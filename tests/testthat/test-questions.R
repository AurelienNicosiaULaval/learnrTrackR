test_that("register_questions stores expected tutorial questions", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  registered <- register_questions(
    con,
    tutorial_id = "module_01",
    questions = data.frame(
      question_id = c("q1", "q2"),
      question_label = c("Question 1", "Question 2"),
      question_type = c("radio", "code"),
      max_score = c(1, 2)
    )
  )

  questions <- get_questions(con, tutorial_id = "module_01")

  expect_s3_class(registered, "tbl_df")
  expect_equal(nrow(questions), 2)
  expect_equal(questions$question_id, c("q1", "q2"))
  expect_equal(questions$max_score, c(1, 2))
})

test_that("register_questions is idempotent and can overwrite", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_questions(con, "module_01", c("q1", "q2"))
  register_questions(con, "module_01", c("q1", "q2"))

  expect_equal(nrow(get_questions(con, "module_01")), 2)

  register_questions(con, "module_01", c("q3"), overwrite = TRUE)

  questions <- get_questions(con, "module_01")
  expect_equal(nrow(questions), 1)
  expect_equal(questions$question_id, "q3")
})

test_that("register_questions validates duplicated question ids", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  expect_error(
    register_questions(con, "module_01", c("q1", "q1")),
    "duplicated"
  )
})
