test_that("export_results writes attempts and scores CSV files", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  attempts_path <- withr::local_tempfile(fileext = ".csv")
  scores_path <- withr::local_tempfile(fileext = ".csv")

  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  track_attempt(
    con,
    "student_001",
    "module_01",
    "q1",
    "mean(x)",
    score = 1,
    max_score = 1
  )

  expect_invisible(export_results(con, attempts_path, type = "attempts"))
  expect_invisible(export_results(con, scores_path, type = "scores"))

  expect_true(file.exists(attempts_path))
  expect_true(file.exists(scores_path))

  attempts <- readr::read_csv(attempts_path, show_col_types = FALSE)
  scores <- readr::read_csv(scores_path, show_col_types = FALSE)

  expect_equal(nrow(attempts), 1)
  expect_equal(nrow(scores), 1)
  expect_true("submitted_answer" %in% names(attempts))
  expect_true("percent" %in% names(scores))
})

test_that("export_results writes gradebook CSV files", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  gradebook_path <- withr::local_tempfile(fileext = ".csv")

  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_questions(con, "module_01", c("q1", "q2"))
  track_attempt(
    con,
    "student_001",
    "module_01",
    "q1",
    "mean(x)",
    score = 1,
    max_score = 1
  )

  expect_invisible(
    export_results(
      con,
      gradebook_path,
      type = "gradebook",
      tutorial_id = "module_01"
    )
  )

  grades <- readr::read_csv(gradebook_path, show_col_types = FALSE)

  expect_equal(nrow(grades), 1)
  expect_true("completed" %in% names(grades))
  expect_equal(grades$n_unanswered, 1)
})

test_that("moodle_grades creates a wide Moodle-ready table", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_questions(con, "module_01", c("q1", "q2"))
  track_attempt(
    con,
    "student_001",
    "module_01",
    "q1",
    "mean(x)",
    score = 1,
    max_score = 1
  )

  grades <- moodle_grades(
    con,
    tutorial_id = "module_01",
    grade_item = "Module 01 quiz"
  )

  expect_s3_class(grades, "tbl_df")
  expect_equal(names(grades), c("useridnumber", "Module 01 quiz"))
  expect_equal(grades$useridnumber, "student_001")
  expect_equal(grades[["Module 01 quiz"]], 50)
})

test_that("moodle_grades can export raw scores and custom identifier columns", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_questions(
    con,
    "module_01",
    data.frame(question_id = c("q1", "q2"), max_score = c(2, 2))
  )
  track_attempt(
    con,
    "student_001",
    "module_01",
    "q1",
    "answer",
    score = 1.25,
    max_score = 2
  )

  grades <- moodle_grades(
    con,
    tutorial_id = "module_01",
    id_column = "email",
    grade_item = "Module 01 raw",
    grade_value = "score",
    digits = 1
  )

  expect_equal(names(grades), c("email", "Module 01 raw"))
  expect_equal(grades$email, "student_001")
  expect_equal(grades[["Module 01 raw"]], 1.2)
})

test_that("export_moodle_grades writes a Moodle-ready CSV", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  moodle_path <- withr::local_tempfile(fileext = ".csv")

  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_questions(con, "module_01", c("q1", "q2"))
  track_attempt(
    con,
    "student_001",
    "module_01",
    "q1",
    "mean(x)",
    score = 1,
    max_score = 1
  )

  expect_invisible(
    export_moodle_grades(
      con,
      moodle_path,
      tutorial_id = "module_01",
      grade_item = "Module 01 quiz"
    )
  )

  grades <- readr::read_csv(moodle_path, show_col_types = FALSE)

  expect_equal(names(grades), c("useridnumber", "Module 01 quiz"))
  expect_equal(grades[["Module 01 quiz"]], 50)
})

test_that("canvas_grades creates a Canvas Gradebook table", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_questions(con, "module_01", c("q1", "q2"))
  track_attempt(
    con,
    "student_001",
    "module_01",
    "q1",
    "mean(x)",
    score = 1,
    max_score = 1
  )

  grades <- canvas_grades(
    con,
    tutorial_id = "module_01",
    assignment = "Module 01 quiz"
  )

  expect_s3_class(grades, "tbl_df")
  expect_equal(
    names(grades),
    c("Student", "ID", "SIS User ID", "SIS Login ID", "Section", "Module 01 quiz")
  )
  expect_equal(grades$Student, "student_001")
  expect_equal(grades[["SIS User ID"]], "student_001")
  expect_equal(grades[["Module 01 quiz"]], 1)
})

test_that("canvas_grades can export percentages and custom identifier columns", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_students(
    con,
    data.frame(
      student_id = "student_001",
      student_label = "Student One",
      email = "student.one@example.test",
      group_id = "A"
    )
  )
  register_questions(
    con,
    "module_01",
    data.frame(question_id = c("q1", "q2"), max_score = c(2, 2))
  )
  track_attempt(
    con,
    "student_001",
    "module_01",
    "q1",
    "answer",
    score = 1.25,
    max_score = 2,
    require_registered_student = TRUE
  )

  grades <- canvas_grades(
    con,
    tutorial_id = "module_01",
    assignment = "Module 01 percent",
    student_id_column = "SIS Login ID",
    student_id_source = "email",
    grade_value = "percent",
    digits = 1
  )

  expect_equal(grades$Student, "Student One")
  expect_equal(grades[["SIS User ID"]], "")
  expect_equal(grades[["SIS Login ID"]], "student.one@example.test")
  expect_equal(grades$Section, "A")
  expect_equal(grades[["Module 01 percent"]], 31.2)
})

test_that("export_canvas_grades writes a Canvas Gradebook CSV", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  canvas_path <- withr::local_tempfile(fileext = ".csv")

  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_questions(con, "module_01", c("q1", "q2"))
  track_attempt(
    con,
    "student_001",
    "module_01",
    "q1",
    "mean(x)",
    score = 1,
    max_score = 1
  )

  expect_invisible(
    export_canvas_grades(
      con,
      canvas_path,
      tutorial_id = "module_01",
      assignment = "Module 01 quiz"
    )
  )

  grades <- readr::read_csv(canvas_path, show_col_types = FALSE)

  expect_equal(
    names(grades),
    c("Student", "ID", "SIS User ID", "SIS Login ID", "Section", "Module 01 quiz")
  )
  expect_equal(grades[["Module 01 quiz"]], 1)
})

test_that("canvas_grades filters by registered group", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_students(
    con,
    data.frame(
      student_id = c("student_001", "student_002", "student_003"),
      group_id = c("A", "B", "A")
    )
  )
  register_questions(con, "module_01", c("q1", "q2"))
  track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
  track_attempt(con, "student_002", "module_01", "q1", "sd(x)", score = 0, max_score = 1)

  grades <- canvas_grades(
    con,
    tutorial_id = "module_01",
    assignment = "Module 01 quiz",
    group_id = "A"
  )

  expect_equal(grades[["SIS User ID"]], c("student_001", "student_003"))
  expect_false("student_002" %in% grades[["SIS User ID"]])
})

test_that("canvas_grades rejects Canvas reserved assignment names", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_questions(con, "module_01", "q1")

  expect_error(
    canvas_grades(con, tutorial_id = "module_01", assignment = "Final Score"),
    "reserved"
  )
})

test_that("moodle_grades filters by registered group", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_students(
    con,
    data.frame(
      student_id = c("student_001", "student_002", "student_003"),
      group_id = c("A", "B", "A")
    )
  )
  register_questions(con, "module_01", c("q1", "q2"))
  track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
  track_attempt(con, "student_002", "module_01", "q1", "sd(x)", score = 0, max_score = 1)

  grades <- moodle_grades(
    con,
    tutorial_id = "module_01",
    grade_item = "Module 01 quiz",
    group_id = "A"
  )

  expect_equal(grades$useridnumber, c("student_001", "student_003"))
  expect_false("student_002" %in% grades$useridnumber)
})

test_that("tracking_export_data filters by group and student", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_students(
    con,
    data.frame(
      student_id = c("student_001", "student_002", "student_003"),
      group_id = c("A", "B", "A")
    )
  )
  register_questions(con, "module_01", c("q1", "q2"))
  track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
  track_attempt(con, "student_002", "module_01", "q1", "sd(x)", score = 0, max_score = 1)

  group_data <- tracking_export_data(con, tutorial_id = "module_01", group_id = "A")
  student_data <- tracking_export_data(
    con,
    tutorial_id = "module_01",
    student_id = "student_001"
  )

  expect_equal(group_data$students$student_id, c("student_001", "student_003"))
  expect_equal(group_data$attempts$student_id, "student_001")
  expect_equal(nrow(group_data$gradebook), 2)
  expect_equal(nrow(group_data$moodle_grades), 2)
  expect_equal(nrow(group_data$canvas_grades), 2)
  expect_equal(student_data$students$student_id, "student_001")
  expect_equal(nrow(student_data$gradebook), 1)
  expect_equal(nrow(student_data$canvas_grades), 1)
})

test_that("export_tracking_bundle writes all rich CSV files", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  out_dir <- withr::local_tempdir()
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_students(con, data.frame(student_id = "student_001", group_id = "A"))
  register_questions(con, "module_01", c("q1", "q2"))
  track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)

  paths <- export_tracking_bundle(
    con,
    out_dir,
    tutorial_id = "module_01",
    group_id = "A"
  )

  expect_true(all(file.exists(paths$path)))
  expect_equal(
    paths$table,
    c(
      "summary",
      "students",
      "attempts",
      "scores",
      "gradebook",
      "questions",
      "moodle_grades",
      "canvas_grades"
    )
  )

  gradebook_path <- paths$path[paths$table == "gradebook"]
  grades <- readr::read_csv(gradebook_path, show_col_types = FALSE)

  expect_equal(nrow(grades), 1)
  expect_true("group_id" %in% names(grades))
})
