library(learnrTrackR)

db_path <- tempfile(fileext = ".sqlite")
con <- init_tracking_db(db_path, overwrite = TRUE)

register_questions(
  con,
  tutorial_id = "module_01",
  questions = data.frame(
    question_id = c("q1", "q2", "q3"),
    max_score = c(1, 1, 1)
  )
)

track_attempt(
  con = con,
  student_id = "student_001",
  tutorial_id = "module_01",
  question_id = "q1",
  submitted_answer = "mean(x)",
  grade_status = "correct",
  score = 1,
  max_score = 1,
  feedback = "Correct."
)

track_attempt(
  con = con,
  student_id = "student_001",
  tutorial_id = "module_01",
  question_id = "q2",
  submitted_answer = "summarise(df, x = mean(x))",
  grade_status = "partial",
  score = 0.5,
  max_score = 1,
  feedback = "Good idea, but check grouping."
)

get_attempts(con)

compute_scores(con, tutorial_id = "module_01", rule = "last")

gradebook(con, tutorial_id = "module_01", rule = "last")

export_results(con, tempfile(fileext = ".csv"), type = "attempts")
export_results(con, tempfile(fileext = ".csv"), type = "scores")
export_results(
  con,
  tempfile(fileext = ".csv"),
  type = "gradebook",
  tutorial_id = "module_01"
)
export_moodle_grades(
  con,
  tempfile(fileext = ".csv"),
  tutorial_id = "module_01",
  grade_item = "Module 01 quiz"
)

DBI::dbDisconnect(con)
