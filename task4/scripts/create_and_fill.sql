\C CTD;

DROP TABLE IF EXISTS Groups CASCADE;
DROP TABLE IF EXISTS Students CASCADE;
DROP TABLE IF EXISTS Courses CASCADE;
DROP TABLE IF EXISTS Lecturers CASCADE;
DROP TABLE IF EXISTS Scores CASCADE;
DROP TABLE IF EXISTS StudyPlan CASCADE;
DROP TYPE IF EXISTS Mark;

CREATE TABLE Groups
(
  id   DECIMAL(5) NOT NULL PRIMARY KEY,
  name CHAR(5)    NOT NULL UNIQUE
);

CREATE TABLE Students
(
  id         DECIMAL(6)  NOT NULL PRIMARY KEY,
  first_name VARCHAR(50) NOT NULL,
  surname    VARCHAR(50) NOT NULL,
  patronymic VARCHAR(50),
  group_id   DECIMAL(5)  NOT NULL,
  FOREIGN KEY (group_id) REFERENCES Groups (id)
);

CREATE TABLE Courses
(
  id   DECIMAL(5)  NOT NULL PRIMARY KEY,
  name VARCHAR(50) NOT NULL
);

CREATE TABLE Lecturers
(
  id         DECIMAL(6)  NOT NULL PRIMARY KEY,
  first_name VARCHAR(50) NOT NULL,
  surname    VARCHAR(50) NOT NULL,
  patronymic VARCHAR(50)
);

CREATE TYPE Mark AS ENUM ('FX', 'F', 'E', 'D', 'C', 'B', 'A');

CREATE TABLE Scores
(
  student_id DECIMAL(6) NOT NULL,
  course_id  DECIMAL(5) NOT NULL,
  score      Mark       NOT NULL,
  PRIMARY KEY (student_id, course_id),
  FOREIGN KEY (student_id) REFERENCES Students (id),
  FOREIGN KEY (course_id) REFERENCES Courses (id)
);

CREATE TABLE StudyPlan
(
  course_id   DECIMAL(5) NOT NULL,
  group_id    DECIMAL(5) NOT NULL,
  lecturer_id DECIMAL(6) NOT NULL,
  PRIMARY KEY (course_id, group_id),
  FOREIGN KEY (course_id) REFERENCES Courses (id),
  FOREIGN KEY (group_id) REFERENCES Groups (id),
  FOREIGN KEY (lecturer_id) REFERENCES Lecturers (id)
);

INSERT INTO Groups(id, name)
VALUES (1, 'M3435'),
       (2, 'M3437'),
       (3, 'M3439');

INSERT INTO Students (id, first_name, surname, patronymic, group_id)
VALUES (1, 'Илья', 'Кокорин', 'Всеволодович', 3),
       (2, 'Лев', 'Довжик', 'Игоревич', 3),
       (3, 'Николай', 'Рыкунов', 'Викторович', 1),
       (4, 'Ярослав', 'Балашов', 'Дмитриевич', 1),
       (5, 'Никита', 'Дугинец', 'Денисович', 2);

INSERT INTO Courses(id, name)
VALUES (1, 'Математический анализ'),
       (2, 'Технологии Java'),
       (3, 'Базы данных');

INSERT INTO Lecturers (id, first_name, surname, patronymic)
VALUES (1, 'Георгий', 'Корнеев', 'Александрович'),
       (2, 'Константин', 'Кохась', 'Петрович'),
       (3, 'Ольга', 'Семёнова', 'Львовна');

INSERT INTO StudyPlan (course_id, group_id, lecturer_id)
VALUES (1, 1, 3),
       (1, 2, 3),
       (1, 3, 2),
       (2, 2, 1),
       (2, 3, 1),
       (3, 3, 1);


INSERT INTO Scores (student_id, course_id, score)
VALUES (1, 1, 'A'),
       (1, 2, 'B'),
       (1, 3, 'C'),
       (2, 1, 'C'),
       (2, 2, 'B'),
       (2, 3, 'A'),
       (3, 1, 'A'),
       (4, 1, 'C'),
       (5, 1, 'A'),
       (5, 2, 'B');