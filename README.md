# learnrTrackR

`learnrTrackR` is an early-stage R package for tracking simulated tutorial
attempts in a local SQLite database.

The long-term goal is to provide a light, open, reproducible layer for storing
answers, attempts, grading results, scores, and exports from interactive
teaching workflows built around `learnr`-style tutorials.

This first version is intentionally small. It validates the database layer
while keeping `learnr`, `gradethis`, Moodle, and Shiny integration minimal.

## Problem

Interactive tutorials are useful for teaching R and statistics, but instructors
also need reliable records of what students submitted, how many times they
tried, what feedback was returned, and what score should be exported.

This package starts with the simplest useful layer: a local database that can
store simulated attempts and export results for inspection.

## What the MVP does

- Create a SQLite tracking database.
- Create the required schema.
- Record simulated attempts.
- Register courses and tutorials.
- Register expected student identifiers.
- Register expected tutorial questions.
- Load course, tutorial, student, and question metadata from YAML or CSV
  configuration files.
- Read and filter attempts.
- Compute simple scores using first, last, or best attempt rules.
- Build a gradebook that counts unanswered registered questions.
- Export attempts or scores to CSV.
- Export a simple Moodle-ready CSV grade table.
- Document a cautious Moodle CSV import workflow.
- Export rich CSV bundles for a tutorial, group, or student.
- Open a minimal local Shiny teacher dashboard.
- Filter dashboard tables and dashboard CSV exports by registered group.
- Provide a minimal example and unit tests.
- Provide a minimal `learnr` and `gradethis` prototype for tracked
  questions and code exercises.
- Provide a course pilot example with CSV configuration, simulated learner
  results, Moodle export, and teacher report generation.

## What the MVP does not do yet

- It does not automatically instrument arbitrary `learnr` tutorials.
- It does not capture `gradethis` checks unless the tracking helper is called
  explicitly.
- It does not provide institutional authentication or role-based access
  control for the dashboard.
- It does not connect to Moodle by API; Moodle export is CSV-based.
- It does not verify real student identity beyond optional local registry
  checks.
- It is not designed yet for high-concurrency production use.

## Installation during development

From the package directory:

```r
devtools::load_all()
```

or:

```r
devtools::install()
```

## Minimal example

```r
library(learnrTrackR)

db_path <- tempfile(fileext = ".sqlite")
con <- init_tracking_db(db_path, overwrite = TRUE)

register_students(
  con,
  data.frame(
    student_id = c("student_001", "student_002"),
    student_label = c("Student 1", "Student 2"),
    group_id = c("A", "A")
  )
)

register_courses(
  con,
  data.frame(
    course_id = "stat101",
    course_label = "Statistics 101",
    semester = "W2026"
  )
)

register_tutorials(
  con,
  data.frame(
    tutorial_id = "module_01",
    course_id = "stat101",
    tutorial_label = "Module 01"
  )
)

register_questions(
  con,
  tutorial_id = "module_01",
  questions = data.frame(
    question_id = c("q1", "q2", "q3"),
    max_score = c(1, 1, 1)
  )
)

track_attempt(
  con = con,
  student_id = "student_001",
  tutorial_id = "module_01",
  question_id = "q1",
  submitted_answer = "mean(x)",
  grade_status = "correct",
  score = 1,
  max_score = 1,
  feedback = "Correct.",
  require_registered_student = TRUE
)

track_attempt(
  con = con,
  student_id = "student_001",
  tutorial_id = "module_01",
  question_id = "q2",
  submitted_answer = "summarise(df, x = mean(x))",
  grade_status = "partial",
  score = 0.5,
  max_score = 1,
  feedback = "Good idea, but check grouping."
)

get_attempts(con)
compute_scores(con, tutorial_id = "module_01", rule = "last")
gradebook(con, tutorial_id = "module_01", rule = "last")

export_results(con, tempfile(fileext = ".csv"), type = "attempts")
export_results(con, tempfile(fileext = ".csv"), type = "scores")
export_results(
  con,
  tempfile(fileext = ".csv"),
  type = "gradebook",
  tutorial_id = "module_01"
)
export_moodle_grades(
  con,
  tempfile(fileext = ".csv"),
  tutorial_id = "module_01",
  grade_item = "Module 01 quiz"
)
export_tracking_bundle(
  con,
  tempfile(),
  tutorial_id = "module_01",
  group_id = "A"
)

DBI::dbDisconnect(con)
```

## Teacher dashboard

A minimal local Shiny dashboard can inspect attempts, registered questions,
gradebook rows, and export files:

```r
run_dashboard(db_path)
```

For an open DBI connection, including PostgreSQL, use:

```r
run_dashboard_connection(con, group_id = "A")
```

The PostgreSQL launcher can also read the Docker example environment
variables:

```r
run_dashboard_postgres(
  postgres_schema = "learnrtrackr_pilot",
  tutorial_id = "stat_descriptive_pilot",
  group_id = "A"
)
```

Registered student groups can be selected in the dashboard. The same filter is
applied to the displayed students, attempts, gradebook rows, and downloaded CSV
files.

By default, the dashboard is launched on `127.0.0.1`. A simple local access
token can be required by setting an environment variable:

```r
Sys.setenv(LEARNRTRACKR_DASHBOARD_TOKEN = "replace-with-a-long-token")
run_dashboard(db_path)
```

Running on a non-local host without a token is refused by default. The token
gate is intended for local inspection and small prototypes. It is not a secured
production deployment interface and does not replace institutional
authentication.

## Teacher configuration

Course, tutorial, student, and question metadata can be declared in YAML or in
a directory of CSV files:

```r
create_tracking_config_template("config", format = "csv")
```

```text
config/
  courses.csv
  tutorials.csv
  students.csv
  questions.csv
```

Then load the configuration into the tracking database:

```r
load_tracking_config(con, "config")
```

For a single-file setup, create a YAML template instead:

```r
create_tracking_config_template("tracking.yml", format = "yaml")
load_tracking_config(con, "tracking.yml")
```

The minimal `learnr` example includes both a YAML configuration file and a CSV
configuration directory.

## Course pilot example

A course-like pilot is available in `inst/examples/course-pilot/`. It contains
a simulated descriptive statistics tutorial with tracked `learnr` questions,
tracked `gradethis` code exercises, CSV configuration files, a cohort
simulation script, explicit student and teacher launch scripts, Moodle export,
dashboard launch, a preflight checklist, and teacher report generation.

The pilot includes both a CSV configuration directory and a single-file YAML
configuration:

```text
inst/examples/course-pilot/config-csv/
inst/examples/course-pilot/config/tracking.yml
```

To create simulated pilot results:

```r
source("inst/examples/course-pilot/simulate-results.R")
source("inst/examples/course-pilot/inspect-results.R")
```

For a student-style launch, copy the example environment file and run the
student launcher:

```sh
cd inst/examples/course-pilot
cp student.env.example student.env
Rscript run-student.R
```

The teacher output workflow can be launched separately:

```sh
cd inst/examples/course-pilot
cp teacher.env.example teacher.env
Rscript run-teacher.R
```

The tutorial can also be launched manually from R:

```r
Sys.setenv(
  LEARNRTRACKR_DB = file.path(tempdir(), "learnrtrackr-course-pilot.sqlite"),
  LEARNRTRACKR_STUDENT_ID = "student_demo",
  LEARNRTRACKR_GROUP_ID = "A"
)

learnr::run_tutorial(
  "inst/examples/course-pilot/tutorial.Rmd",
  clean = TRUE,
  as_rstudio_job = FALSE
)
```

Before a real controlled pilot, read
`inst/examples/course-pilot/pilot-checklist.md`.

## PostgreSQL prototype

SQLite remains the default backend for local prototypes. For a server-backed
course setup, install `RPostgres` and connect to an existing PostgreSQL
database:

```r
con <- connect_postgres_tracking_db(
  dbname = "learnrtrackr",
  host = "localhost",
  user = "learnrtrackr",
  password = Sys.getenv("LEARNRTRACKR_POSTGRES_PASSWORD"),
  initialize = TRUE
)

load_tracking_config(con, "config")
```

The PostgreSQL path is intended for controlled deployments. Use
`dashboard_data(con, ...)` for non-interactive inspection,
`run_dashboard_connection(con, ...)` for an open DBI connection, or
`run_dashboard_postgres(...)` for environment-variable based PostgreSQL
launches.

For a reproducible local PostgreSQL rehearsal, see:

```r
vignette("deployment-postgresql", package = "learnrTrackR")
```

The Docker Compose example is included in
`inst/examples/postgres-docker/`.

The same Docker example also includes a controlled course pilot rehearsal:

```sh
cd inst/examples/postgres-docker
cp env.example .env
docker compose --env-file .env up -d
Rscript course-pilot-smoke-test.R
Rscript run-dashboard.R
```

The pilot smoke test loads the `course-pilot` CSV configuration, records the
simulated cohort in PostgreSQL, prepares dashboard data, writes Moodle-ready
grades filtered by group, writes an export bundle, and renders an HTML teacher
report when `rmarkdown` is installed.

## Privacy utilities

Student-level records can be deleted, pseudonymised, or stripped of direct
identifiers:

```r
delete_student_data(con, "student_001")
pseudo <- pseudonymise_results(tracking_export_data(con, "module_01"))
anonymous <- anonymise_results(pseudo$data)
```

See `privacy.md` for practical data-governance notes.

## Pedagogical analytics

The package can produce teacher-facing summaries for an individual tutorial:

```r
summarise_questions(con, "module_01")
summarise_students(con, "module_01")
detect_difficult_questions(con, "module_01")
detect_stalled_students(con, "module_01")
generate_teacher_report(con, "teacher-report.html", "module_01")
```

These helpers use the same scoring rules as `gradebook()` and can be filtered
by registered group.

## Short roadmap after 0.2.0

1. Rehearse the course pilot with one real tutorial section and a small number
   of volunteer learners.
2. Decide the institutional student identifier, authentication boundary, and
   data-retention period outside the package.
3. Add a deployment guide for a managed Shiny or Posit Connect environment.
4. Add stricter operational checks for duplicate learners, missing questions,
   and unexpected Moodle export rows.
5. Prepare a `0.3.0` release focused on production deployment hardening.

## Minimal learnr prototype

The directory `inst/examples/minimal-learnr/` contains a small tutorial with
tracked radio, text, and numeric questions, plus two tracked code exercises.
The setup chunk creates a reusable context with `setup_learnr_tracking()`. The
questions use the generic `tracked_question()` helper with that context. The
code exercises use explicit calls to `track_gradethis_attempt()` inside
`gradethis::grade_this()` check chunks.

From the package source directory, install the package locally first:

```r
devtools::install(dependencies = FALSE)
```

Then run the tutorial:

```r
Sys.setenv(
  LEARNRTRACKR_DB = file.path(tempdir(), "learnrtrackr-minimal.sqlite"),
  LEARNRTRACKR_STUDENT_ID = "student_demo"
)

learnr::run_tutorial(
  "inst/examples/minimal-learnr/tutorial.Rmd",
  clean = TRUE,
  as_rstudio_job = FALSE
)
```

After submitting the code exercises:

```r
source("inst/examples/minimal-learnr/inspect-results.R")
```

You can also inspect the same database with the teacher dashboard:

```r
learnrTrackR::run_dashboard(Sys.getenv("LEARNRTRACKR_DB"))
```

The four built-in `learnr` question families can be tracked with
`tracked_question()`, or with the explicit wrappers
`tracked_question_radio()`, `tracked_question_checkbox()`,
`tracked_question_text()`, and `tracked_question_numeric()`.
Use `get_learnr_tracking_env()` to validate the launch environment, then
`setup_learnr_tracking()` in a tutorial setup chunk to initialize the database,
load configuration, register the current learner, and pass the returned context
to tracked questions.

For a compact guide to this workflow, see:

```r
vignette("learnr-context", package = "learnrTrackR")
```

Student identity is read with `get_tracking_student_id()`, which checks the
`LEARNRTRACKR_STUDENT_ID` environment variable and throws an informative error
when it is missing.

Expected student identifiers can be stored with `register_students()`. Attempts
can then require a registered identifier by setting
`require_registered_student = TRUE` in `track_attempt()`.

`export_tracking_bundle()` writes richer teacher-facing CSV files, including
students, attempts, scores, gradebook rows, question metadata, summary metrics,
and Moodle-ready grades. The export can be filtered by `group_id` or
`student_id`.

`export_moodle_grades()` writes a compact CSV with one student identifier column
and one grade item column. Moodle then asks the teacher to map these columns to
the appropriate user field and grade item during CSV import.

For the full Moodle CSV workflow, see:

```r
vignette("moodle-export", package = "learnrTrackR")
```
