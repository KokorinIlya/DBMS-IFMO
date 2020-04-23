-- Возвращает TRUE, если получилось создать пользователя, и
-- FALSE, если нет (если пользователь с таким id уже существует).
-- Заметим, что функция не падает с ошибкой если user_id не уникален,
-- а возвращает FALSE.
CREATE OR REPLACE FUNCTION
    create_user(user_id_arg INT,
                first_name_arg VARCHAR(50),
                surname_arg VARCHAR(50),
                pass_arg TEXT) RETURNS BOOLEAN AS
$$
DECLARE
    pass_hash       TEXT;
    new_users_count INT;
BEGIN
    pass_hash := crypt(pass_arg, gen_salt('bf', 8));

    INSERT INTO Users (user_id, first_name, surname, encrypted_pass)
    VALUES (user_id_arg, first_name_arg, surname_arg, pass_hash)
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS new_users_count = ROW_COUNT;
    RETURN new_users_count = 1;
END;
$$
    LANGUAGE plpgsql;

-- Возвращает TRUE, если пользователь с таким user_id существует и пароль корректный,
-- FALSE, если нет (если пользователя не существует или пароль неверен).
CREATE OR REPLACE FUNCTION
    check_credentials(user_id_arg INT,
                      password_arg TEXT) RETURNS BOOLEAN AS
$$
DECLARE
    user_pass_hash TEXT;
BEGIN
    SELECT Users.encrypted_pass
    INTO user_pass_hash
    FROM Users
    WHERE Users.user_id = user_id_arg;

    RETURN user_pass_hash IS NOT NULL AND crypt(password_arg, user_pass_hash) = user_pass_hash;
END;
$$
    LANGUAGE plpgsql;

-- Проверяет, что рейс flight_id_arg существует, в самолёте,
-- совершающем данный рейс, есть место seat_no_arg,
-- бронирование (или покупка) на рейс flight_id_arg может быть
-- совершено во время action_timestamp_arg. (то есть осталось
-- больше суток/двух часов до вылета и
-- продажа на рейс не запрещена администратором)
CREATE OR REPLACE FUNCTION
    seat_exists_and_can_be_processed(flight_id_arg INT,
                                     seat_no_arg INT,
                                     action_timestamp_arg TIMESTAMP,
                                     interval_arg INTERVAL)
    RETURNS BOOLEAN AS
$$
BEGIN
    RETURN EXISTS(
            SELECT *
            FROM Flights
                     NATURAL JOIN Seats
            WHERE Flights.flight_id = flight_id_arg
              AND Seats.seat_no = seat_no_arg
              AND action_timestamp_arg + interval_arg < Flights.flight_time
              AND NOT Flights.closed_by_administrator
        );
END;
$$
    LANGUAGE plpgsql;

-- Производит операцию со свободным (то есть не купленным и не забронированным) сидением.
-- Если is_bought_arg = TRUE, ты покупаем, иначе бронируем.
-- action_closed_interval обозначает промежуток времени до вылета,
-- за который закрывается эта операция (для покупки - два часа, для бронирования - сутки)
-- Функция фозвращает TRUE если операция прошла удачно, иначе FALSE.
CREATE OR REPLACE FUNCTION process_free_seat(user_id_arg INT,
                                             pass_arg TEXT,
                                             flight_id_arg INT,
                                             seat_no_arg INT,
                                             action_closed_interval INTERVAL,
                                             is_bought_arg BOOLEAN)
    RETURNS BOOLEAN
AS
$$
DECLARE
    booking_expiration_interval INTERVAL  := INTERVAL '1 Day';
    request_timestamp           TIMESTAMP := now();
    seat_is_bought              BOOLEAN;
    seat_reservation_timestamp  TIMESTAMP;
BEGIN
    IF check_credentials(user_id_arg, pass_arg) AND
       seat_exists_and_can_be_processed(flight_id_arg,
                                        seat_no_arg,
                                        request_timestamp,
                                        action_closed_interval) THEN
        SELECT Reservation.is_bought,
               Reservation.reservation_timestamp
        INTO seat_is_bought,
            seat_reservation_timestamp
        FROM Reservation
        WHERE Reservation.flight_id = flight_id_arg
          AND Reservation.seat_no = seat_no_arg;

        IF seat_is_bought IS NULL THEN
            INSERT INTO Reservation (flight_id,
                                     seat_no,
                                     reservation_timestamp,
                                     user_id,
                                     is_bought)
            VALUES (flight_id_arg,
                    seat_no_arg,
                    request_timestamp,
                    user_id_arg,
                    is_bought_arg);

            RETURN TRUE;
        ELSEIF NOT seat_is_bought AND
               seat_reservation_timestamp
                   + booking_expiration_interval < request_timestamp THEN
            UPDATE Reservation
            SET user_id               = user_id_arg,
                reservation_timestamp = request_timestamp,
                is_bought             = is_bought_arg
            WHERE flight_id = flight_id_arg
              AND seat_no = seat_no_arg;

            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$
    LANGUAGE plpgsql;

-- Пытается забронировать место, то есть создать новую бронь, а не продлить старую.
-- Возвращает TRUE, если удалось и FALSE — в противном случае
CREATE OR REPLACE FUNCTION reserve(user_id_arg INT,
                                   pass_arg TEXT,
                                   flight_id_arg INT,
                                   seat_no_arg INT)
    RETURNS BOOLEAN
AS
$$
DECLARE
    reservation_closed_interval INTERVAL := INTERVAL '1 Day';
BEGIN
    RETURN process_free_seat(
            user_id_arg,
            pass_arg,
            flight_id_arg,
            seat_no_arg,
            reservation_closed_interval,
            FALSE
        );
END;
$$
    LANGUAGE plpgsql;

-- Пытается продлить бронь места.
-- Возвращает TRUE, если удалось и FALSE — в противном случае
CREATE OR REPLACE FUNCTION extend_reservation(user_id_arg INT,
                                              pass_arg TEXT,
                                              flight_id_arg INT,
                                              seat_no_arg INT)
    RETURNS BOOLEAN
AS
$$
DECLARE
    request_timestamp           TIMESTAMP := now();
    booking_expiration_interval INTERVAL  := INTERVAL '1 Day';
    booking_closed_interval     INTERVAL  := INTERVAL '1 Day';
BEGIN
    IF check_credentials(user_id_arg, pass_arg) AND EXISTS(
            SELECT *
            FROM Reservation
                     NATURAL JOIN Flights
            WHERE Reservation.flight_id = flight_id_arg
              AND Reservation.seat_no = seat_no_arg
              AND Reservation.user_id = user_id_arg
              AND NOT Flights.closed_by_administrator
              AND NOT Reservation.is_bought
              AND Reservation.reservation_timestamp +
                  booking_expiration_interval >= request_timestamp
              AND request_timestamp + booking_closed_interval <
                  Flights.flight_time
        ) THEN
        UPDATE Reservation
        SET reservation_timestamp = request_timestamp
        WHERE flight_id = flight_id_arg
          AND seat_no = seat_no_arg;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$
    LANGUAGE plpgsql;

-- пытается купить свободное место.
-- Возвращает TRUE, если удалось и FALSE — в противном случае
CREATE OR REPLACE FUNCTION buy_free(user_id_arg INT,
                                    pass_arg TEXT,
                                    flight_id_arg INT,
                                    seat_no_arg INT)
    RETURNS BOOLEAN
AS
$$
DECLARE
    buy_closed_interval INTERVAL := INTERVAL '2 Hours';
BEGIN
    RETURN process_free_seat(
            user_id_arg,
            pass_arg,
            flight_id_arg,
            seat_no_arg,
            buy_closed_interval,
            TRUE
        );
END;
$$
    LANGUAGE plpgsql;

-- Пытается выкупить забронированное место.
-- Возвращает TRUE, если удалось и FALSE — в противном случае
CREATE OR REPLACE FUNCTION buy_reserved(user_id_arg INT,
                                        pass_arg TEXT,
                                        flight_id_arg INT,
                                        seat_no_arg INT)
    RETURNS BOOLEAN
AS
$$
DECLARE
    request_timestamp           TIMESTAMP := now();
    booking_expiration_interval INTERVAL  := INTERVAL '1 Day';
    buy_closed_interval         INTERVAL  := INTERVAL '2 Hours';
BEGIN
    IF check_credentials(user_id_arg, pass_arg) AND EXISTS(
            SELECT *
            FROM Reservation
                     NATURAL JOIN Flights
            WHERE Reservation.flight_id = flight_id_arg
              AND Reservation.seat_no = seat_no_arg
              AND Reservation.user_id = user_id_arg
              AND NOT Flights.closed_by_administrator
              AND NOT Reservation.is_bought
              AND Reservation.reservation_timestamp +
                  booking_expiration_interval >= request_timestamp
              AND request_timestamp + buy_closed_interval <
                  Flights.flight_time
        ) THEN
        UPDATE Reservation
        SET reservation_timestamp = request_timestamp,
            is_bought             = TRUE
        WHERE flight_id = flight_id_arg
          AND seat_no = seat_no_arg;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$
    LANGUAGE plpgsql;

-- оптимизирует занятость мест в самолете.
-- В результате оптимизации, в начале самолета должны быть купленные места,
-- затем — забронированные, а в конце — свободные
CREATE OR REPLACE PROCEDURE
    compress_seats(flight_id_arg INT) AS
$$
DECLARE
    request_timestamp   TIMESTAMP := now();
    reservations_cursor CURSOR FOR
        SELECT Reservation.seat_no
        FROM Reservation
        WHERE Reservation.flight_id = flight_id_arg
          AND (Reservation.is_bought OR
               Reservation.reservation_timestamp + '1 Day' >= request_timestamp)
        ORDER BY is_bought DESC;
    seats_cursor CURSOR FOR
        SELECT Seats.seat_no
        FROM Flights
                 NATURAL JOIN Seats
        WHERE Flights.flight_id = flight_id_arg
        ORDER BY seat_no;
    reservation_seat_no INT;
    plane_seat_no       INT;
BEGIN
    SET CONSTRAINTS ALL DEFERRED;
    DELETE
    FROM Reservation
    WHERE Reservation.flight_id = flight_id_arg
      AND NOT Reservation.is_bought
      AND Reservation.reservation_timestamp
              + INTERVAL '1 Day' < request_timestamp;

    OPEN reservations_cursor;
    OPEN seats_cursor;
    LOOP
        FETCH reservations_cursor INTO reservation_seat_no;
        FETCH seats_cursor INTO plane_seat_no;

        IF NOT FOUND THEN
            EXIT;
        END IF;

        UPDATE Reservation
        SET seat_no = plane_seat_no
        WHERE flight_id = flight_id_arg
          AND seat_no = reservation_seat_no;

    END LOOP;
    CLOSE reservations_cursor;
    CLOSE seats_cursor;
END;
$$
    LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE remove_all_bookings(flight_id_arg INT) AS
$$
BEGIN
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    DELETE
    FROM Reservation
    WHERE flight_id = flight_id_arg
      AND NOT is_bought;
END;
$$
    LANGUAGE plpgsql;
