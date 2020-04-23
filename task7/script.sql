-- Напишите запрос, удаляющий всех студентов, не имеющих долгов.
WITH StudentsWithStudiedCoursesCount AS (
  SELECT Students.StudentId,
         count(Plan.CourseId) AS StudiedCoursesCount
  FROM Students
         LEFT OUTER JOIN Plan ON
    Students.GroupId = Plan.GroupId
  GROUP BY (Students.StudentId)
),
     OnlyPassedCoursesMarks AS (
       SELECT Marks.StudentId,
              Marks.CourseId,
              Marks.Mark
       FROM Marks
       WHERE Marks.Mark >= 60
     ),
     StudentsWithPassedCoursesCount AS (
       SELECT Students.StudentId,
              count(OnlyPassedCoursesMarks.Mark) AS PassedCoursesCount
       FROM Students
              LEFT OUTER JOIN OnlyPassedCoursesMarks ON
         Students.StudentId = OnlyPassedCoursesMarks.StudentId
       GROUP BY (Students.StudentId)
     ),
     StudentsWitouthDepts AS (
       SELECT StudentId
       FROM StudentsWithStudiedCoursesCount
              NATURAL JOIN StudentsWithPassedCoursesCount
       WHERE PassedCoursesCount = StudiedCoursesCount
     )
DELETE
FROM Students
WHERE Students.StudentId IN (
  SELECT StudentsWitouthDepts.StudentId
  FROM StudentsWitouthDepts
);

-- Напишите запрос, удаляющий всех студентов, имеющих 3 и более долгов
WITH StudentsWithStudiedCoursesCount AS (
  SELECT Students.StudentId,
         count(Plan.CourseId) AS StudiedCoursesCount
  FROM Students
         LEFT OUTER JOIN Plan ON
    Students.GroupId = Plan.GroupId
  GROUP BY (Students.StudentId)
),
     OnlyPassedCoursesMarks AS (
       SELECT Marks.StudentId,
              Marks.CourseId,
              Marks.Mark
       FROM Marks
       WHERE Marks.Mark >= 60
     ),
     StudentsWithPassedCoursesCount AS (
       SELECT Students.StudentId,
              count(OnlyPassedCoursesMarks.Mark) AS PassedCoursesCount
       FROM Students
              LEFT OUTER JOIN OnlyPassedCoursesMarks ON
         Students.StudentId = OnlyPassedCoursesMarks.StudentId
       GROUP BY (Students.StudentId)
     ),
     Losers AS (
       SELECT StudentId
       FROM StudentsWithStudiedCoursesCount
              NATURAL JOIN StudentsWithPassedCoursesCount
       WHERE StudiedCoursesCount - PassedCoursesCount >= 3
     )
DELETE
FROM Students
WHERE Students.StudentId IN (
  SELECT Losers.StudentId
  FROM Losers
);


-- Напишите запрос, удаляющий все группы, в которых нет студентов
WITH GroupsWithStudents AS (
  SELECT DISTINCT Students.GroupId
  FROM Students
)
DELETE
FROM Groups
WHERE Groups.GroupId NOT IN (
  SELECT GroupsWithStudents.GroupId
  FROM GroupsWithStudents
);

-- Создайте view Losers в котором для каждого студента, имеющего долги указано их количество

CREATE VIEW Losers AS (
  WITH StudentsWithStudiedCoursesCount AS (
    SELECT Students.StudentId,
           Students.StudentName,
           count(Plan.CourseId) AS StudiedCoursesCount
    FROM Students
           LEFT OUTER JOIN Plan USING (GroupId)
    GROUP BY (Students.StudentId)
  ),
       OnlyPassedCoursesMarks AS (
         SELECT Marks.StudentId,
                Marks.CourseId,
                Marks.Mark
         FROM Marks
         WHERE Marks.Mark >= 60
       ),
       StudentsWithPassedCoursesCount AS (
         SELECT Students.StudentId,
                Students.StudentName,
                Students.GroupId,
                count(OnlyPassedCoursesMarks.Mark) AS PassedCoursesCount
         FROM Students
                LEFT OUTER JOIN OnlyPassedCoursesMarks USING (StudentId)
         GROUP BY (Students.StudentId)
       )
  SELECT StudentsWithStudiedCoursesCount.StudentId,
         StudentsWithStudiedCoursesCount.StudentName,
         StudiedCoursesCount - PassedCoursesCount AS DeptsCount
  FROM StudentsWithStudiedCoursesCount
         INNER JOIN StudentsWithPassedCoursesCount USING (StudentId)
  WHERE StudiedCoursesCount > PassedCoursesCount
);

-- Создайте таблицу LoserT, в которой содержится та же информация, что во view Losers.
-- Эта таблица должна автоматически обновляться при изменении таблицы с баллами
CREATE MATERIALIZED VIEW LoserT AS (
  SELECT Losers.StudentId,
         Losers.StudentName,
         Losers.DeptsCount
  FROM Losers
);

CREATE OR REPLACE FUNCTION refreshLosers() RETURNS TRIGGER AS
$refreshLosers$
BEGIN
  REFRESH MATERIALIZED VIEW LoserT;
END;
$refreshLosers$ LANGUAGE plpgsql;

CREATE TRIGGER UpdateLoserTWhenMarksChanged
  AFTER INSERT OR UPDATE OR DELETE
  ON Marks
  FOR EACH STATEMENT
EXECUTE PROCEDURE refreshLosers();

-- Отключите автоматическое обновление таблицы LoserT.

DROP TRIGGER IF EXISTS UpdateLoserTWhenMarksChanged ON Marks;


-- Добавьте проверку того, что все студенты одной группы изучают один и тот же набор курсов
-- Набор предметов, изучаемых студентом, определяется его группой (в таблице Plan).
-- Поэтому, такая проверка выполняется автоматически.

-- Создайте триггер, не позволяющий уменьшить баллы студента по предмету.
-- При попытке такого изменения баллы изменяться не должны
CREATE OR REPLACE FUNCTION checkMarksNotDecreased() RETURNS TRIGGER AS
$checkMarksNotDecreased$
BEGIN
  IF NEW.Mark < OLD.Mark THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$checkMarksNotDecreased$ LANGUAGE plpgsql;

CREATE TRIGGER NotAllowDecreaseMarks
  BEFORE UPDATE
  ON Marks
  FOR EACH ROW
EXECUTE PROCEDURE checkMarksNotDecreased();