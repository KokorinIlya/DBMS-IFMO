\C CTD;

CREATE TABLE Groups
(
  GroupId   DECIMAL(5) NOT NULL PRIMARY KEY,
  GroupName CHAR(5)    NOT NULL UNIQUE
);

CREATE TABLE Students
(
  StudentId   DECIMAL(6)  NOT NULL PRIMARY KEY,
  StudentName VARCHAR(50) NOT NULL,
  GroupId     DECIMAL(5)  NOT NULL,
  FOREIGN KEY (GroupId) REFERENCES Groups (GroupId)
);

CREATE TABLE Courses
(
  CourseId   DECIMAL(5)  NOT NULL PRIMARY KEY,
  CourseName VARCHAR(50) NOT NULL
);

CREATE TABLE Lecturers
(
  LecturerId   DECIMAL(6)  NOT NULL PRIMARY KEY,
  LecturerName VARCHAR(50) NOT NULL
);

CREATE TABLE Marks
(
  StudentId DECIMAL(6) NOT NULL,
  CourseId  DECIMAL(5) NOT NULL,
  Mark      DECIMAL(3) NOT NULL,
  PRIMARY KEY (StudentId, CourseId),
  FOREIGN KEY (CourseId) REFERENCES Courses (CourseId),
  FOREIGN KEY (StudentId) REFERENCES Students (StudentId)
    ON DELETE CASCADE ON UPDATE NO ACTION
);

CREATE TABLE Plan
(
  CourseId   DECIMAL(5) NOT NULL,
  GroupId    DECIMAL(5) NOT NULL,
  LecturerId DECIMAL(6) NOT NULL,
  PRIMARY KEY (CourseId, GroupId),
  FOREIGN KEY (CourseId) REFERENCES Courses (CourseId),
  FOREIGN KEY (GroupId) REFERENCES Groups (GroupId),
  FOREIGN KEY (LecturerId) REFERENCES Lecturers (LecturerId)
);

INSERT INTO Groups(GroupId, GroupName)
VALUES (1, 'M3435'),
       (2, 'M3437'),
       (3, 'M3439'),
       (4, 'M3438');

INSERT INTO Students (StudentId, StudentName, GroupId)
VALUES (1, 'Илья Кокорин', 3),
       (2, 'Лев Довжик', 3),
       (3, 'Артём Абрамов', 3),
       (4, 'Николай Рыкунов', 1),
       (5, 'Ярослав Балашов', 1),
       (6, 'Никита Дугинец', 2);

INSERT INTO Courses(CourseId, CourseName)
VALUES (1, 'Математический анализ'),
       (2, 'Технологии Java'),
       (3, 'Базы данных'),
       (4, 'Теория вероятностей'),
       (5, 'Матстат');

INSERT INTO Lecturers (LecturerId, LecturerName)
VALUES (1, 'Георгий Корнеев'),
       (2, 'Константин Кохась'),
       (3, 'Ольга Семёнова'),
       (4, 'Ирина Суслина');

INSERT INTO Plan (CourseId, GroupId, LecturerId)
VALUES (1, 1, 3),
       (1, 2, 3),
       (1, 3, 2),
       (2, 2, 1),
       (2, 3, 1),
       (3, 3, 1),
       (4, 3, 4),
       (5, 3, 4);


INSERT INTO Marks (StudentId, CourseId, Mark)
VALUES (1, 1, 100),
       (1, 2, 85),
       (1, 3, 75),
       (2, 1, 75),
       (2, 2, 85),
       (2, 3, 100),
       (4, 1, 100),
       (5, 1, 75),
       (6, 1, 100),
       (6, 2, 85),
       (1, 4, 100),
       (2, 5, 85),
       (1, 5, 50);