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

dashboard_token <- function() {
  token <- env_value("LEARNRTRACKR_DASHBOARD_TOKEN")

  if (
    !nzchar(token) ||
      identical(token, "replace-with-a-long-random-dashboard-token")
  ) {
    return(NULL)
  }

  token
}

load_learnrtrackr()
read_local_env()

password <- env_value("LEARNRTRACKR_POSTGRES_PASSWORD")

if (
  !nzchar(password) ||
    identical(password, "replace-with-a-long-random-password")
) {
  stop(
    "Set LEARNRTRACKR_POSTGRES_PASSWORD in .env before running the dashboard.",
    call. = FALSE
  )
}

learnrTrackR::run_dashboard_postgres(
  dbname = env_value("LEARNRTRACKR_POSTGRES_DB", "learnrtrackr"),
  postgres_host = env_value("LEARNRTRACKR_POSTGRES_HOST", "127.0.0.1"),
  postgres_port = as.integer(env_value("LEARNRTRACKR_POSTGRES_PORT", "5432")),
  postgres_user = env_value("LEARNRTRACKR_POSTGRES_USER", "learnrtrackr"),
  postgres_password = password,
  postgres_schema = env_value("LEARNRTRACKR_POSTGRES_SCHEMA"),
  tutorial_id = env_value(
    "LEARNRTRACKR_PILOT_TUTORIAL_ID",
    "stat_descriptive_pilot"
  ),
  group_id = env_value("LEARNRTRACKR_PILOT_GROUP_ID", "A"),
  host = env_value("LEARNRTRACKR_DASHBOARD_HOST", "127.0.0.1"),
  access_token = dashboard_token(),
  token_envvar = NULL,
  allow_remote = FALSE
)
