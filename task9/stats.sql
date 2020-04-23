\C Airline;

-- Заметим, что не бывает такой ситцации, когда место можно забронировать, но нельзя купить.
-- Ситуация, когда место можно купить, но нельзя забронировать, возникает, например,
-- за 3 часа до вылета.
CREATE TYPE AvailableActions AS ENUM ('Buy', 'BuyAndReserve', 'Nothing');

CREATE OR REPLACE FUNCTION get_available_actions(request_timestamp TIMESTAMP,
                                                 flight_timestamp TIMESTAMP)
    RETURNS AvailableActions AS
$$
DECLARE
    booking_closed_interval INTERVAL := INTERVAL '1 Day';
    buy_closed_interval     INTERVAL := INTERVAL '2 Hours';
BEGIN
    IF request_timestamp + booking_closed_interval < flight_timestamp THEN
        RETURN 'BuyAndReserve';
    ELSEIF request_timestamp + buy_closed_interval < flight_timestamp THEN
        RETURN 'Buy';
    ELSE
        RETURN 'Nothing';
    END IF;
END;
$$
    LANGUAGE plpgsql;

-- Возвращает список мест, доступных для продажи и бронирования.
-- Для каждого места говорит, что с ним можно сделать (либо купить, либо купить и забронировать).
-- Заметим, что, так как пользователь неизвестен, не бывает такой ситации,
-- когда мы можем выкупить ранее забронированное нами место или продлить его бронь.
CREATE OR REPLACE FUNCTION free_seats(flight_id_arg INT)
    RETURNS TABLE
            (
                seat_no           INT,
                available_actions AvailableActions
            )
AS
$$
DECLARE
    request_timestamp           TIMESTAMP := now();
    booking_expiration_interval INTERVAL  := INTERVAL '1 Day';
BEGIN
    RETURN QUERY
        SELECT Seats.seat_no                              AS seat_no,
               get_available_actions(request_timestamp,
                                     Flights.flight_time) AS available_actions
        FROM Flights
                 NATURAL JOIN Seats
                 LEFT OUTER JOIN Reservation USING (flight_id, seat_no)
        WHERE Flights.flight_id = flight_id_arg
          AND (NOT Flights.closed_by_administrator)
          AND get_available_actions(request_timestamp,
                                    Flights.flight_time) <> 'Nothing'
          AND (Reservation.user_id IS NULL OR -- в таблице Reservation в принципе нет такой записи,
               Reservation.user_id IS NOT NULL -- либо в таблице Reservation есть такая запись
                   AND NOT Reservation.is_bought -- место не выкуплено
                   AND Reservation.reservation_timestamp + -- а бронь истекла
                       booking_expiration_interval < request_timestamp);
END;
$$
    LANGUAGE plpgsql;

-- В таблице Reservation может не быть записи, так что bought_arg может быть NULL
CREATE OR REPLACE FUNCTION count_bought(bought_arg BOOLEAN) RETURNS INT AS
$$
BEGIN
    IF bought_arg IS NULL THEN
        RETURN 0;
    ELSEIF NOT bought_arg THEN
        RETURN 0;
    ELSE
        RETURN 1;
    END IF;
END;
$$
    LANGUAGE plpgsql;

-- Если покупка на рейс запрещена администратором или осталось менее двух часов до вылета,
-- то считаем, что не заблокировано ни одного места
-- (так как эти места всё равно не смогут быть выкуплены)
-- В таблице Reservation может не быть записи, так что
-- bought_arg и reservation_timestamp_arg может быть NULL
CREATE OR REPLACE FUNCTION count_reserved(closed_by_administrator_arg BOOLEAN,
                                          flight_time_arg TIMESTAMP,
                                          reservation_timestamp_arg TIMESTAMP,
                                          bought_arg BOOLEAN,
                                          request_timestamp_arg TIMESTAMP) RETURNS INT AS
$$
DECLARE
    buy_closed_interval          INTERVAL := INTERVAL '2 Hours';
    reservation_expires_interval INTERVAL := INTERVAL '1 Day';
BEGIN
    IF reservation_timestamp_arg IS NULL
        OR bought_arg IS NULL
        OR closed_by_administrator_arg
        OR (bought_arg IS NOT NULL AND bought_arg)
        OR (reservation_timestamp_arg IS NOT NULL
            AND reservation_timestamp_arg + buy_closed_interval > flight_time_arg)
        OR (reservation_timestamp_arg IS NOT NULL
            AND reservation_timestamp_arg +
                reservation_expires_interval < request_timestamp_arg) THEN
        RETURN 0;
    ELSE
        RETURN 1;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- В таблице Reservation может не быть записи, так что
-- is_bought_arg, user_that_reserved_arg и reservation_timestamp_arg могут быть NULL.
-- Считаем, что если пользователь, делающий запрос, уже бронировал это место и бронь не истекла,
-- то он может забронировать это место (продлить бронь).
-- Считаем, что человек не может забронировать или купить ничего,
-- если у него неправильный логин или пароль.
-- Возвращает 1, если место может быть обработано неким образом (куплено или зарезервировано)
-- данным пользователем, 0 иначе. Считаем, что если данный пользователь забронировал место,
-- то он может его как купить (выкупить бронь), так и забронировать (продлить бронь).
-- process_closed_interval - время до вылета, за которое закрывается возможность
-- совершить данное действие (2 часа для покупки, 1 день - для брони).
CREATE OR REPLACE FUNCTION count_available_to_process(closed_by_administrator_arg BOOLEAN,
                                                      flight_timestamp_arg TIMESTAMP,
                                                      user_id_arg INT,
                                                      pass_arg TEXT,
                                                      user_that_reserved_arg INT,
                                                      is_bought_arg BOOLEAN,
                                                      reservation_timestamp_arg TIMESTAMP,
                                                      request_timestamp_arg TIMESTAMP,
                                                      process_closed_interval INTERVAL)
    RETURNS INT AS
$$
DECLARE
    reservation_expires_interval INTERVAL := INTERVAL '1 Day';
BEGIN
    IF check_credentials(user_id_arg, pass_arg)
        AND NOT closed_by_administrator_arg
        AND request_timestamp_arg + process_closed_interval <= flight_timestamp_arg
        AND (is_bought_arg IS NULL OR NOT is_bought_arg) THEN
        IF user_that_reserved_arg IS NULL THEN
            RETURN 1;
        ELSEIF reservation_timestamp_arg +
               reservation_expires_interval < request_timestamp_arg THEN
            RETURN 1;
        ELSEIF user_that_reserved_arg = user_id_arg THEN
            RETURN 1;
        ELSE
            RETURN 0;
        END IF;
    ELSE
        RETURN 0;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION count_available_to_reserve(closed_by_administrator_arg BOOLEAN,
                                                      flight_timestamp_arg TIMESTAMP,
                                                      user_id_arg INT,
                                                      pass_arg TEXT,
                                                      user_that_reserved_arg INT,
                                                      is_bought_arg BOOLEAN,
                                                      reservation_timestamp_arg TIMESTAMP,
                                                      request_timestamp_arg TIMESTAMP)
    RETURNS INT AS
$$
DECLARE
    reservation_closed_interval INTERVAL := INTERVAL '1 Day';
BEGIN
    RETURN count_available_to_process(
            closed_by_administrator_arg,
            flight_timestamp_arg,
            user_id_arg,
            pass_arg,
            user_that_reserved_arg,
            is_bought_arg,
            reservation_timestamp_arg,
            request_timestamp_arg,
            reservation_closed_interval
        );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION count_available_to_buy(closed_by_administrator_arg BOOLEAN,
                                                  flight_timestamp_arg TIMESTAMP,
                                                  user_id_arg INT,
                                                  pass_arg TEXT,
                                                  user_that_reserved_arg INT,
                                                  is_bought_arg BOOLEAN,
                                                  reservation_timestamp_arg TIMESTAMP,
                                                  request_timestamp_arg TIMESTAMP)
    RETURNS INT AS
$$
DECLARE
    buy_closed_interval INTERVAL := INTERVAL '2 Hours';
BEGIN
    RETURN count_available_to_process(
            closed_by_administrator_arg,
            flight_timestamp_arg,
            user_id_arg,
            pass_arg,
            user_that_reserved_arg,
            is_bought_arg,
            reservation_timestamp_arg,
            request_timestamp_arg,
            buy_closed_interval
        );
END;
$$ LANGUAGE plpgsql;

-- статистика по рейсам: число возможных для бронирования и покупки данным человеком,
-- число свободных, забронированных и проданных мест
CREATE OR REPLACE FUNCTION flight_statistic(user_id_arg INT, pass_arg TEXT)
    RETURNS TABLE
            (
                flight_id                  INT,
                available_to_reserve_seats INT,
                available_to_buy_seats     INT,
                free_seats                 INT,
                reserved_seats             INT,
                bought_seats               INT
            )
AS
$$
DECLARE
    request_timestamp TIMESTAMP := now();
BEGIN
    RETURN QUERY
        WITH temp_stats AS (
            SELECT Flights.flight_id,
                   sum(
                           count_available_to_reserve(
                                   Flights.closed_by_administrator,
                                   Flights.flight_time,
                                   user_id_arg,
                                   pass_arg,
                                   Reservation.user_id,
                                   Reservation.is_bought,
                                   Reservation.reservation_timestamp,
                                   request_timestamp
                               )
                       ):: INT     AS available_to_reserve_seats,
                   sum(
                           count_available_to_buy(
                                   Flights.closed_by_administrator,
                                   Flights.flight_time,
                                   user_id_arg,
                                   pass_arg,
                                   Reservation.user_id,
                                   Reservation.is_bought,
                                   Reservation.reservation_timestamp,
                                   request_timestamp
                               )
                       ) :: INT    AS available_to_buy_seats,
                   sum(
                           count_bought(
                                   Reservation.is_bought
                               )
                       ) :: INT    AS bought_seats,
                   sum(
                           count_reserved(
                                   Flights.closed_by_administrator,
                                   Flights.flight_time,
                                   Reservation.reservation_timestamp,
                                   Reservation.is_bought,
                                   request_timestamp
                               )
                       ) :: INT    AS reserved_seats,
                   count(*) :: INT AS total_seats
            FROM Flights
                     NATURAL JOIN Seats
                     LEFT OUTER JOIN Reservation USING (flight_id, seat_no)
            GROUP BY Flights.flight_id
        )
        SELECT temp_stats.flight_id,
               temp_stats.available_to_reserve_seats,
               temp_stats.available_to_buy_seats,
               temp_stats.total_seats - temp_stats.reserved_seats
                   - temp_stats.bought_seats AS free_seats,
               temp_stats.reserved_seats,
               temp_stats.bought_seats
        FROM temp_stats;
END;
$$ LANGUAGE plpgsql;

CREATE TYPE FlightStat AS (
    available_to_reserve_seats INT,
    available_to_buy_seats INT,
    free_seats INT,
    reserved_seats INT,
    bought_seats INT
    );

-- статистика по рейсу: число возможных для бронирования и покупки данным человеком,
-- число свободных, забронированных и проданных мест
CREATE OR REPLACE FUNCTION flight_stat(user_id_arg INT, pass_arg TEXT, flight_id_arg INT)
    RETURNS FlightStat
AS
$$
DECLARE
    result FlightStat;
BEGIN
    SELECT available_to_reserve_seats,
           available_to_buy_seats,
           free_seats,
           reserved_seats,
           bought_seats
    INTO result.available_to_reserve_seats,
        result.available_to_buy_seats,
        result.free_seats,
        result.reserved_seats,
        result.bought_seats
    FROM flight_statistic(user_id_arg, pass_arg)
    WHERE flight_id = flight_id_arg;

    IF result.available_to_reserve_seats IS NOT NULL THEN
        RETURN result;
    ELSE
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;