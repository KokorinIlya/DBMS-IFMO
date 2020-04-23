\C CTD;

SELECT (Lecturers.surname, Courses.name, Groups.name)
FROM StudyPlan
       JOIN Lecturers ON StudyPlan.lecturer_id = Lecturers.id
       JOIN Courses ON StudyPlan.course_id = Courses.id
       JOIN Groups ON StudyPlan.group_id = Groups.id;

SELECT (Students.surname, Courses.name, Scores.score)
FROM Scores
       JOIN Students ON Scores.student_id = Students.id
       JOIN Courses ON Scores.course_id = Courses.id;