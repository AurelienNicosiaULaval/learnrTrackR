sqlite_schema_statements <- function() {
  c(
    "CREATE TABLE IF NOT EXISTS students (
      student_id TEXT PRIMARY KEY,
      student_label TEXT,
      email TEXT,
      group_id TEXT,
      created_at TEXT
    )",
    "CREATE TABLE IF NOT EXISTS courses (
      course_id TEXT PRIMARY KEY,
      course_label TEXT,
      semester TEXT,
      created_at TEXT
    )",
    "CREATE TABLE IF NOT EXISTS tutorials (
      tutorial_id TEXT PRIMARY KEY,
      course_id TEXT,
      tutorial_label TEXT,
      version TEXT,
      created_at TEXT
    )",
    "CREATE TABLE IF NOT EXISTS questions (
      question_id TEXT,
      tutorial_id TEXT,
      question_label TEXT,
      question_type TEXT,
      max_score REAL,
      created_at TEXT,
      PRIMARY KEY(question_id, tutorial_id)
    )",
    "CREATE TABLE IF NOT EXISTS sessions (
      session_id TEXT PRIMARY KEY,
      student_id TEXT,
      tutorial_id TEXT,
      started_at TEXT,
      last_seen_at TEXT,
      completed_at TEXT
    )",
    "CREATE TABLE IF NOT EXISTS attempts (
      attempt_id INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id TEXT,
      student_id TEXT NOT NULL,
      tutorial_id TEXT NOT NULL,
      question_id TEXT NOT NULL,
      attempt_number INTEGER NOT NULL,
      submitted_answer TEXT,
      grade_status TEXT,
      score REAL,
      max_score REAL,
      feedback TEXT,
      timestamp TEXT
    )"
  )
}

postgres_schema_statements <- function() {
  c(
    "CREATE TABLE IF NOT EXISTS students (
      student_id TEXT PRIMARY KEY,
      student_label TEXT,
      email TEXT,
      group_id TEXT,
      created_at TEXT
    )",
    "CREATE TABLE IF NOT EXISTS courses (
      course_id TEXT PRIMARY KEY,
      course_label TEXT,
      semester TEXT,
      created_at TEXT
    )",
    "CREATE TABLE IF NOT EXISTS tutorials (
      tutorial_id TEXT PRIMARY KEY,
      course_id TEXT,
      tutorial_label TEXT,
      version TEXT,
      created_at TEXT
    )",
    "CREATE TABLE IF NOT EXISTS questions (
      question_id TEXT,
      tutorial_id TEXT,
      question_label TEXT,
      question_type TEXT,
      max_score DOUBLE PRECISION,
      created_at TEXT,
      PRIMARY KEY(question_id, tutorial_id)
    )",
    "CREATE TABLE IF NOT EXISTS sessions (
      session_id TEXT PRIMARY KEY,
      student_id TEXT,
      tutorial_id TEXT,
      started_at TEXT,
      last_seen_at TEXT,
      completed_at TEXT
    )",
    "CREATE TABLE IF NOT EXISTS attempts (
      attempt_id BIGSERIAL PRIMARY KEY,
      session_id TEXT,
      student_id TEXT NOT NULL,
      tutorial_id TEXT NOT NULL,
      question_id TEXT NOT NULL,
      attempt_number INTEGER NOT NULL,
      submitted_answer TEXT,
      grade_status TEXT,
      score DOUBLE PRECISION,
      max_score DOUBLE PRECISION,
      feedback TEXT,
      timestamp TEXT
    )"
  )
}

schema_statements <- function(con) {
  backend <- tracking_db_backend(con)

  switch(
    backend,
    sqlite = sqlite_schema_statements(),
    postgres = postgres_schema_statements()
  )
}

#' Create the tracking database schema
#'
#' Creates the SQLite or PostgreSQL tables required by the tracking layer. The
#' function is idempotent: calling it several times on the same connection keeps
#' existing data and only creates missing tables.
#'
#' @param con A DBI connection.
#'
#' @return The input connection, invisibly.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' create_schema(con)
#' DBI::dbDisconnect(con)
create_schema <- function(con) {
  check_connection(con)

  statements <- schema_statements(con)

  DBI::dbWithTransaction(con, {
    for (statement in statements) {
      DBI::dbExecute(con, statement)
    }
  })

  invisible(con)
}
