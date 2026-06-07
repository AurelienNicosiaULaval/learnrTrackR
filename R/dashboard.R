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

available_dashboard_groups <- function(con) {
  check_required_tables(con)

  groups <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT DISTINCT group_id",
      "FROM students",
      "WHERE group_id IS NOT NULL AND group_id != ''",
      "ORDER BY group_id ASC"
    )
  )

  tibble::as_tibble(groups)
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

normalize_dashboard_group_id <- function(group_id = NULL) {
  group_id <- validate_scalar_character(
    group_id,
    arg = "group_id",
    allow_null = TRUE,
    allow_empty = TRUE
  )

  if (is.null(group_id)) {
    return(NULL)
  }

  group_id <- trimws(group_id)

  if (!nzchar(group_id)) {
    return(NULL)
  }

  group_id
}

empty_dashboard_summary <- function() {
  tibble::tibble(
    metric = c(
      "Tutorial",
      "Group",
      "Students",
      "Attempts",
      "Questions",
      "Completed",
      "Completion rate (%)",
      "Mean percent",
      "Median percent"
    ),
    value = c(
      "No tutorial available",
      "All groups",
      "0",
      "0",
      "0",
      "0",
      NA_character_,
      NA_character_,
      NA_character_
    )
  )
}

format_dashboard_number <- function(x, digits = 1) {
  if (is.na(x)) {
    return(NA_character_)
  }

  format(round(x, digits), trim = TRUE, nsmall = digits)
}

summarise_dashboard <- function(tutorial_id,
                                group_id,
                                attempts,
                                grades,
                                questions,
                                students) {
  if (is.null(tutorial_id)) {
    return(empty_dashboard_summary())
  }

  n_students <- nrow(students)

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
      "Group",
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
      if (is.null(group_id)) "All groups" else group_id,
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

empty_dashboard_students <- function() {
  tibble::tibble(
    student_id = character(),
    student_label = character(),
    email = character(),
    group_id = character(),
    n_attempts = integer(),
    has_attempts = logical()
  )
}

filter_registered_students <- function(students, group_id = NULL) {
  if (is.null(group_id)) {
    return(students)
  }

  students[
    !is.na(students$group_id) & students$group_id == group_id,
    ,
    drop = FALSE
  ]
}

dashboard_student_ids <- function(registered_students,
                                  attempts,
                                  group_id = NULL) {
  if (!is.null(group_id)) {
    return(sort(unique(registered_students$student_id)))
  }

  sort(unique(c(registered_students$student_id, attempts$student_id)))
}

filter_attempts_by_student_ids <- function(attempts, student_ids) {
  if (length(student_ids) == 0) {
    return(attempts[FALSE, , drop = FALSE])
  }

  attempts[attempts$student_id %in% student_ids, , drop = FALSE]
}

attempt_counts_by_student <- function(attempts) {
  if (nrow(attempts) == 0) {
    return(tibble::tibble(
      student_id = character(),
      n_attempts = integer()
    ))
  }

  counts <- stats::aggregate(
    attempt_id ~ student_id,
    data = attempts,
    FUN = length
  )
  names(counts) <- c("student_id", "n_attempts")
  counts$n_attempts <- as.integer(counts$n_attempts)

  tibble::as_tibble(counts)
}

dashboard_students_table <- function(registered_students,
                                     attempts,
                                     student_ids) {
  if (length(student_ids) == 0) {
    return(empty_dashboard_students())
  }

  out <- tibble::tibble(student_id = student_ids)
  out <- dplyr::left_join(
    out,
    registered_students[
      ,
      c("student_id", "student_label", "email", "group_id"),
      drop = FALSE
    ],
    by = "student_id"
  )
  out <- dplyr::left_join(
    out,
    attempt_counts_by_student(attempts),
    by = "student_id"
  )

  out$n_attempts[is.na(out$n_attempts)] <- 0L
  out$n_attempts <- as.integer(out$n_attempts)
  out$has_attempts <- out$n_attempts > 0

  out[order(is.na(out$group_id), out$group_id, out$student_id), , drop = FALSE]
}

enrich_with_student_metadata <- function(data, registered_students) {
  metadata_columns <- c("student_id", "student_label", "email", "group_id")
  out <- dplyr::left_join(
    data,
    registered_students[, metadata_columns, drop = FALSE],
    by = "student_id"
  )

  front <- metadata_columns
  out[, c(front, setdiff(names(out), front)), drop = FALSE]
}

dashboard_gradebook <- function(con,
                                tutorial_id,
                                student_ids,
                                rule,
                                include_unregistered) {
  if (is.null(tutorial_id) || length(student_ids) == 0) {
    return(empty_gradebook_tibble())
  }

  rows <- lapply(student_ids, function(current_student_id) {
    gradebook(
      con,
      tutorial_id = tutorial_id,
      student_id = current_student_id,
      rule = rule,
      include_unregistered = include_unregistered
    )
  })

  dplyr::bind_rows(rows)
}

dashboard_moodle_grades <- function(grades,
                                    tutorial_id,
                                    id_column = "useridnumber",
                                    grade_value = "percent",
                                    digits = 2) {
  grade_item <- if (is.null(tutorial_id)) {
    "grade"
  } else {
    tutorial_id
  }

  if (nrow(grades) == 0) {
    out <- tibble::tibble(
      student_id = character(),
      grade = numeric()
    )
  } else {
    out <- tibble::tibble(
      student_id = grades$student_id,
      grade = format_grade_values(grades[[grade_value]], digits = digits)
    )
  }

  names(out) <- c(id_column, grade_item)
  out
}

safe_dashboard_filename_part <- function(value, fallback) {
  if (is.null(value) || is.na(value) || !nzchar(value)) {
    return(fallback)
  }

  value <- gsub("[^A-Za-z0-9._-]+", "-", value)
  value <- gsub("^-+|-+$", "", value)

  if (!nzchar(value)) {
    return(fallback)
  }

  value
}

dashboard_download_filename <- function(tutorial_id, group_id, type) {
  group_id <- normalize_dashboard_group_id(group_id)
  tutorial_part <- safe_dashboard_filename_part(tutorial_id, "dashboard")
  type_part <- safe_dashboard_filename_part(type, "export")

  if (is.null(group_id)) {
    return(paste0(tutorial_part, "-", type_part, ".csv"))
  }

  group_part <- safe_dashboard_filename_part(group_id, "group")
  paste0(tutorial_part, "-group-", group_part, "-", type_part, ".csv")
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
                                          include_unregistered,
                                          attempts = NULL) {
  if (is.null(tutorial_id)) {
    return(empty_dashboard_questions())
  }

  if (is.null(attempts)) {
    attempts <- get_attempts(con, tutorial_id = tutorial_id)
  }

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
#' @param group_id Optional registered student group identifier. If supplied,
#'   only students registered in that group are included.
#'
#' @return A list with tutorials, groups, selected tutorial id, selected group
#'   id, summary, student summary, gradebook, question summary, attempts, and
#'   Moodle-ready grades.
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
                           include_unregistered = TRUE,
                           group_id = NULL) {
  check_required_tables(con)

  rule <- match.arg(rule)
  include_unregistered <- validate_scalar_logical(
    include_unregistered,
    arg = "include_unregistered"
  )
  group_id <- normalize_dashboard_group_id(group_id)
  tutorials <- available_dashboard_tutorials(con)
  groups <- available_dashboard_groups(con)
  tutorial_id <- resolve_dashboard_tutorial_id(con, tutorial_id = tutorial_id)
  registered_students <- get_students(con)
  selected_registered_students <- filter_registered_students(
    registered_students,
    group_id = group_id
  )

  if (is.null(tutorial_id)) {
    attempts <- get_attempts(con)
    grades <- empty_gradebook_tibble()
    questions <- empty_dashboard_questions()
  } else {
    all_attempts <- get_attempts(con, tutorial_id = tutorial_id)
    student_ids <- dashboard_student_ids(
      registered_students = selected_registered_students,
      attempts = all_attempts,
      group_id = group_id
    )
    attempts <- if (is.null(group_id)) {
      all_attempts
    } else {
      filter_attempts_by_student_ids(all_attempts, student_ids)
    }
    grades <- dashboard_gradebook(
      con,
      tutorial_id = tutorial_id,
      student_ids = student_ids,
      rule = rule,
      include_unregistered = include_unregistered
    )
    questions <- summarise_dashboard_questions(
      con = con,
      tutorial_id = tutorial_id,
      rule = rule,
      include_unregistered = include_unregistered,
      attempts = attempts
    )
  }

  if (is.null(tutorial_id)) {
    student_ids <- dashboard_student_ids(
      registered_students = selected_registered_students,
      attempts = attempts,
      group_id = group_id
    )

    if (!is.null(group_id)) {
      attempts <- filter_attempts_by_student_ids(attempts, student_ids)
    }
  }

  students <- dashboard_students_table(
    registered_students = selected_registered_students,
    attempts = attempts,
    student_ids = student_ids
  )
  grades <- enrich_with_student_metadata(grades, registered_students)
  attempts <- enrich_with_student_metadata(attempts, registered_students)
  moodle <- dashboard_moodle_grades(
    grades = grades,
    tutorial_id = tutorial_id
  )

  list(
    tutorials = tutorials,
    groups = groups,
    tutorial_id = tutorial_id,
    group_id = group_id,
    summary = summarise_dashboard(
      tutorial_id = tutorial_id,
      group_id = group_id,
      attempts = attempts,
      grades = grades,
      questions = questions,
      students = students
    ),
    students = students,
    gradebook = grades,
    questions = questions,
    attempts = attempts,
    moodle_grades = moodle
  )
}

dashboard_data_from_path <- function(db_path,
                                     tutorial_id = NULL,
                                     rule = "last",
                                     include_unregistered = TRUE,
                                     group_id = NULL) {
  con <- connect_tracking_db(db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  dashboard_data(
    con = con,
    tutorial_id = tutorial_id,
    rule = rule,
    include_unregistered = include_unregistered,
    group_id = group_id
  )
}

dashboard_data_from_connection <- function(con,
                                           tutorial_id = NULL,
                                           rule = "last",
                                           include_unregistered = TRUE,
                                           group_id = NULL) {
  dashboard_data(
    con = con,
    tutorial_id = tutorial_id,
    rule = rule,
    include_unregistered = include_unregistered,
    group_id = group_id
  )
}

dashboard_sqlite_source <- function(db_path) {
  db_path <- validate_path(db_path, arg = "db_path")

  if (!file.exists(db_path)) {
    cli::cli_abort("The database file does not exist: {.path {db_path}}.")
  }

  function(tutorial_id = NULL,
           rule = "last",
           include_unregistered = TRUE,
           group_id = NULL) {
    dashboard_data_from_path(
      db_path = db_path,
      tutorial_id = tutorial_id,
      rule = rule,
      include_unregistered = include_unregistered,
      group_id = group_id
    )
  }
}

dashboard_connection_source <- function(con) {
  check_required_tables(con)

  function(tutorial_id = NULL,
           rule = "last",
           include_unregistered = TRUE,
           group_id = NULL) {
    dashboard_data_from_connection(
      con = con,
      tutorial_id = tutorial_id,
      rule = rule,
      include_unregistered = include_unregistered,
      group_id = group_id
    )
  }
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
                              group_choices,
                              selected_group,
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
        "group_id",
        "Group",
        choices = group_choices,
        selected = selected_group
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
      shiny::h3("Students"),
      shiny::tableOutput("students"),
      shiny::h3("Gradebook"),
      shiny::tableOutput("gradebook"),
      shiny::h3("Questions"),
      shiny::tableOutput("questions"),
      shiny::h3("Attempts"),
      shiny::tableOutput("attempts")
    )
  )
}

dashboard_source_app <- function(data_source,
                                 tutorial_id = NULL,
                                 rule = "last",
                                 include_unregistered = TRUE,
                                 group_id = NULL,
                                 access_token = NULL) {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg shiny} is required to use {.fn run_dashboard}."
    )
  }

  initial_data <- data_source(
    tutorial_id = tutorial_id,
    rule = rule,
    include_unregistered = include_unregistered,
    group_id = group_id
  )
  choices <- initial_data$tutorials$tutorial_id
  group_values <- initial_data$groups$group_id
  group_choices <- c(
    "All groups" = "",
    stats::setNames(group_values, group_values)
  )
  selected <- tutorial_id
  selected_group <- if (is.null(group_id)) "" else group_id

  if (is.null(selected) && length(choices) > 0) {
    selected <- choices[[1]]
  }

  dashboard_ui <- dashboard_main_ui(
    choices = choices,
    selected = selected,
    group_choices = group_choices,
    selected_group = selected_group,
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

      data_source(
        tutorial_id = input$tutorial_id,
        rule = input$rule,
        include_unregistered = input$include_unregistered,
        group_id = input$group_id
      )
    })

    output$summary <- shiny::renderTable(current_data()$summary)
    output$students <- shiny::renderTable(current_data()$students)
    output$gradebook <- shiny::renderTable(current_data()$gradebook)
    output$questions <- shiny::renderTable(current_data()$questions)
    output$attempts <- shiny::renderTable(current_data()$attempts)

    output$download_gradebook <- shiny::downloadHandler(
      filename = function() {
        dashboard_download_filename(
          tutorial_id = input$tutorial_id,
          group_id = input$group_id,
          type = "gradebook"
        )
      },
      content = function(file) {
        readr::write_csv(current_data()$gradebook, file)
      }
    )

    output$download_moodle <- shiny::downloadHandler(
      filename = function() {
        dashboard_download_filename(
          tutorial_id = input$tutorial_id,
          group_id = input$group_id,
          type = "moodle"
        )
      },
      content = function(file) {
        readr::write_csv(current_data()$moodle_grades, file)
      }
    )
  }

  shiny::shinyApp(ui = ui, server = server)
}

dashboard_app <- function(db_path,
                          tutorial_id = NULL,
                          rule = "last",
                          include_unregistered = TRUE,
                          group_id = NULL,
                          access_token = NULL) {
  dashboard_source_app(
    data_source = dashboard_sqlite_source(db_path),
    tutorial_id = tutorial_id,
    rule = rule,
    include_unregistered = include_unregistered,
    group_id = group_id,
    access_token = access_token
  )
}

dashboard_connection_app <- function(con,
                                     tutorial_id = NULL,
                                     rule = "last",
                                     include_unregistered = TRUE,
                                     group_id = NULL,
                                     access_token = NULL) {
  dashboard_source_app(
    data_source = dashboard_connection_source(con),
    tutorial_id = tutorial_id,
    rule = rule,
    include_unregistered = include_unregistered,
    group_id = group_id,
    access_token = access_token
  )
}

normalize_postgres_schema_name <- function(schema = NULL) {
  schema <- validate_scalar_character(
    schema,
    arg = "postgres_schema",
    allow_null = TRUE,
    allow_empty = TRUE
  )

  if (is.null(schema)) {
    return(NULL)
  }

  schema <- trimws(schema)

  if (!nzchar(schema)) {
    return(NULL)
  }

  if (!grepl("^[A-Za-z_][A-Za-z0-9_]*$", schema)) {
    cli::cli_abort(
      "{.arg postgres_schema} must start with a letter or underscore and contain only letters, digits, or underscores."
    )
  }

  schema
}

set_postgres_dashboard_schema <- function(con,
                                          postgres_schema = NULL,
                                          initialize = FALSE) {
  postgres_schema <- normalize_postgres_schema_name(postgres_schema)

  if (is.null(postgres_schema)) {
    return(invisible(NULL))
  }

  quoted_schema <- DBI::dbQuoteIdentifier(con, postgres_schema)

  if (initialize) {
    DBI::dbExecute(con, paste("CREATE SCHEMA IF NOT EXISTS", quoted_schema))
  }

  DBI::dbExecute(con, paste("SET search_path TO", quoted_schema))

  invisible(postgres_schema)
}

connect_dashboard_postgres_db <- function(dbname,
                                          postgres_host,
                                          postgres_port,
                                          postgres_user,
                                          postgres_password = NULL,
                                          postgres_schema = NULL,
                                          initialize = FALSE) {
  if (!requireNamespace("RPostgres", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg RPostgres} is required to connect to PostgreSQL."
    )
  }

  dbname <- validate_scalar_character(dbname, arg = "dbname")
  postgres_host <- validate_scalar_character(postgres_host, arg = "postgres_host")
  postgres_port <- validate_positive_integer(postgres_port, arg = "postgres_port")
  postgres_user <- validate_scalar_character(postgres_user, arg = "postgres_user")
  postgres_password <- validate_scalar_character(
    postgres_password,
    arg = "postgres_password",
    allow_null = TRUE,
    allow_empty = TRUE
  )
  initialize <- validate_scalar_logical(initialize, arg = "initialize")

  connection_args <- list(
    dbname = dbname,
    host = postgres_host,
    port = postgres_port,
    user = postgres_user
  )

  if (!is.null(postgres_password) && nzchar(postgres_password)) {
    connection_args$password <- postgres_password
  }

  con <- do.call(
    DBI::dbConnect,
    c(list(drv = RPostgres::Postgres()), connection_args)
  )

  tryCatch(
    {
      set_postgres_dashboard_schema(
        con,
        postgres_schema = postgres_schema,
        initialize = initialize
      )

      if (initialize) {
        create_schema(con)
      }

      check_required_tables(con)
      con
    },
    error = function(cnd) {
      if (DBI::dbIsValid(con)) {
        DBI::dbDisconnect(con)
      }

      stop(cnd)
    }
  )
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
#' @param group_id Optional registered student group identifier selected at
#'   startup. If supplied, the dashboard is filtered to students in that group.
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
                          group_id = NULL,
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
  group_id <- normalize_dashboard_group_id(group_id)
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
    group_id = group_id,
    access_token = access_token
  )

  shiny::runApp(app, host = host, ...)
}

#' Run the teacher dashboard from an open DBI connection
#'
#' Opens the same Shiny dashboard as [run_dashboard()], but reads data from an
#' existing DBI connection instead of a SQLite file path. The caller owns the
#' connection and is responsible for disconnecting it after the dashboard stops.
#'
#' @inheritParams dashboard_data
#' @inheritParams run_dashboard
#'
#' @return The return value of [shiny::runApp()].
#' @export
#'
#' @examples
#' \dontrun{
#' db_path <- "learnrtrackr.sqlite"
#' con <- connect_tracking_db(db_path)
#' run_dashboard_connection(con)
#' DBI::dbDisconnect(con)
#' }
run_dashboard_connection <- function(con,
                                     tutorial_id = NULL,
                                     rule = c("last", "best", "first"),
                                     include_unregistered = TRUE,
                                     group_id = NULL,
                                     host = "127.0.0.1",
                                     access_token = NULL,
                                     token_envvar = "LEARNRTRACKR_DASHBOARD_TOKEN",
                                     allow_remote = FALSE,
                                     ...) {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg shiny} is required to use {.fn run_dashboard_connection}."
    )
  }

  check_required_tables(con)
  rule <- match.arg(rule)
  include_unregistered <- validate_scalar_logical(
    include_unregistered,
    arg = "include_unregistered"
  )
  group_id <- normalize_dashboard_group_id(group_id)
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

  app <- dashboard_connection_app(
    con = con,
    tutorial_id = tutorial_id,
    rule = rule,
    include_unregistered = include_unregistered,
    group_id = group_id,
    access_token = access_token
  )

  shiny::runApp(app, host = host, ...)
}

#' Run the teacher dashboard from PostgreSQL
#'
#' Connects to a PostgreSQL tracking database and opens the teacher dashboard.
#' Connection settings default to `LEARNRTRACKR_POSTGRES_*` environment
#' variables. If `postgres_schema` is supplied, the PostgreSQL `search_path` is
#' set to that schema before dashboard data are read.
#'
#' @param dbname PostgreSQL database name. Defaults to
#'   `LEARNRTRACKR_POSTGRES_DB`, or `"learnrtrackr"` when unset.
#' @param postgres_host PostgreSQL host. Defaults to
#'   `LEARNRTRACKR_POSTGRES_HOST`, or `"127.0.0.1"` when unset.
#' @param postgres_port PostgreSQL port. Defaults to
#'   `LEARNRTRACKR_POSTGRES_PORT`, or `5432` when unset.
#' @param postgres_user PostgreSQL user. Defaults to
#'   `LEARNRTRACKR_POSTGRES_USER`, or `"learnrtrackr"` when unset.
#' @param postgres_password Optional PostgreSQL password. Defaults to
#'   `LEARNRTRACKR_POSTGRES_PASSWORD`.
#' @param postgres_schema Optional PostgreSQL schema. Defaults to
#'   `LEARNRTRACKR_POSTGRES_SCHEMA`.
#' @param initialize If `TRUE`, create `postgres_schema` when supplied and
#'   create missing tracking tables before launching the dashboard.
#' @inheritParams run_dashboard
#'
#' @return The return value of [shiny::runApp()].
#' @export
#'
#' @examples
#' \dontrun{
#' run_dashboard_postgres(
#'   postgres_schema = "learnrtrackr_pilot",
#'   group_id = "A",
#'   access_token = Sys.getenv("LEARNRTRACKR_DASHBOARD_TOKEN")
#' )
#' }
run_dashboard_postgres <- function(dbname = Sys.getenv(
                                     "LEARNRTRACKR_POSTGRES_DB",
                                     unset = "learnrtrackr"
                                   ),
                                   postgres_host = Sys.getenv(
                                     "LEARNRTRACKR_POSTGRES_HOST",
                                     unset = "127.0.0.1"
                                   ),
                                   postgres_port = as.integer(Sys.getenv(
                                     "LEARNRTRACKR_POSTGRES_PORT",
                                     unset = "5432"
                                   )),
                                   postgres_user = Sys.getenv(
                                     "LEARNRTRACKR_POSTGRES_USER",
                                     unset = "learnrtrackr"
                                   ),
                                   postgres_password = Sys.getenv(
                                     "LEARNRTRACKR_POSTGRES_PASSWORD",
                                     unset = ""
                                   ),
                                   postgres_schema = Sys.getenv(
                                     "LEARNRTRACKR_POSTGRES_SCHEMA",
                                     unset = ""
                                   ),
                                   initialize = FALSE,
                                   tutorial_id = NULL,
                                   rule = c("last", "best", "first"),
                                   include_unregistered = TRUE,
                                   group_id = Sys.getenv(
                                     "LEARNRTRACKR_PILOT_GROUP_ID",
                                     unset = ""
                                   ),
                                   host = "127.0.0.1",
                                   access_token = NULL,
                                   token_envvar = "LEARNRTRACKR_DASHBOARD_TOKEN",
                                   allow_remote = FALSE,
                                   ...) {
  con <- connect_dashboard_postgres_db(
    dbname = dbname,
    postgres_host = postgres_host,
    postgres_port = postgres_port,
    postgres_user = postgres_user,
    postgres_password = postgres_password,
    postgres_schema = postgres_schema,
    initialize = initialize
  )
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  run_dashboard_connection(
    con = con,
    tutorial_id = tutorial_id,
    rule = rule,
    include_unregistered = include_unregistered,
    group_id = group_id,
    host = host,
    access_token = access_token,
    token_envvar = token_envvar,
    allow_remote = allow_remote,
    ...
  )
}
