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
SELECT DISTINCT Students.StudentId, Students.StudentName, Groups.GroupName
FROM Students
       NATURAL JOIN Marks
       NATURAL JOIN Courses
       NATURAL JOIN Groups
WHERE Courses.CourseName = 'Базы данных'
  AND Marks.Mark <= ?
  AND Marks.Mark >= ?;

-- Информацию о студентах не имеющих оценки по предмету «Базы данных» среди всех студентов
WITH CorrectCourses AS (
  SELECT Courses.CourseId
  FROM Courses
  WHERE Courses.CourseName = 'Базы данных'
)
SELECT DISTINCT CorrectStudents.StudentId,
                CorrectStudents.StudentName,
                Groups.GroupName
FROM (SELECT DISTINCT Students.StudentId,
                      Students.StudentName,
                      Students.GroupId
      FROM Students EXCEPT ALL (SELECT DISTINCT Students.StudentId,
                                                Students.StudentName,
                                                Students.GroupId
                                FROM Students
                                       NATURAL JOIN Marks
                                       NATURAL JOIN CorrectCourses)) AS CorrectStudents
       NATURAL JOIN Groups;

-- Информацию о студентах не имеющих оценки по предмету «Базы данных» среди студентов,
-- у которых есть этот предмет
WITH CorrectCourses AS (
  SELECT Courses.CourseId
  FROM Courses
  WHERE Courses.CourseName = 'Базы данных'
)
SELECT DISTINCT CorrectStudents.StudentId,
                CorrectStudents.StudentName,
                Groups.GroupName
FROM (SELECT DISTINCT Students.StudentId,
                      Students.StudentName,
                      Students.GroupId
      FROM Students
             NATURAL JOIN Plan
             NATURAL JOIN CorrectCourses
        EXCEPT ALL (SELECT DISTINCT Students.StudentId,
                                    Students.StudentName,
                                    Students.GroupId
                    FROM Students
                           NATURAL JOIN Marks
                           NATURAL JOIN CorrectCourses)) AS CorrectStudents
       NATURAL JOIN Groups;


-- Информацию о студентах, имеющих хотя бы одну оценку у заданного лектора
SELECT DISTINCT Students.StudentId,
                Students.StudentName,
                Groups.GroupName
FROM Students
       NATURAL JOIN Groups
       NATURAL JOIN Marks
       NATURAL JOIN Plan
WHERE Plan.LecturerId = ?;

-- Идентификаторы студентов, не имеющих ни одной оценки у заданного лектора
SELECT DISTINCT Students.StudentId
FROM Students EXCEPT ALL (
  SELECT DISTINCT Students.StudentId
  FROM Students
         NATURAL JOIN Marks
         NATURAL JOIN Plan
  WHERE Plan.LecturerId = ?
);

-- Студентов, имеющих оценки по всем предметам заданного лектора
WITH StudentsWithCourses AS (
  SELECT DISTINCT Students.StudentId,
                  Students.StudentName,
                  Groups.GroupName,
                  Marks.CourseId,
                  Plan.Lecturerid
  FROM Students
         NATURAL JOIN Groups
         LEFT OUTER JOIN Marks USING (StudentId)
         LEFT OUTER JOIN Plan USING (GroupId, CourseId)
),
     ProperLecturerCourses AS (
       SELECT DISTINCT Plan.CourseId,
                       Plan.LecturerId
       FROM Plan
       WHERE LecturerId = ?
     )
SELECT DISTINCT StudentsWithCourses.StudentId,
                StudentsWithCourses.StudentName,
                StudentsWithCourses.GroupName
FROM StudentsWithCourses EXCEPT ALL (
  SELECT DISTINCT StudentsWithNotAllCourses.StudentId,
                  StudentsWithNotAllCourses.StudentName,
                  StudentsWithNotAllCourses.GroupName
  FROM (
         (SELECT DISTINCT StudentsWithCourses.StudentId,
                          StudentsWithCourses.StudentName,
                          StudentsWithCourses.GroupName,
                          ProperLecturerCourses.CourseId,
                          ProperLecturerCourses.LecturerId
          FROM StudentsWithCourses
                 CROSS JOIN ProperLecturerCourses)
         EXCEPT
         ALL
         (SELECT DISTINCT StudentsWithCourses.StudentId,
                          StudentsWithCourses.StudentName,
                          StudentsWithCourses.GroupName,
                          StudentsWithCourses.CourseId,
                          StudentsWithCourses.Lecturerid
          FROM StudentsWithCourses)
       ) AS StudentsWithNotAllCourses
);

-- Для каждого студента имя и названия предметов, которые он должен посещать
SELECT DISTINCT NotMarkedCourses.StudentId,
                NotMarkedCourses.StudentName,
                NotMarkedCourses.CourseName
FROM (
       (SELECT DISTINCT Students.StudentId,
                        Students.StudentName,
                        Courses.CourseId,
                        Courses.CourseName
        FROM Students
               NATURAL JOIN Plan
               NATURAL JOIN Courses)
       EXCEPT
       ALL
       (
         SELECT DISTINCT Students.StudentId,
                         Students.StudentName,
                         Courses.CourseId,
                         Courses.CourseName
         FROM Students
                NATURAL JOIN Marks
                NATURAL JOIN Courses
       )
     ) AS NotMarkedCourses;

-- По лектору всех студентов, у которых он хоть что-нибудь преподавал
SELECT DISTINCT Lecturers.LecturerId,
                Lecturers.LecturerName,
                Students.StudentId,
                Students.StudentName,
                Groups.GroupName
FROM Plan
       NATURAL JOIN Lecturers
       NATURAL JOIN Students
       NATURAL JOIN Groups;

SELECT DISTINCT Lecturers.LecturerId,
                Lecturers.LecturerName,
                LecturerStudents.StudentId,
                LecturerStudents.StudentName,
                LecturerStudents.GroupName
FROM (SELECT Students.StudentId,
             Students.StudentName,
             Groups.GroupName,
             Plan.LecturerId
      FROM Plan
             NATURAL JOIN Students
             NATURAL JOIN Groups
      WHERE Plan.LecturerId = ?) AS LecturerStudents
       NATURAL JOIN Lecturers;


-- Пары студентов, такие, что все сданные первым студентом предметы сдал и второй студент
WITH StudentsWithPassedCourses AS (
  SELECT DISTINCT Students.StudentId, Marks.CourseId
  FROM Students
         NATURAL JOIN Marks
  WHERE Marks.Mark >= 60
),
     StudentsWithPassedCourses1 AS (
       SELECT DISTINCT StudentsWithPassedCourses.StudentId AS StudentId1,
                       StudentsWithPassedCourses.CourseId
       FROM StudentsWithPassedCourses
     ),
     StudentsWithPassedCourses2 AS (
       SELECT DISTINCT StudentsWithPassedCourses.StudentId AS StudentId2,
                       StudentsWithPassedCourses.CourseId
       FROM StudentsWithPassedCourses
     ),
     Students1 AS (
       SELECT DISTINCT StudentsWithPassedCourses1.StudentId1 FROM StudentsWithPassedCourses1
     ),
     Students2 AS (
       SELECT DISTINCT StudentsWithPassedCourses2.StudentId2 FROM StudentsWithPassedCourses2
     ),
     AllStudentsPairs AS (
       SELECT DISTINCT Students1.StudentId1,
                       Students2.StudentId2
       FROM Students1
              CROSS JOIN Students2
     ),
     IncorrectPairs AS (
       SELECT DISTINCT Pairs.StudentId1, Pairs.StudentId2
       FROM ((SELECT DISTINCT Students2.StudentId2,
                              StudentsWithPassedCourses1.StudentId1,
                              StudentsWithPassedCourses1.CourseId
              FROM Students2
                     CROSS JOIN StudentsWithPassedCourses1)
             EXCEPT
             ALL
             (SELECT DISTINCT StudentsWithPassedCourses2.StudentId2,
                              StudentsWithPassedCourses1.StudentId1,
                              StudentsWithPassedCourses1.CourseId
              FROM StudentsWithPassedCourses2
                     NATURAL JOIN StudentsWithPassedCourses1)
            ) AS Pairs
     ),
     NonTrivialPairs AS (
       SELECT DISTINCT Pairs.StudentId1, Pairs.Studentid2
       FROM (SELECT DISTINCT AllStudentsPairs.StudentId1,
                             AllStudentsPairs.StudentId2
             FROM AllStudentsPairs EXCEPT ALL
             SELECT DISTINCT IncorrectPairs.StudentId1,
                             IncorrectPairs.StudentId2
             FROM IncorrectPairs) AS Pairs),
     AllStudents AS (
       SELECT DISTINCT Students.StudentId
       FROM Students
     ),
     StudentsWithoupPassedCourses AS (
       SELECT DISTINCT Studs.StudentId
       FROM (
              (SELECT DISTINCT AllStudents.StudentId
               FROM AllStudents)
              EXCEPT
              ALL
              (
                SELECT DISTINCT StudentsWithPassedCourses.StudentId
                FROM StudentsWithPassedCourses
              )
            ) AS Studs
     ),
     TrivialPairs AS (
       SELECT DISTINCT StudentsWithoupPassedCourses.StudentId AS StudentId1,
                       Students.StudentId                     AS StudentId2
       FROM StudentsWithoupPassedCourses
              CROSS JOIN Students
     ),
     AllPairs AS (
       SELECT DISTINCT Pairs.StudentId1,
                       Pairs.StudentId2
       FROM (
                (SELECT StudentId1, StudentId2 FROM NonTrivialPairs)
                UNION
                DISTINCT
                (
                  SELECT StudentId1, StudentId2
                  FROM TrivialPairs
                )
            ) AS Pairs
       WHERE Pairs.StudentId1 <> Pairs.StudentId2
     ),
     WithNames1 AS (
       SELECT DISTINCT AllPairs.StudentId1,
                       AllPairs.StudentId2,
                       Students.StudentName as StudentName1
       FROM AllPairs
              INNER JOIN Students ON Students.StudentId = AllPairs.StudentId1
     )
SELECT DISTINCT WithNames1.StudentId1,
                WithNames1.StudentName1,
                WithNames1.StudentId2,
                Students.StudentName as StudentName2
FROM WithNames1
       INNER JOIN Students ON Students.StudentId = WithNames1.StudentId2;

-- Такие группы и предметы, что все студенты группы сдали предмет
WITH StudentsWithPassedCourses AS (
  SELECT DISTINCT Marks.CourseId,
                  Students.StudentId
  FROM Students
         NATURAL JOIN Marks
  WHERE Marks.Mark >= 60
),
     GroupWithStudents AS (
       SELECT DISTINCT Students.StudentId,
                       Students.GroupId
       FROM Students
     ),
     AllCourses AS (
       SELECT DISTINCT StudentsWithPassedCourses.CourseId
       FROM StudentsWithPassedCourses
     ),
     AllGroups AS (
       SELECT DISTINCT GroupWithStudents.GroupId
       FROM GroupWithStudents
     ),
     AllGroupsWithSubjects AS (
       SELECT DISTINCT AllCourses.CourseId,
                       AllGroups.GroupId
       FROM AllCourses
              CROSS JOIN AllGroups
     ),
     tmp1 AS (
       SELECT DISTINCT AllCourses.CourseId,
                       GroupWithStudents.StudentId,
                       GroupWithStudents.GroupId
       FROM AllCourses
              CROSS JOIN GroupWithStudents
     ),
     tmp2 AS (
       SELECT DISTINCT StudentsWithPassedCourses.CourseId,
                       GroupWithStudents.StudentId,
                       GroupWithStudents.GroupId
       FROM StudentsWithPassedCourses
              NATURAL JOIN GroupWithStudents
     ),
     IncorrectPairs AS (
       SELECT DISTINCT Res.CourseId,
                       Res.GroupId
       FROM (SELECT DISTINCT Setminus.CourseId,
                             Setminus.StudentId,
                             Setminus.GroupId
             FROM (SELECT DISTINCT tmp1.CourseId,
                                   tmp1.StudentId,
                                   tmp1.GroupId
                   FROM tmp1 EXCEPT ALL
                   SELECT DISTINCT tmp2.CourseId,
                                   tmp2.StudentId,
                                   tmp2.GroupId
                   FROM tmp2
                  ) AS Setminus
            ) AS Res
     ),
     CorrectPairs AS (
       SELECT DISTINCT Result.CourseId,
                       Result.GroupId
       FROM (SELECT DISTINCT AllGroupsWithSubjects.CourseId,
                             AllGroupsWithSubjects.GroupId
             FROM AllGroupsWithSubjects EXCEPT ALL
             SELECT DISTINCT IncorrectPairs.CourseId,
                             IncorrectPairs.GroupId
             FROM IncorrectPairs
            ) AS Result
     )
SELECT DISTINCT CorrectPairs.CourseId,
                Courses.CourseName,
                Correctpairs.GroupId,
                Groups.GroupName
FROM CorrectPairs
       NATURAL JOIN courses
       NATURAL JOIN Groups;

-- Средний балл студента по идентификатору
SELECT DISTINCT avg(Marks.Mark)
FROM Students
       NATURAL JOIN Marks
WHERE Students.StudentId = ?;

-- Средний балл студента для всех студентов
SELECT DISTINCT Students.StudentId,
                Students.StudentName,
                avg(Marks.Mark)
FROM Students
       NATURAL JOIN Marks
GROUP BY (Students.StudentId, students.StudentName);

-- Средний балл средних баллов студентов каждой группы
WITH AllMarks AS (
  SELECT DISTINCT Students.StudentId,
                  Groups.GroupId,
                  Groups.GroupName,
                  Marks.CourseId,
                  Marks.Mark
  FROM Students
         NATURAL JOIN Groups
         NATURAL JOIN Marks
),
     AverageByStudents AS (
       SELECT DISTINCT AllMarks.StudentId,
                       AllMarks.GroupId,
                       AllMarks.GroupName,
                       avg(AllMarks.Mark) AS Mark
       FROM AllMarks
       GROUP BY (AllMarks.StudentId, AllMarks.Groupid, AllMarks.GroupName)
     )
SELECT DISTINCT AverageByStudents.GroupId,
                AverageByStudents.GroupName,
                avg(AverageByStudents.Mark)
FROM AverageByStudents
GROUP BY (AverageByStudents.GroupId, AverageByStudents.GroupName);

-- Для каждого студента число предметов, которые у него были,
-- число сданных предметов и число несданных предметов
WITH StudentsTotalCourses AS (
  SELECT DISTINCT Students.StudentId,
                  Students.StudentName,
                  count(*) AS TotalCourses
  FROM students
         NATURAL JOIN Plan
  GROUP BY (Students.StudentId, Students.StudentName)
),
     OnlyPassedCourses AS (
       SELECT Marks.StudentId, Marks.CourseId
       FROM Marks
       WHERE Marks.Mark >= 60
     ),
     StudentsPassedCourses AS (
       SELECT DISTINCT Students.StudentId,
                       Students.StudentName,
                       count(OnlyPassedCourses.CourseId) AS PassedCourses
       FROM Students
              LEFT OUTER JOIN OnlyPassedCourses
                              ON OnlyPassedCourses.StudentId = Students.StudentId
       GROUP BY (Students.StudentId, Students.StudentName)
     )
SELECT DISTINCT StudentsTotalCourses.StudentId,
                StudentsTotalCourses.StudentName,
                StudentsTotalCourses.TotalCourses,
                StudentsPassedCourses.PassedCourses,
                StudentsTotalCourses.TotalCourses - StudentsPassedCourses.PassedCourses
                  AS NotPassedCoursed
FROM StudentsTotalCourses
       NATURAL JOIN StudentsPassedCourses;


