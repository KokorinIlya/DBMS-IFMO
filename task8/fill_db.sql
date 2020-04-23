\c Airline;

INSERT INTO Planes (plane_id, registration_number)
VALUES (1, 'PLANE1'),
       (2, 'PLANE2'),
       (3, 'PLANE3');

INSERT INTO Users (user_id, first_name, surname)
VALUES (1, 'Joka', 'Jokov'),
       (2, 'Boka', 'Bokov'),
       (3, 'Lolik', 'Lolikov'),
       (4, 'Bolik', 'Bolikov');

INSERT INTO Seats (plane_id, seat_no)
VALUES (1, 1),
       (1, 2),
       (1, 3),
       (1, 4),
       (2, 1),
       (2, 2),
       (2, 3),
       (3, 1);

INSERT INTO Flights (flight_id, flight_time, plane_id)
VALUES (1, TO_TIMESTAMP('17/11/2019 10:00:00', 'DD/MM/YYYY HH24:MI:SS'), 1),
       (2, TO_TIMESTAMP('11/11/2019 23:00:00', 'DD/MM/YYYY HH24:MI:SS'), 1),
       (3, TO_TIMESTAMP('11/11/2019 02:00:00', 'DD/MM/YYYY HH24:MI:SS'), 2);