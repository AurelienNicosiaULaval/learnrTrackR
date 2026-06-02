available_dashboard_tutorials <- function(con) {
  check_required_tables(con)

  tutorials <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT tutorial_id FROM questions",
      "UNION",
      "SELECT tutorial_id FROM attempts",
      "ORDER BY tutorial_id ASC"
    )
  )

  tibble::as_tibble(tutorials)
}

resolve_dashboard_tutorial_id <- function(con, tutorial_id = NULL) {
  tutorial_id <- validate_scalar_character(
    tutorial_id,
    arg = "tutorial_id",
    allow_null = TRUE
  )

  if (!is.null(tutorial_id)) {
    return(tutorial_id)
  }

  tutorials <- available_dashboard_tutorials(con)

  if (nrow(tutorials) == 0) {
    return(NULL)
  }

  tutorials$tutorial_id[[1]]
}

empty_dashboard_summary <- function() {
  tibble::tibble(
    metric = c(
      "Tutorial",
      "Students",
      "Attempts",
      "Questions",
      "Completed",
      "Completion rate (%)",
      "Mean percent",
      "Median percent"
    ),
    value = c("No tutorial available", "0", "0", "0", "0", NA_character_, NA_character_, NA_character_)
  )
}

format_dashboard_number <- function(x, digits = 1) {
  if (is.na(x)) {
    return(NA_character_)
  }

  format(round(x, digits), trim = TRUE, nsmall = digits)
}

summarise_dashboard <- function(tutorial_id, attempts, grades, questions) {
  if (is.null(tutorial_id)) {
    return(empty_dashboard_summary())
  }

  n_students <- if (nrow(grades) > 0) {
    nrow(grades)
  } else {
    length(unique(attempts$student_id))
  }

  n_completed <- if (nrow(grades) > 0) {
    sum(grades$completed, na.rm = TRUE)
  } else {
    0L
  }

  completion_rate <- if (n_students > 0) {
    100 * n_completed / n_students
  } else {
    NA_real_
  }

  mean_percent <- if (nrow(grades) > 0) {
    mean(grades$percent, na.rm = TRUE)
  } else {
    NA_real_
  }

  median_percent <- if (nrow(grades) > 0) {
    stats::median(grades$percent, na.rm = TRUE)
  } else {
    NA_real_
  }

  if (is.nan(mean_percent)) {
    mean_percent <- NA_real_
  }

  if (is.nan(median_percent)) {
    median_percent <- NA_real_
  }

  tibble::tibble(
    metric = c(
      "Tutorial",
      "Students",
      "Attempts",
      "Questions",
      "Completed",
      "Completion rate (%)",
      "Mean percent",
      "Median percent"
    ),
    value = c(
      tutorial_id,
      as.character(n_students),
      as.character(nrow(attempts)),
      as.character(nrow(questions)),
      as.character(n_completed),
      format_dashboard_number(completion_rate),
      format_dashboard_number(mean_percent),
      format_dashboard_number(median_percent)
    )
  )
}

empty_dashboard_questions <- function() {
  tibble::tibble(
    question_id = character(),
    question_label = character(),
    question_type = character(),
    max_score = numeric(),
    n_attempts = integer(),
    n_students = integer(),
    n_answered = integer(),
    mean_score = numeric(),
    mean_percent = numeric()
  )
}

summarise_dashboard_questions <- function(con,
                                          tutorial_id,
                                          rule,
                                          include_unregistered) {
  if (is.null(tutorial_id)) {
    return(empty_dashboard_questions())
  }

  attempts <- get_attempts(con, tutorial_id = tutorial_id)
  selected <- if (nrow(attempts) == 0) {
    attempts
  } else {
    select_attempts_for_score(attempts, rule = rule)
  }
  registered <- get_questions(con, tutorial_id = tutorial_id)
  questions <- merge_question_metadata(
    registered = registered,
    selected = selected,
    tutorial_id = tutorial_id,
    include_unregistered = include_unregistered
  )

  if (nrow(questions) == 0) {
    return(empty_dashboard_questions())
  }

  rows <- lapply(seq_len(nrow(questions)), function(index) {
    question <- questions[index, , drop = FALSE]
    question_attempts <- attempts[attempts$question_id == question$question_id[[1]], , drop = FALSE]
    question_selected <- selected[selected$question_id == question$question_id[[1]], , drop = FALSE]
    answers <- question_selected$submitted_answer
    answered <- !is.na(answers) & nzchar(answers)
    max_score <- question$max_score[[1]]
    mean_score <- if (nrow(question_selected) > 0) {
      mean(question_selected$score, na.rm = TRUE)
    } else {
      NA_real_
    }

    if (is.nan(mean_score)) {
      mean_score <- NA_real_
    }

    tibble::tibble(
      question_id = question$question_id[[1]],
      question_label = question$question_label[[1]],
      question_type = question$question_type[[1]],
      max_score = max_score,
      n_attempts = nrow(question_attempts),
      n_students = length(unique(question_attempts$student_id)),
      n_answered = sum(answered),
      mean_score = mean_score,
      mean_percent = if (!is.na(max_score) && max_score > 0 && !is.na(mean_score)) {
        100 * mean_score / max_score
      } else {
        NA_real_
      }
    )
  })

  dplyr::bind_rows(rows)
}

#' Prepare dashboard data
#'
#' Computes the tables used by the teacher dashboard without launching Shiny.
#' This function is useful for testing, reporting, and non-interactive
#' summaries.
#'
#' @param con A DBI connection.
#' @param tutorial_id Optional tutorial identifier. If `NULL`, the first
#'   available tutorial found in the database is used.
#' @param rule Scoring rule passed to [gradebook()].
#' @param include_unregistered If `TRUE`, include attempted questions that were
#'   not registered with [register_questions()].
#'
#' @return A list with tutorials, selected tutorial id, summary, gradebook,
#'   question summary, and attempts.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_questions(con, "module_01", c("q1", "q2"))
#' track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
#' dashboard_data(con, tutorial_id = "module_01")
#' DBI::dbDisconnect(con)
dashboard_data <- function(con,
                           tutorial_id = NULL,
                           rule = c("last", "best", "first"),
                           include_unregistered = TRUE) {
  check_required_tables(con)

  rule <- match.arg(rule)
  include_unregistered <- validate_scalar_logical(
    include_unregistered,
    arg = "include_unregistered"
  )
  tutorials <- available_dashboard_tutorials(con)
  tutorial_id <- resolve_dashboard_tutorial_id(con, tutorial_id = tutorial_id)

  if (is.null(tutorial_id)) {
    attempts <- get_attempts(con)
    grades <- empty_gradebook_tibble()
    questions <- empty_dashboard_questions()
  } else {
    attempts <- get_attempts(con, tutorial_id = tutorial_id)
    grades <- gradebook(
      con,
      tutorial_id = tutorial_id,
      rule = rule,
      include_unregistered = include_unregistered
    )
    questions <- summarise_dashboard_questions(
      con = con,
      tutorial_id = tutorial_id,
      rule = rule,
      include_unregistered = include_unregistered
    )
  }

  list(
    tutorials = tutorials,
    tutorial_id = tutorial_id,
    summary = summarise_dashboard(tutorial_id, attempts, grades, questions),
    gradebook = grades,
    questions = questions,
    attempts = attempts
  )
}

dashboard_data_from_path <- function(db_path,
                                     tutorial_id = NULL,
                                     rule = "last",
                                     include_unregistered = TRUE) {
  con <- connect_tracking_db(db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  dashboard_data(
    con = con,
    tutorial_id = tutorial_id,
    rule = rule,
    include_unregistered = include_unregistered
  )
}

resolve_dashboard_access_token <- function(access_token = NULL,
                                           token_envvar = "LEARNRTRACKR_DASHBOARD_TOKEN") {
  access_token <- validate_scalar_character(
    access_token,
    arg = "access_token",
    allow_null = TRUE
  )
  token_envvar <- validate_scalar_character(
    token_envvar,
    arg = "token_envvar",
    allow_null = TRUE
  )

  if (!is.null(access_token)) {
    return(access_token)
  }

  if (is.null(token_envvar)) {
    return(NULL)
  }

  env_token <- Sys.getenv(token_envvar, unset = "")

  if (!nzchar(env_token)) {
    return(NULL)
  }

  env_token
}

validate_dashboard_host <- function(host) {
  validate_scalar_character(host, arg = "host")
}

is_local_dashboard_host <- function(host) {
  host %in% c("127.0.0.1", "localhost", "::1")
}

check_dashboard_launch_security <- function(host,
                                            access_token,
                                            allow_remote) {
  host <- validate_dashboard_host(host)
  allow_remote <- validate_scalar_logical(allow_remote, arg = "allow_remote")

  if (
    !is_local_dashboard_host(host) &&
      is.null(access_token) &&
      !allow_remote
  ) {
    cli::cli_abort(c(
      "Refusing to run the dashboard on a non-local host without an access token.",
      "i" = "Use {.code host = \"127.0.0.1\"} for local use.",
      "i" = "Set {.arg access_token} or {.envvar LEARNRTRACKR_DASHBOARD_TOKEN} before allowing remote access.",
      "i" = "Set {.code allow_remote = TRUE} only for an explicitly managed environment."
    ))
  }

  invisible(TRUE)
}

dashboard_main_ui <- function(choices,
                              selected,
                              rule,
                              include_unregistered) {
  shiny::sidebarLayout(
    shiny::sidebarPanel(
      shiny::selectInput(
        "tutorial_id",
        "Tutorial",
        choices = choices,
        selected = selected
      ),
      shiny::selectInput(
        "rule",
        "Scoring rule",
        choices = c("last", "best", "first"),
        selected = rule
      ),
      shiny::checkboxInput(
        "include_unregistered",
        "Include unregistered attempted questions",
        value = include_unregistered
      ),
      shiny::actionButton("refresh", "Refresh"),
      shiny::hr(),
      shiny::downloadButton("download_gradebook", "Download gradebook"),
      shiny::downloadButton("download_moodle", "Download Moodle CSV")
    ),
    shiny::mainPanel(
      shiny::h3("Summary"),
      shiny::tableOutput("summary"),
      shiny::h3("Gradebook"),
      shiny::tableOutput("gradebook"),
      shiny::h3("Questions"),
      shiny::tableOutput("questions"),
      shiny::h3("Attempts"),
      shiny::tableOutput("attempts")
    )
  )
}

dashboard_app <- function(db_path,
                          tutorial_id = NULL,
                          rule = "last",
                          include_unregistered = TRUE,
                          access_token = NULL) {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg shiny} is required to use {.fn run_dashboard}."
    )
  }

  initial_data <- dashboard_data_from_path(
    db_path = db_path,
    tutorial_id = tutorial_id,
    rule = rule,
    include_unregistered = include_unregistered
  )
  choices <- initial_data$tutorials$tutorial_id
  selected <- tutorial_id

  if (is.null(selected) && length(choices) > 0) {
    selected <- choices[[1]]
  }

  dashboard_ui <- dashboard_main_ui(
    choices = choices,
    selected = selected,
    rule = rule,
    include_unregistered = include_unregistered
  )

  ui <- shiny::fluidPage(
    shiny::titlePanel("learnrTrackR teacher dashboard"),
    if (is.null(access_token)) {
      dashboard_ui
    } else {
      shiny::uiOutput("dashboard_access")
    }
  )

  server <- function(input, output, session) {
    authorized <- shiny::reactiveVal(is.null(access_token))
    auth_message <- shiny::reactiveVal(NULL)

    output$dashboard_access <- shiny::renderUI({
      if (isTRUE(authorized())) {
        return(dashboard_ui)
      }

      shiny::tagList(
        shiny::passwordInput("dashboard_token", "Dashboard token"),
        shiny::actionButton("dashboard_login", "Open dashboard"),
        shiny::uiOutput("dashboard_auth_message")
      )
    })

    output$dashboard_auth_message <- shiny::renderUI({
      message <- auth_message()

      if (is.null(message)) {
        return(NULL)
      }

      shiny::tags$p(message)
    })

    shiny::observeEvent(input$dashboard_login, {
      if (identical(input$dashboard_token, access_token)) {
        authorized(TRUE)
        auth_message(NULL)
      } else {
        auth_message("Invalid dashboard token.")
      }
    })

    current_data <- shiny::reactive({
      shiny::req(authorized())
      input$refresh

      dashboard_data_from_path(
        db_path = db_path,
        tutorial_id = input$tutorial_id,
        rule = input$rule,
        include_unregistered = input$include_unregistered
      )
    })

    output$summary <- shiny::renderTable(current_data()$summary)
    output$gradebook <- shiny::renderTable(current_data()$gradebook)
    output$questions <- shiny::renderTable(current_data()$questions)
    output$attempts <- shiny::renderTable(current_data()$attempts)

    output$download_gradebook <- shiny::downloadHandler(
      filename = function() {
        paste0(input$tutorial_id, "-gradebook.csv")
      },
      content = function(file) {
        readr::write_csv(current_data()$gradebook, file)
      }
    )

    output$download_moodle <- shiny::downloadHandler(
      filename = function() {
        paste0(input$tutorial_id, "-moodle.csv")
      },
      content = function(file) {
        con <- connect_tracking_db(db_path)
        on.exit(DBI::dbDisconnect(con), add = TRUE)

        export_moodle_grades(
          con,
          file,
          tutorial_id = input$tutorial_id,
          rule = input$rule,
          grade_item = input$tutorial_id,
          include_unregistered = input$include_unregistered
        )
      }
    )
  }

  shiny::shinyApp(ui = ui, server = server)
}

#' Run the teacher dashboard
#'
#' Opens a minimal Shiny dashboard for inspecting attempts, registered
#' questions, gradebook rows, and CSV exports.
#'
#' @param db_path Path to an existing SQLite tracking database.
#' @param tutorial_id Optional tutorial identifier selected at startup. If
#'   `NULL`, the first available tutorial is selected.
#' @param rule Scoring rule passed to [gradebook()].
#' @param include_unregistered If `TRUE`, include attempted questions that were
#'   not registered with [register_questions()].
#' @param host Host passed to [shiny::runApp()]. Defaults to `"127.0.0.1"` for
#'   local-only use.
#' @param access_token Optional dashboard token. If supplied, the dashboard asks
#'   for this token before showing data.
#' @param token_envvar Environment variable used to read a dashboard token when
#'   `access_token` is `NULL`. Set to `NULL` to disable environment lookup.
#' @param allow_remote If `FALSE`, refuse to run on a non-local host unless an
#'   access token is configured.
#' @param ... Additional arguments passed to [shiny::runApp()].
#'
#' @return The return value of [shiny::runApp()].
#' @export
#'
#' @examples
#' \dontrun{
#' db_path <- "learnrtrackr.sqlite"
#' run_dashboard(db_path)
#' }
run_dashboard <- function(db_path,
                          tutorial_id = NULL,
                          rule = c("last", "best", "first"),
                          include_unregistered = TRUE,
                          host = "127.0.0.1",
                          access_token = NULL,
                          token_envvar = "LEARNRTRACKR_DASHBOARD_TOKEN",
                          allow_remote = FALSE,
                          ...) {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg shiny} is required to use {.fn run_dashboard}."
    )
  }

  db_path <- validate_path(db_path, arg = "db_path")

  if (!file.exists(db_path)) {
    cli::cli_abort("The database file does not exist: {.path {db_path}}.")
  }

  rule <- match.arg(rule)
  include_unregistered <- validate_scalar_logical(
    include_unregistered,
    arg = "include_unregistered"
  )
  host <- validate_dashboard_host(host)
  access_token <- resolve_dashboard_access_token(
    access_token = access_token,
    token_envvar = token_envvar
  )
  allow_remote <- validate_scalar_logical(
    allow_remote,
    arg = "allow_remote"
  )

  check_dashboard_launch_security(
    host = host,
    access_token = access_token,
    allow_remote = allow_remote
  )

  app <- dashboard_app(
    db_path = db_path,
    tutorial_id = tutorial_id,
    rule = rule,
    include_unregistered = include_unregistered,
    access_token = access_token
  )

  shiny::runApp(app, host = host, ...)
}
