load_learnrtrackr <- function() {
  if (requireNamespace("learnrTrackR", quietly = TRUE)) {
    return(invisible(TRUE))
  }

  repo_root <- normalizePath(
    file.path(getwd(), "..", "..", ".."),
    mustWork = FALSE
  )

  if (
    file.exists(file.path(repo_root, "DESCRIPTION")) &&
      requireNamespace("devtools", quietly = TRUE)
  ) {
    devtools::load_all(repo_root, quiet = TRUE)
    return(invisible(TRUE))
  }

  stop(
    "Install learnrTrackR or run this script from the package source example directory.",
    call. = FALSE
  )
}

read_local_env <- function(path = ".env") {
  if (file.exists(path)) {
    readRenviron(path)
  }

  invisible(TRUE)
}

env_value <- function(name, default = "") {
  Sys.getenv(name, unset = default)
}

load_learnrtrackr()
read_local_env()

password <- env_value("LEARNRTRACKR_POSTGRES_PASSWORD")

if (
  !nzchar(password) ||
    identical(password, "replace-with-a-long-random-password")
) {
  stop(
    "Set LEARNRTRACKR_POSTGRES_PASSWORD in .env before running this smoke test.",
    call. = FALSE
  )
}

con <- learnrTrackR::connect_postgres_tracking_db(
  dbname = env_value("LEARNRTRACKR_POSTGRES_DB", "learnrtrackr"),
  host = env_value("LEARNRTRACKR_POSTGRES_HOST", "127.0.0.1"),
  port = as.integer(env_value("LEARNRTRACKR_POSTGRES_PORT", "5432")),
  user = env_value("LEARNRTRACKR_POSTGRES_USER", "learnrtrackr"),
  password = password,
  initialize = TRUE
)
on.exit(DBI::dbDisconnect(con), add = TRUE)

run_id <- format(Sys.time(), "%Y%m%d%H%M%S")
course_id <- paste0("smoke_course_", run_id)
tutorial_id <- paste0("smoke_tutorial_", run_id)
student_id <- paste0("smoke_student_", run_id)

learnrTrackR::register_courses(
  con,
  data.frame(
    course_id = course_id,
    course_label = "Smoke test course",
    semester = "test"
  )
)

learnrTrackR::register_tutorials(
  con,
  data.frame(
    tutorial_id = tutorial_id,
    course_id = course_id,
    tutorial_label = "Smoke test tutorial"
  )
)

learnrTrackR::register_students(
  con,
  data.frame(
    student_id = student_id,
    student_label = "Smoke test student",
    group_id = "test"
  )
)

learnrTrackR::register_questions(
  con,
  tutorial_id = tutorial_id,
  questions = data.frame(
    question_id = c("q1", "q2"),
    question_label = c("Question 1", "Question 2"),
    max_score = c(1, 1)
  )
)

learnrTrackR::track_attempt(
  con,
  student_id = student_id,
  tutorial_id = tutorial_id,
  question_id = "q1",
  submitted_answer = "mean(x)",
  grade_status = "correct",
  score = 1,
  max_score = 1,
  feedback = "Smoke test attempt.",
  require_registered_student = TRUE
)

print(learnrTrackR::gradebook(con, tutorial_id = tutorial_id))
