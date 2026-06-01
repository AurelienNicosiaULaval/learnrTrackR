test_that("get_tracking_student_id reads the default environment variable", {
  withr::local_envvar(LEARNRTRACKR_STUDENT_ID = "student_001")

  expect_equal(get_tracking_student_id(), "student_001")
})

test_that("get_tracking_student_id trims environment values", {
  withr::local_envvar(LEARNRTRACKR_STUDENT_ID = "  student_001  ")

  expect_equal(get_tracking_student_id(), "student_001")
})

test_that("get_tracking_student_id uses a default when the environment variable is missing", {
  withr::local_envvar(LEARNRTRACKR_STUDENT_ID = NA)

  expect_equal(get_tracking_student_id(default = "student_demo"), "student_demo")
})

test_that("get_tracking_student_id can return NA when not required", {
  withr::local_envvar(LEARNRTRACKR_STUDENT_ID = NA)

  expect_true(is.na(get_tracking_student_id(required = FALSE)))
})

test_that("get_tracking_student_id errors clearly when required and missing", {
  withr::local_envvar(LEARNRTRACKR_STUDENT_ID = NA)

  expect_error(
    get_tracking_student_id(),
    "Student identifier is missing"
  )
})
