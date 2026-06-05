test_that("setup_learnr_tracking creates a reusable context", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")

  tracking <- setup_learnr_tracking(
    tutorial_id = "minimal_learnr",
    student_id = "student_001",
    db_path = db_path,
    group_id = "A"
  )

  con <- open_learnr_tracking_db(tracking)
  withr::defer(DBI::dbDisconnect(con))
  students <- get_students(con)

  expect_s3_class(tracking, "learnrTrackR_context")
  expect_equal(tracking$student_id, "student_001")
  expect_equal(tracking$tutorial_id, "minimal_learnr")
  expect_equal(tracking$db_path, db_path)
  expect_true(file.exists(db_path))
  expect_equal(students$student_id, "student_001")
  expect_equal(students$group_id, "A")
})

test_that("setup_learnr_tracking can skip student registration", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")

  tracking <- setup_learnr_tracking(
    tutorial_id = "minimal_learnr",
    student_id = "student_001",
    db_path = db_path,
    register_student = FALSE
  )

  con <- open_learnr_tracking_db(tracking)
  withr::defer(DBI::dbDisconnect(con))

  expect_equal(nrow(get_students(con)), 0)
})

test_that("track_gradethis_attempt records and returns a gradethis grade", {
  skip_if_not_installed("gradethis")

  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  grade <- track_gradethis_attempt(
    con = con,
    student_id = "student_001",
    tutorial_id = "minimal_learnr",
    question_id = "q2_mean",
    submitted_answer = "mean(c(2, 4, 6))",
    correct = TRUE,
    feedback = "Correct.",
    max_score = 1
  )

  attempts <- get_attempts(con)

  expect_s3_class(grade, "gradethis_graded")
  expect_true(grade$correct)
  expect_equal(nrow(attempts), 1)
  expect_equal(attempts$grade_status, "correct")
  expect_equal(attempts$score, 1)
})

test_that("track_gradethis_attempt works inside grade_this", {
  skip_if_not_installed("gradethis")

  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  DBI::dbDisconnect(con)

  grader <- gradethis::grade_this({
    con <- init_tracking_db(db_path, overwrite = FALSE)
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    correct <- identical(.result, 4)

    track_gradethis_attempt(
      con = con,
      student_id = "student_001",
      tutorial_id = "minimal_learnr",
      question_id = "q2_mean",
      submitted_answer = .user_code,
      correct = correct,
      feedback = if (correct) "Correct." else "Try again.",
      max_score = 1
    )
  })

  grade <- grader(gradethis::mock_this_exercise(.user_code = 2 + 2))

  con <- connect_tracking_db(db_path)
  withr::defer(DBI::dbDisconnect(con))
  attempts <- get_attempts(con)

  expect_s3_class(grade, "gradethis_graded")
  expect_true(grade$correct)
  expect_equal(nrow(attempts), 1)
  expect_equal(attempts$submitted_answer, "2 + 2")
})

test_that("track_gradethis_attempt can use a learnr tracking context", {
  skip_if_not_installed("gradethis")

  db_path <- withr::local_tempfile(fileext = ".sqlite")
  tracking <- setup_learnr_tracking(
    tutorial_id = "minimal_learnr",
    student_id = "student_001",
    db_path = db_path
  )

  grade <- track_gradethis_attempt(
    context = tracking,
    question_id = "q2_mean",
    submitted_answer = "mean(c(2, 4, 6))",
    correct = TRUE,
    feedback = "Correct.",
    max_score = 1
  )

  con <- open_learnr_tracking_db(tracking)
  withr::defer(DBI::dbDisconnect(con))
  attempts <- get_attempts(con)

  expect_s3_class(grade, "gradethis_graded")
  expect_true(grade$correct)
  expect_equal(nrow(attempts), 1)
  expect_equal(attempts$student_id, "student_001")
  expect_equal(attempts$tutorial_id, "minimal_learnr")
  expect_equal(attempts$score, 1)
})

test_that("tracked_question_radio records radio submissions", {
  skip_if_not_installed("learnr")

  db_path <- withr::local_tempfile(fileext = ".sqlite")

  question <- tracked_question_radio(
    "What is 2 + 2?",
    learnr::answer("3"),
    learnr::answer("4", correct = TRUE, message = "Correct."),
    question_id = "q1_radio",
    tutorial_id = "minimal_learnr",
    student_id = "student_001",
    db_path = db_path,
    max_score = 1
  )

  result <- learnr::question_is_correct(question, "4")

  con <- connect_tracking_db(db_path)
  withr::defer(DBI::dbDisconnect(con))
  attempts <- get_attempts(con)

  expect_true(result$correct)
  expect_equal(nrow(attempts), 1)
  expect_equal(attempts$question_id, "q1_radio")
  expect_equal(attempts$submitted_answer, "4")
  expect_equal(attempts$grade_status, "correct")
  expect_equal(attempts$score, 1)
})

test_that("tracked_question can use a learnr tracking context", {
  skip_if_not_installed("learnr")

  db_path <- withr::local_tempfile(fileext = ".sqlite")
  tracking <- setup_learnr_tracking(
    tutorial_id = "minimal_learnr",
    student_id = "student_001",
    db_path = db_path
  )

  question <- tracked_question(
    "What is 2 + 2?",
    learnr::answer("3"),
    learnr::answer("4", correct = TRUE, message = "Correct."),
    type = "radio",
    question_id = "q1_context",
    context = tracking,
    max_score = 1
  )

  result <- learnr::question_is_correct(question, "4")

  con <- open_learnr_tracking_db(tracking)
  withr::defer(DBI::dbDisconnect(con))
  attempts <- get_attempts(con)

  expect_true(result$correct)
  expect_equal(nrow(attempts), 1)
  expect_equal(attempts$question_id, "q1_context")
  expect_equal(attempts$student_id, "student_001")
  expect_equal(attempts$tutorial_id, "minimal_learnr")
  expect_equal(attempts$score, 1)
})

test_that("tracked_question_radio records incorrect radio submissions", {
  skip_if_not_installed("learnr")

  db_path <- withr::local_tempfile(fileext = ".sqlite")

  question <- tracked_question_radio(
    "What is 2 + 2?",
    learnr::answer("3", message = "Too low."),
    learnr::answer("4", correct = TRUE),
    question_id = "q1_radio",
    tutorial_id = "minimal_learnr",
    student_id = "student_001",
    db_path = db_path,
    max_score = 1
  )

  result <- learnr::question_is_correct(question, "3")

  con <- connect_tracking_db(db_path)
  withr::defer(DBI::dbDisconnect(con))
  attempts <- get_attempts(con)

  expect_false(result$correct)
  expect_equal(nrow(attempts), 1)
  expect_equal(attempts$submitted_answer, "3")
  expect_equal(attempts$grade_status, "incorrect")
  expect_equal(attempts$score, 0)
})

test_that("tracked_question_checkbox records multiple selections", {
  skip_if_not_installed("learnr")

  db_path <- withr::local_tempfile(fileext = ".sqlite")

  question <- tracked_question_checkbox(
    "Select all even numbers.",
    learnr::answer("2", correct = TRUE),
    learnr::answer("3"),
    learnr::answer("4", correct = TRUE),
    question_id = "q2_checkbox",
    tutorial_id = "minimal_learnr",
    student_id = "student_001",
    db_path = db_path,
    max_score = 2
  )

  result <- learnr::question_is_correct(question, c("2", "4"))

  con <- connect_tracking_db(db_path)
  withr::defer(DBI::dbDisconnect(con))
  attempts <- get_attempts(con)

  expect_true(result$correct)
  expect_equal(nrow(attempts), 1)
  expect_equal(attempts$question_id, "q2_checkbox")
  expect_equal(attempts$submitted_answer, "2\n4")
  expect_equal(attempts$score, 2)
  expect_equal(attempts$max_score, 2)
})

test_that("tracked_question_text records text submissions", {
  skip_if_not_installed("learnr")

  db_path <- withr::local_tempfile(fileext = ".sqlite")

  question <- tracked_question_text(
    "Type the word mean.",
    learnr::answer("mean", correct = TRUE, message = "Correct."),
    question_id = "q3_text",
    tutorial_id = "minimal_learnr",
    student_id = "student_001",
    db_path = db_path,
    max_score = 1
  )

  result <- learnr::question_is_correct(question, "mean")

  con <- connect_tracking_db(db_path)
  withr::defer(DBI::dbDisconnect(con))
  attempts <- get_attempts(con)

  expect_true(result$correct)
  expect_equal(nrow(attempts), 1)
  expect_equal(attempts$question_id, "q3_text")
  expect_equal(attempts$submitted_answer, "mean")
  expect_equal(attempts$grade_status, "correct")
  expect_equal(attempts$score, 1)
})

test_that("tracked_question_text records answer_fn submissions", {
  skip_if_not_installed("learnr")

  db_path <- withr::local_tempfile(fileext = ".sqlite")

  question <- tracked_question_text(
    "Which station is colder on average?",
    learnr::answer_fn(
      function(value) {
        if (tolower(trimws(value)) %in% c("quebec", "québec")) {
          learnr::correct("Correct.")
        } else {
          learnr::incorrect("Try again.")
        }
      },
      label = "station checker"
    ),
    question_id = "q4_text_fn",
    tutorial_id = "minimal_learnr",
    student_id = "student_001",
    db_path = db_path,
    max_score = 1
  )

  result <- learnr::question_is_correct(question, "Québec")

  con <- connect_tracking_db(db_path)
  withr::defer(DBI::dbDisconnect(con))
  attempts <- get_attempts(con)

  expect_true(result$correct)
  expect_equal(nrow(attempts), 1)
  expect_equal(attempts$submitted_answer, "Québec")
  expect_equal(attempts$score, 1)
})

test_that("tracked_question_numeric records numeric submissions", {
  skip_if_not_installed("learnr")

  db_path <- withr::local_tempfile(fileext = ".sqlite")

  question <- tracked_question_numeric(
    "How many rows are in the data set?",
    learnr::answer(6, correct = TRUE, message = "Correct."),
    question_id = "q5_numeric",
    tutorial_id = "minimal_learnr",
    student_id = "student_001",
    db_path = db_path,
    max_score = 1,
    min = 0,
    max = 20,
    step = 1
  )

  result <- learnr::question_is_correct(question, 6)

  con <- connect_tracking_db(db_path)
  withr::defer(DBI::dbDisconnect(con))
  attempts <- get_attempts(con)

  expect_true(result$correct)
  expect_equal(nrow(attempts), 1)
  expect_equal(attempts$question_id, "q5_numeric")
  expect_equal(attempts$submitted_answer, "6")
  expect_equal(attempts$grade_status, "correct")
  expect_equal(attempts$score, 1)
})

test_that("tracked_question dispatches to radio questions", {
  skip_if_not_installed("learnr")

  db_path <- withr::local_tempfile(fileext = ".sqlite")

  question <- tracked_question(
    "What is 2 + 2?",
    learnr::answer("3"),
    learnr::answer("4", correct = TRUE),
    type = "radio",
    question_id = "q6_generic_radio",
    tutorial_id = "minimal_learnr",
    student_id = "student_001",
    db_path = db_path,
    max_score = 1
  )

  result <- learnr::question_is_correct(question, "4")

  con <- connect_tracking_db(db_path)
  withr::defer(DBI::dbDisconnect(con))
  attempts <- get_attempts(con)

  expect_true(inherits(question, "learnrTrackR_tracked_radio"))
  expect_true(result$correct)
  expect_equal(attempts$question_id, "q6_generic_radio")
  expect_equal(attempts$score, 1)
})

test_that("tracked_question auto dispatches to checkbox questions", {
  skip_if_not_installed("learnr")

  db_path <- withr::local_tempfile(fileext = ".sqlite")

  question <- tracked_question(
    "Select all even numbers.",
    learnr::answer("2", correct = TRUE),
    learnr::answer("3"),
    learnr::answer("4", correct = TRUE),
    question_id = "q7_generic_checkbox",
    tutorial_id = "minimal_learnr",
    student_id = "student_001",
    db_path = db_path,
    max_score = 2
  )

  result <- learnr::question_is_correct(question, c("2", "4"))

  con <- connect_tracking_db(db_path)
  withr::defer(DBI::dbDisconnect(con))
  attempts <- get_attempts(con)

  expect_true(inherits(question, "learnrTrackR_tracked_checkbox"))
  expect_true(result$correct)
  expect_equal(attempts$question_id, "q7_generic_checkbox")
  expect_equal(attempts$submitted_answer, "2\n4")
  expect_equal(attempts$score, 2)
})

test_that("tracked_question dispatches to text and numeric questions", {
  skip_if_not_installed("learnr")

  text_db_path <- withr::local_tempfile(fileext = ".sqlite")
  numeric_db_path <- withr::local_tempfile(fileext = ".sqlite")

  text_question <- tracked_question(
    "Type the word mean.",
    learnr::answer("mean", correct = TRUE),
    type = "text",
    question_id = "q8_generic_text",
    tutorial_id = "minimal_learnr",
    student_id = "student_001",
    db_path = text_db_path,
    max_score = 1
  )

  numeric_question <- tracked_question(
    "What is 2 + 2?",
    learnr::answer(4, correct = TRUE),
    type = "numeric",
    question_id = "q9_generic_numeric",
    tutorial_id = "minimal_learnr",
    student_id = "student_001",
    db_path = numeric_db_path,
    max_score = 1
  )

  text_result <- learnr::question_is_correct(text_question, "mean")
  numeric_result <- learnr::question_is_correct(numeric_question, 4)

  text_con <- connect_tracking_db(text_db_path)
  numeric_con <- connect_tracking_db(numeric_db_path)
  withr::defer(DBI::dbDisconnect(text_con))
  withr::defer(DBI::dbDisconnect(numeric_con))

  text_attempts <- get_attempts(text_con)
  numeric_attempts <- get_attempts(numeric_con)

  expect_true(inherits(text_question, "learnrTrackR_tracked_text"))
  expect_true(inherits(numeric_question, "learnrTrackR_tracked_numeric"))
  expect_true(text_result$correct)
  expect_true(numeric_result$correct)
  expect_equal(text_attempts$submitted_answer, "mean")
  expect_equal(numeric_attempts$submitted_answer, "4")
})
