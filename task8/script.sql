\C Airline;

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
        AND (NOT Flights.closed_by_administrator)
    );
END;
$$
  LANGUAGE plpgsql;

-- Проверяет, что место не куплено.
CREATE OR REPLACE FUNCTION
  check_not_bought(flight_id_arg INT,
                   seat_no_arg INT)
  RETURNS BOOLEAN AS
$$
BEGIN
  RETURN NOT EXISTS(
      SELECT *
      FROM Bought
      WHERE Bought.flight_id = flight_id_arg
        AND Bought.seat_no = seat_no_arg
    );
END;
$$
  LANGUAGE plpgsql;

-- Выполняет бронирование места или продление брони.
-- Если есть истёкшие брони на данное место на данный рейс,
-- удаляет их из таблицы. Гарантируется, что указанный рейс существует,
-- данное место есть в самолёте, совершающем данный рейс, и не куплено.
-- Если броней на данное место нет, создаёт новую.
-- Если есть бронь данного человека на данное место, обновляет её.
-- Возвращает TRUE, если бронь удалось продлить или создать,
-- FALSE иначе (если данное место забронировано другим человеком).
CREATE OR REPLACE FUNCTION
  do_reservation(flight_id_arg INT,
                 seat_no_arg INT,
                 reservation_timestamp_arg TIMESTAMP,
                 user_id_arg INT)
  RETURNS BOOLEAN AS
$$
DECLARE
  user_that_reserved INT;
BEGIN
  DELETE
  FROM Reservation
  WHERE Reservation.flight_id = flight_id_arg
    AND Reservation.seat_no = seat_no_arg
    AND Reservation.reservation_timestamp
          + INTERVAL '1 Day' < reservation_timestamp_arg;

  SELECT Reservation.user_id INTO user_that_reserved
  FROM Reservation
  WHERE Reservation.flight_id = flight_id_arg
    AND Reservation.seat_no = seat_no_arg;

  IF user_that_reserved IS NULL THEN
    INSERT INTO Reservation(flight_id,
                            seat_no,
                            reservation_timestamp,
                            user_id)
    VALUES (flight_id_arg,
            seat_no_arg,
            reservation_timestamp_arg,
            user_id_arg);

    RETURN TRUE;
  ELSEIF user_that_reserved = user_id_arg THEN
    UPDATE Reservation
    SET reservation_timestamp = reservation_timestamp_arg
    WHERE Reservation.flight_id = flight_id_arg
      AND Reservation.seat_no = seat_no_arg;

    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$
  LANGUAGE plpgsql;

-- Попробовать создать новое или продлить старое бронирование для места seat_no_arg
-- на рейсе flight_id_arg для пользователя user_id_arg.
-- Для этого проверятеся, что место существует, не куплено
-- и не забронировано, на рейс не закрыта продажа
-- администратором (иначе нет смысла бронировать)
-- а бронирование доступно (должно быть больше суток до рейса).
-- Возвращает TRUE, если удалось создать бронирование, FALSE иначе.
CREATE OR REPLACE FUNCTION
  create_or_update_reservation(flight_id_arg INT,
                               seat_no_arg INT,
                               user_id_arg INT) RETURNS BOOLEAN AS
$$
DECLARE
  reservation_timestamp TIMESTAMP := now();
BEGIN
  IF seat_exists_and_can_be_processed(flight_id_arg,
                                      seat_no_arg,
                                      reservation_timestamp,
                                      INTERVAL '1 Day') AND
     check_not_bought(flight_id_arg, seat_no_arg) THEN
    RETURN do_reservation(
        flight_id_arg,
        seat_no_arg,
        reservation_timestamp,
        user_id_arg
      );
  ELSE
    RETURN FALSE;
  END IF;
END;
$$
  LANGUAGE plpgsql;

-- Запрещает покупку мест на рейс flight_id_arg по запросу администратора
CREATE OR REPLACE PROCEDURE close_buy(flight_id_arg INT) AS
$$
BEGIN
  UPDATE Flights
  SET closed_by_administrator = TRUE
  WHERE flight_id = flight_id_arg;
END;
$$
  LANGUAGE plpgsql;

-- Выполняет покупку места.
-- Если есть истёкшие брони на данное место на данный рейс,
-- удаляет их из таблицы. Гарантируется, что указанный рейс существует,
-- данное место есть в самолёте, совершающем данный рейс, и не куплено.
-- Если есть действительная бронь данного места данным человеком,
-- удаляет её из таблицы бронирования.
-- Возвращает TRUE, если бронь удалось купить,
-- FALSE иначе (если данное место забронировано другим человеком).
CREATE OR REPLACE FUNCTION
  do_buy(flight_id_arg INT,
         seat_no_arg INT,
         buy_timestamp_arg TIMESTAMP,
         user_id_arg INT)
  RETURNS BOOLEAN AS
$$
DECLARE
  user_that_reserved INT;
BEGIN
  DELETE
  FROM Reservation
  WHERE Reservation.flight_id = flight_id_arg
    AND Reservation.seat_no = seat_no_arg
    AND Reservation.reservation_timestamp
          + INTERVAL '1 Day' < buy_timestamp_arg;

  SELECT Reservation.user_id INTO user_that_reserved
  FROM Reservation
  WHERE Reservation.flight_id = flight_id_arg
    AND Reservation.seat_no = seat_no_arg;

  IF user_that_reserved IS NULL THEN
    INSERT INTO Bought(flight_id, seat_no, user_id)
    VALUES (flight_id_arg, seat_no_arg, user_id_arg);

    RETURN TRUE;
  ELSEIF user_that_reserved = user_id_arg THEN
    DELETE
    FROM Reservation
    WHERE reservation.flight_id = flight_id_arg
      AND Reservation.seat_no = seat_no_arg;

    INSERT INTO Bought(flight_id, seat_no, user_id)
    VALUES (flight_id_arg, seat_no_arg, user_id_arg);

    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$
  LANGUAGE plpgsql;


-- Попробовать купить место seat_no_arg
-- на рейсе flight_id_arg для пользователя user_id_arg.
-- Для этого проверятеся, что место существует, не куплено
-- и не забронировано другим пользователем, на рейс не закрыта продажа
-- администратором,
-- а покупка доступна (должно быть больше двух часов до рейса).
-- Если существует бронирование данного места, выполненное данным человеком,
-- удаляет его из таблицы бронирований
-- (т.к.  нет смысла держать бронь, если место куплено)
-- Возвращает TRUE, если удалось купить, FALSE иначе.
CREATE OR REPLACE FUNCTION
  buy(flight_id_arg INT,
      seat_no_arg INT,
      user_id_arg INT) RETURNS BOOLEAN AS
$$
DECLARE
  buy_timestamp TIMESTAMP := now();
BEGIN
  IF seat_exists_and_can_be_processed(flight_id_arg,
                                      seat_no_arg,
                                      buy_timestamp,
                                      INTERVAL '2 Hours') AND
     check_not_bought(flight_id_arg, seat_no_arg) THEN
    RETURN do_buy(flight_id_arg, seat_no_arg, buy_timestamp, user_id_arg);
  ELSE
    RETURN FALSE;
  END IF;
END;
$$
  LANGUAGE plpgsql;

-- Средняя заполненность самолёта по рейсу (среднее количество мест, которые
-- были куплены в самолёте с определённым plane_id)
WITH FlightsWithBoughtCount AS (
  SELECT Flights.flight_id,
         count(Bought.seat_no) AS bought_count
  FROM Flights
         LEFT OUTER JOIN Bought USING (flight_id)
  WHERE Flights.plane_id = ?
  GROUP BY Flights.flight_id
)
SELECT avg(FlightsWithBoughtCount.bought_count)
FROM FlightsWithBoughtCount;

CREATE INDEX plane_id_idx ON Flights USING hash (plane_id);