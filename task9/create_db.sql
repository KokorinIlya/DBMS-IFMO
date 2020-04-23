\C Airline;

CREATE TABLE Planes
(
    plane_id            INT        NOT NULL PRIMARY KEY,
    registration_number VARCHAR(7) NOT NULL
);

CREATE TABLE Seats
(
    plane_id INT NOT NULL,
    seat_no  INT NOT NULL,
    PRIMARY KEY (plane_id, seat_no),
    FOREIGN KEY (plane_id) REFERENCES Planes (plane_id)
);

CREATE TABLE Flights
(
    flight_id               INT       NOT NULL PRIMARY KEY,
    flight_time             TIMESTAMP NOT NULL,
    plane_id                INT       NOT NULL,
    closed_by_administrator BOOLEAN   NOT NULL DEFAULT FALSE,
    FOREIGN KEY (plane_id) REFERENCES Planes (plane_id)
);

CREATE TABLE Users
(
    user_id        INT         NOT NULL PRIMARY KEY,
    first_name     VARCHAR(50) NOT NULL,
    surname        VARCHAR(50) NOT NULL,
    encrypted_pass TEXT        NOT NULL -- пароль + соль, используемый в функции crypt
);

CREATE TABLE Reservation
(
    flight_id             INT       NOT NULL,
    seat_no               INT       NOT NULL,
    reservation_timestamp TIMESTAMP NOT NULL,
    user_id               INT       NOT NULL,
    is_bought             BOOLEAN   NOT NULL,
    -- FALSE, если место забронировано, но пока не выкуплено,
    -- иначе TRUE
    FOREIGN KEY (user_id) REFERENCES Users (user_id),
    FOREIGN KEY (flight_id) REFERENCES Flights (flight_id)
);

ALTER TABLE Reservation
    ADD PRIMARY KEY (flight_id, seat_no) DEFERRABLE INITIALLY DEFERRED;