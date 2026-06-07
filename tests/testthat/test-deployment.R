test_that("PostgreSQL Docker example files are installed", {
  example_dir <- system.file(
    "examples/postgres-docker",
    package = "learnrTrackR",
    mustWork = TRUE
  )

  compose_path <- file.path(example_dir, "compose.yml")
  env_path <- file.path(example_dir, "env.example")
  smoke_path <- file.path(example_dir, "smoke-test.R")
  pilot_smoke_path <- file.path(example_dir, "course-pilot-smoke-test.R")

  expect_true(file.exists(compose_path))
  expect_true(file.exists(env_path))
  expect_true(file.exists(smoke_path))
  expect_true(file.exists(pilot_smoke_path))

  compose <- readLines(compose_path, warn = FALSE)
  env <- readLines(env_path, warn = FALSE)

  expect_true(any(grepl("image: postgres:", compose, fixed = TRUE)))
  expect_false(any(grepl("POSTGRES_HOST_AUTH_METHOD", compose, fixed = TRUE)))
  expect_true(any(grepl("LEARNRTRACKR_POSTGRES_PASSWORD=", env, fixed = TRUE)))
  expect_true(any(grepl("LEARNRTRACKR_POSTGRES_SCHEMA=", env, fixed = TRUE)))
  expect_true(any(grepl("LEARNRTRACKR_PILOT_GROUP_ID=", env, fixed = TRUE)))
  expect_true(any(grepl("LEARNRTRACKR_PILOT_OUTPUT_DIR=", env, fixed = TRUE)))
})

test_that("controlled PostgreSQL pilot works when a test DSN is configured", {
  skip_if_not_installed("RPostgres")

  dsn <- Sys.getenv("LEARNRTRACKR_TEST_POSTGRES_DSN", unset = "")
  skip_if(
    !nzchar(dsn),
    "Set LEARNRTRACKR_TEST_POSTGRES_DSN to run PostgreSQL pilot integration tests."
  )

  example_dir <- system.file(
    "examples/course-pilot",
    package = "learnrTrackR",
    mustWork = TRUE
  )
  source(file.path(example_dir, "pilot-workflow.R"), local = TRUE)

  schema_name <- paste0(
    "learnrtrackr_pilot_test_",
    gsub("[^A-Za-z0-9]", "", basename(tempfile()))
  )
  output_dir <- withr::local_tempdir()

  con <- DBI::dbConnect(RPostgres::Postgres(), dbname = dsn)
  withr::defer(DBI::dbDisconnect(con))
  withr::defer(
    DBI::dbExecute(
      con,
      paste(
        "DROP SCHEMA IF EXISTS",
        DBI::dbQuoteIdentifier(con, schema_name),
        "CASCADE"
      )
    )
  )

  DBI::dbExecute(
    con,
    paste("CREATE SCHEMA", DBI::dbQuoteIdentifier(con, schema_name))
  )
  DBI::dbExecute(
    con,
    paste("SET search_path TO", DBI::dbQuoteIdentifier(con, schema_name))
  )

  create_schema(con)
  course_pilot_load_config(con, example_dir)
  course_pilot_record_simulated_attempts(con)
  outputs <- course_pilot_teacher_outputs(
    con,
    output_dir = output_dir,
    group_id = "A",
    render_report = FALSE
  )

  moodle <- readr::read_csv(outputs$paths$moodle, show_col_types = FALSE)

  expect_equal(nrow(get_attempts(con, tutorial_id = course_pilot_tutorial_id())), 18)
  expect_equal(nrow(outputs$gradebook), 4)
  expect_setequal(moodle$useridnumber, c("student_demo", "student_a01", "student_a02"))
  expect_false("student_b01" %in% moodle$useridnumber)
  expect_true(file.exists(outputs$paths$moodle))
  expect_true(dir.exists(outputs$paths$bundle))
})
