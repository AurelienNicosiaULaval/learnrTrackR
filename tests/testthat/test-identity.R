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

test_that("get_learnr_tracking_env reads launch environment variables", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  withr::local_envvar(
    LEARNRTRACKR_STUDENT_ID = " student_001 ",
    LEARNRTRACKR_DB = paste0(" ", db_path, " "),
    LEARNRTRACKR_GROUP_ID = " A "
  )

  env <- get_learnr_tracking_env()

  expect_s3_class(env, "learnrTrackR_env")
  expect_equal(env$student_id, "student_001")
  expect_equal(env$db_path, db_path)
  expect_equal(env$group_id, "A")
})

test_that("get_learnr_tracking_env supports default database and group values", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  withr::local_envvar(
    LEARNRTRACKR_STUDENT_ID = "student_001",
    LEARNRTRACKR_DB = NA,
    LEARNRTRACKR_GROUP_ID = NA
  )

  env <- get_learnr_tracking_env(
    default_db_path = db_path,
    default_group_id = "demo_group"
  )

  expect_equal(env$db_path, db_path)
  expect_equal(env$group_id, "demo_group")
})

test_that("get_learnr_tracking_env can return NA for optional group", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  withr::local_envvar(
    LEARNRTRACKR_STUDENT_ID = "student_001",
    LEARNRTRACKR_DB = db_path,
    LEARNRTRACKR_GROUP_ID = NA
  )

  env <- get_learnr_tracking_env()

  expect_true(is.na(env$group_id))
})

test_that("get_learnr_tracking_env errors when required database path is missing", {
  withr::local_envvar(
    LEARNRTRACKR_STUDENT_ID = "student_001",
    LEARNRTRACKR_DB = NA
  )

  expect_error(
    get_learnr_tracking_env(),
    "Tracking database path is missing"
  )
})

test_that("get_learnr_tracking_env errors when required group is missing", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  withr::local_envvar(
    LEARNRTRACKR_STUDENT_ID = "student_001",
    LEARNRTRACKR_DB = db_path,
    LEARNRTRACKR_GROUP_ID = NA
  )

  expect_error(
    get_learnr_tracking_env(require_group_id = TRUE),
    "Tracking group identifier is missing"
  )
})
