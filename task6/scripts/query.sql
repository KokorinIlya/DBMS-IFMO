\C CTD;

SELECT Students.StudentName,
       Groups.GroupName,
       Lecturers.LecturerName,
       Courses.CourseName,
       Marks.Mark
FROM Students
       INNER JOIN Groups ON Groups.GroupId = Students.GroupId
       FULL OUTER JOIN Marks ON Marks.StudentId = Students.StudentId
       FULL OUTER JOIN Plan ON Plan.CourseId = Marks.CourseId AND Plan.GroupId = Students.GroupId
       FULL OUTER JOIN Lecturers ON Lecturers.LecturerId = Plan.LecturerId
       FULL OUTER JOIN Courses ON Courses.CourseId = Marks.CourseId;

-- Информацию о студентах, с заданной оценкой по предмету «Базы данных»
WITH DatabaseCourse AS (
  SELECT DISTINCT *
  FROM Courses
  WHERE Courses.CourseName = 'Базы данных'
),
     StudentsWithCorrectMarks AS (
       SELECT DISTINCT Students.StudentId, Students.StudentName, Students.GroupId
       FROM Students
       WHERE EXISTS(SELECT DISTINCT *
                    FROM DatabaseCourse
                    WHERE EXISTS(SELECT DISTINCT *
                                 FROM Marks
                                 WHERE Marks.Mark <= ?
                                   AND Marks.Mark >= ?
                                   AND Marks.StudentId = Students.StudentId
                                   AND Marks.CourseId = DatabaseCourse.CourseId))
     )
SELECT DISTINCT StudentsWithCorrectMarks.StudentId,
                StudentsWithCorrectMarks.StudentName,
                Groups.GroupName
FROM StudentsWithCorrectMarks
       NATURAL JOIN Groups;

-- Информацию о студентах не имеющих оценки по предмету «Базы данных»:
-- среди всех студентов
WITH DatabaseCourse AS (
  SELECT DISTINCT *
  FROM Courses
  WHERE Courses.CourseName = 'Базы данных'
),
     StudentsWithNoMarks AS (
       SELECT DISTINCT Students.StudentId, Students.StudentName, Students.GroupId
       FROM Students
       WHERE EXISTS(SELECT DISTINCT *
                    FROM DatabaseCourse
                    WHERE NOT EXISTS(SELECT DISTINCT *
                                     FROM Marks
                                     WHERE Marks.StudentId = Students.StudentId
                                       AND Marks.CourseId = DatabaseCourse.CourseId))
     )
SELECT StudentsWithNoMarks.StudentId,
       StudentsWithNoMarks.StudentName,
       Groups.Groupname
FROM StudentsWithNoMarks
       NATURAL JOIN Groups;

-- Информацию о студентах не имеющих оценки по предмету «Базы данных»:
-- среди студентов, у которых есть этот предмет
WITH DatabaseCourse AS (
  SELECT DISTINCT *
  FROM Courses
  WHERE Courses.CourseName = 'Базы данных'
),
     StudentsWithNoMarks AS (
       SELECT DISTINCT Students.StudentId,
                       Students.StudentName,
                       Students.GroupId
       FROM Students
       WHERE EXISTS(SELECT DISTINCT *
                    FROM DatabaseCourse
                    WHERE EXISTS(
                        SELECT DISTINCT *
                        FROM Plan
                        WHERE Plan.CourseId = DatabaseCourse.CourseId
                          AND Plan.GroupId = Students.GroupId
                      )
                      AND NOT EXISTS(SELECT DISTINCT *
                                     FROM Marks
                                     WHERE Marks.StudentId = Students.StudentId
                                       AND Marks.CourseId = DatabaseCourse.CourseId))
     )
SELECT StudentsWithNoMarks.StudentId,
       StudentsWithNoMarks.StudentName,
       Groups.Groupname
FROM StudentsWithNoMarks
       NATURAL JOIN Groups;

-- Информацию о студентах, имеющих хотя бы одну оценку у заданного лектора
WITH LecturerCourses AS (
  SELECT DISTINCT Plan.GroupId,
                  Plan.CourseId
  FROM Plan
  WHERE Plan.LecturerId = ?
),
     StudentsWithMarks AS (
       SELECT DISTINCT Students.StudentId,
                       Students.StudentName,
                       Students.GroupId
       FROM Students
       WHERE EXISTS(
                 SELECT *
                 FROM Marks
                 WHERE Marks.StudentId = Students.StudentId
                   AND EXISTS(
                     SELECT *
                     FROM LecturerCourses
                     WHERE LecturerCourses.GroupId = Students.GroupId
                       AND LecturerCourses.CourseId = Marks.CourseId
                   )
               )
     )
SELECT StudentsWithMarks.StudentId,
       StudentsWithMarks.StudentName,
       Groups.Groupname
FROM StudentsWithMarks
       NATURAL JOIN Groups;

-- Идентификаторы студентов, не имеющих ни одной оценки у заданного лектора
WITH LecturerCourses AS (
  SELECT DISTINCT Plan.GroupId,
                  Plan.CourseId
  FROM Plan
  WHERE Plan.LecturerId = ?
),
     StudentsWithMarks AS (
       SELECT DISTINCT Students.StudentId,
                       Students.StudentName,
                       Students.GroupId
       FROM Students
       WHERE EXISTS(
                 SELECT *
                 FROM Marks
                 WHERE Marks.StudentId = Students.StudentId
                   AND EXISTS(
                     SELECT *
                     FROM LecturerCourses
                     WHERE LecturerCourses.GroupId = Students.GroupId
                       AND LecturerCourses.CourseId = Marks.CourseId
                   )
               )
     )
SELECT Students.StudentId
FROM Students
WHERE Students.StudentId NOT IN (SELECT StudentsWithMarks.StudentId FROM StudentsWithMarks);

-- Студентов, имеющих оценки по всем предметам заданного лектора

WITH CorrectLecturerCourses AS (
  SELECT DISTINCT Plan.CourseId,
                  Plan.LecturerId
  FROM Plan
  WHERE Plan.LecturerId = ?
),
     CorrectLecturerMarks AS (
       SELECT DISTINCT Students.StudentId,
                       Marks.CourseId
       FROM Students
              NATURAL JOIN Plan
              NATURAL JOIN Marks
       WHERE Plan.LecturerId = (SELECT DISTINCT CorrectLecturerCourses.LecturerId
                                FROM CorrectLecturerCourses)
     ),
     WithoutAtLeastOneMark AS (
       SELECT DISTINCT Students.StudentId
       FROM Students,
            CorrectLecturerCourses
       WHERE NOT EXISTS(SELECT DISTINCT *
                        FROM CorrectLecturerMarks
                        WHERE CorrectLecturerMarks.StudentId = Students.StudentId
                          AND CorrectLecturerMarks.CourseId = CorrectLecturerCourses.CourseId
         )
     ),
     WithAllMarks AS (
         (SELECT DISTINCT Students.StudentId FROM Students)
         EXCEPT
         ALL
         (SELECT DISTINCT WithoutAtLeastOneMark.StudentId FROM WithoutAtLeastOneMark)
     )
SELECT DISTINCT WithAllMarks.StudentId,
                Students.StudentName,
                Groups.GroupName
FROM WithAllMarks
       NATURAL JOIN students
       NATURAL JOIN Groups;

-- Для каждого студента имя и предметы, которые он должен посещать
SELECT DISTINCT Students.StudentId,
                Students.StudentName,
                Plan.CourseId,
                Courses.CourseName
FROM (Students NATURAL JOIN Plan)
       NATURAL JOIN Courses
WHERE NOT EXISTS(SELECT *
                 FROM Marks
                 WHERE Marks.CourseId = Plan.CourseId
                   AND Marks.StudentId = Students.StudentId
                   AND Marks.Mark >= 60);

-- По лектору всех студентов, у которых он хоть что-нибудь преподавал
-- Для заданного лектора
WITH LectureGroups AS (
  SELECT DISTINCT Plan.GroupId
  FROM Plan
  WHERE Plan.LecturerId = ?
),
     LecturerStudents AS (
       SELECT DISTINCT Students.StudentId,
                       Students.StudentName,
                       Students.GroupId
       FROM Students
       WHERE EXISTS(SELECT *
                    FROM LectureGroups
                    WHERE LectureGroups.GroupId = Students.GroupId)
     )
SELECT DISTINCT LecturerStudents.StudentId,
                LecturerStudents.StudentName,
                Groups.GroupName
FROM LecturerStudents
       NATURAL JOIN Groups;

-- По лектору всех студентов, у которых он хоть что-нибудь преподавал
-- Для каждого лектора
SELECT DISTINCT Lecturers.LecturerId,
                Lecturers.LecturerName,
                Students.StudentId,
                Students.StudentName,
                Groups.GroupName
FROM Plan
       NATURAL JOIN Lecturers
       NATURAL JOIN Students
       NATURAL JOIN Groups;

-- Пары студентов, такие, что все сданные первым студентом предметы сдал и второй студент
WITH IncorrectPairs AS (
  SELECT DISTINCT Students1.StudentId AS StudentId1,
                  Students2.StudentId AS StudentId2
  FROM Students AS Students1,
       Students AS Students2
  WHERE EXISTS(
            SELECT DISTINCT *
            FROM Courses
            WHERE EXISTS(SELECT *
                         FROM Marks
                         WHERE Marks.StudentId = Students1.StudentId
                           AND Marks.CourseId = Courses.CourseId
                           AND Marks.Mark >= 60)
              AND NOT EXISTS(SELECT *
                             FROM Marks
                             WHERE Marks.StudentId = Students2.StudentId
                               AND Marks.CourseId = Courses.CourseId
                               AND Marks.Mark >= 60)
          )
),
     CorrectPairs AS (
       ((SELECT DISTINCT Students1.StudentId AS StudentId1,
                         Students2.StudentId AS StudentId2
         FROM Students AS Students1,
              Students AS Students2)
        EXCEPT
        ALL
        (SELECT DISTINCT IncorrectPairs.StudentId1,
                         IncorrectPairs.StudentId2
         FROM IncorrectPairs))
     )
SELECT DISTINCT CorrectPairs.StudentId1,
                CorrectPairs.StudentId2,
                Students1.StudentName AS StudentName1,
                Students2.StudentName AS StudentName2,
                Groups1.GroupName     AS GroupName1,
                Groups2.GroupName     AS GroupName2
FROM CorrectPairs
       INNER JOIN Students AS Students1 ON CorrectPairs.StudentId1 = Students1.StudentId
       INNER JOIN Students AS Students2 ON CorrectPairs.StudentId2 = Students2.StudentId
       INNER JOIN Groups AS Groups1 ON Students1.GroupId = Groups1.GroupId
       INNER JOIN Groups AS Groups2 ON Students2.GroupId = Groups2.GroupId
WHERE CorrectPairs.StudentId1 <> CorrectPairs.StudentId2;

-- Такие группы и предметы, что все студенты группы сдали предмет
WITH IncorrectPairs AS (
  SELECT DISTINCT Groups.GroupId,
                  Courses.CourseId
  FROM Courses,
       (Groups
         NATURAL JOIN Students)
  WHERE NOT EXISTS(
      SELECT *
      FROM Marks
      WHERE Marks.StudentId = Students.StudentId
        AND Marks.CourseId = Courses.CourseId
        AND Marks.Mark >= 60
    )
),
     CorrectPairs AS (
       (SELECT DISTINCT Groups.GroupId,
                        Courses.CourseId
        FROM Groups,
             Courses)
       EXCEPT
       ALL
       (SELECT DISTINCT IncorrectPairs.GroupId,
                        IncorrectPairs.CourseId
        FROM IncorrectPairs)
     )
SELECT DISTINCT CorrectPairs.GroupId,
                Groups.GroupName,
                CorrectPairs.CourseId,
                Courses.CourseName
FROM CorrectPairs
       NATURAL JOIN Groups
       NATURAL JOIN Courses;