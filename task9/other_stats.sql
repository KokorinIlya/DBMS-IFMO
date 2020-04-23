\C Airline;

CREATE OR
    REPLACE FUNCTION nullable_bool_to_int(arg BOOLEAN)
    RETURNS INT
    IMMUTABLE
AS
$$
BEGIN
    IF arg is NULL THEN
        RETURN 0;
    ELSE
        RETURN arg::INT;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR
    REPLACE FUNCTION can_book(closed_by_admin BOOLEAN,
                              flight_time TIMESTAMP,
                              user_id INT,
                              pass TEXT,
                              booker_id INT,
                              is_bought BOOLEAN,
                              book_time TIMESTAMP)
    RETURNS BOOLEAN
    IMMUTABLE
AS
$$
BEGIN
    IF closed_by_admin OR (flight_time - CURRENT_TIMESTAMP < INTERVAL '1 Day') THEN
        RETURN FALSE;
    END IF;
    IF booker_id is NULL THEN
        RETURN TRUE;
    END IF;
    IF is_bought THEN
        RETURN FALSE;
    END IF;
    IF booking_end(book_time, flight_time) < CURRENT_TIMESTAMP THEN
        RETURN TRUE;
    ELSE
        IF NOT check_credentials(user_id, pass) THEN
            RETURN FALSE;
        ELSE
            RETURN user_id = booker_id;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR
    REPLACE FUNCTION can_buy(closed_by_admin BOOLEAN,
                             flight_time TIMESTAMP,
                             user_id INT,
                             pass TEXT,
                             booker_id INT,
                             is_bought BOOLEAN,
                             book_time TIMESTAMP)
    RETURNS BOOLEAN
    IMMUTABLE
AS
$$
BEGIN
    IF closed_by_admin OR (flight_time - CURRENT_TIMESTAMP < two_hours()) THEN
        RETURN FALSE;
    END IF;
    IF booker_id is NULL THEN
        RETURN TRUE;
    END IF;
    IF is_bought THEN
        RETURN FALSE;
    END IF;
    IF booking_end(book_time, flight_time) < CURRENT_TIMESTAMP THEN
        RETURN TRUE;
    ELSE
        IF NOT check_credentials(user_id, pass) THEN
            RETURN FALSE;
        ELSE
            RETURN user_id = booker_id;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR
    REPLACE FUNCTION flight_statistic(user_id_arg INT, pass_arg TEXT)
    RETURNS TABLE
            (
                flight_id    INT,
                can_buy      BOOLEAN,
                can_book     BOOLEAN,
                free_seats   INT,
                booked_seats INT,
                sold_seats   INT
            )
    IMMUTABLE
AS
$$
BEGIN
    WITH raw_stats AS (
        SELECT flight_id,
               sum(nullable_bool_to_int(is_bought)) AS sold_seats,
               sum(is_booked(closed_by_administrator, flight_time,
                             reservation_timestamp))
                                                    AS booked_seats,
               count(*)                             AS total_seats,
               sum(can_book(closed_by_administrator, flight_time, user_id_arg,
                            pass_arg, user_id, is_bought, reservation_timestamp)::INT)
                                                    AS books_available,
               sum(can_buy(closed_by_administrator, flight_time, user_id_arg,
                           pass_arg, user_id, is_bought, reservation_timestamp)::INT)
                                                    AS purchases_available
        FROM flights
                 NATURAL JOIN seats
                 LEFT OUTER JOIN Reservation USING (flight_id, seat_no)
        GROUP BY flight_id
    )
    SELECT flight_id,
           purchases_available > 0                 AS can_buy,
           books_available > 0                     AS can_book,
           total_seats - sold_seats - booked_seats AS free_seats,
           booked_seats,
           sold_seats
    FROM raw_stats;
END;
$$ LANGUAGE plpgsql;

CREATE OR
    REPLACE FUNCTION flight_stat(user_id_arg INT, pass_arg TEXT, flight_id_arg INT)
    RETURNS TABLE
            (
                flight_id    INT,
                can_buy      BOOLEAN,
                can_book     BOOLEAN,
                free_seats   INT,
                booked_seats INT,
                sold_seats   INT
            )
    IMMUTABLE
AS
$$
BEGIN
    SELECT *
    FROM flight_statistic(user_id_arg, pass_arg)
    WHERE flight_id = flight_id_arg;
END;
$$ LANGUAGE plpgsql;