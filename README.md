# learnrTrackR

`learnrTrackR` is an early-stage R package for tracking simulated tutorial
attempts in a local SQLite database.

The long-term goal is to provide a light, open, reproducible layer for storing
answers, attempts, grading results, scores, and exports from interactive
teaching workflows built around `learnr`-style tutorials.

This first version is intentionally small. It validates the database layer
before any deeper integration with `learnr`, `gradethis`, Shiny, Moodle, or
institutional authentication.

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
- Read and filter attempts.
- Compute simple scores using first, last, or best attempt rules.
- Export attempts or scores to CSV.
- Provide a minimal example and unit tests.
- Provide a minimal `learnr` and `gradethis` prototype for tracked
  questions and code exercises.

## What the MVP does not do yet

- It does not automatically instrument arbitrary `learnr` tutorials.
- It does not capture `gradethis` checks unless the tracking helper is called
  explicitly.
- It does not provide a Shiny dashboard.
- It does not export directly to Moodle.
- It does not implement authentication or student identity verification.
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

track_attempt(
  con = con,
  student_id = "student_001",
  tutorial_id = "module_01",
  question_id = "q1",
  submitted_answer = "mean(x)",
  grade_status = "correct",
  score = 1,
  max_score = 1,
  feedback = "Correct."
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

export_results(con, tempfile(fileext = ".csv"), type = "attempts")
export_results(con, tempfile(fileext = ".csv"), type = "scores")

DBI::dbDisconnect(con)
```

## Short roadmap

1. Validate the SQLite storage layer with simulated attempts.
2. Expand the minimal `learnr` tutorial integration prototype.
3. Add stronger student identification workflows.
4. Add richer gradebook and Moodle-oriented exports.
5. Add an instructor dashboard after the storage layer is stable.

## Minimal learnr prototype

The directory `inst/examples/minimal-learnr/` contains a small tutorial with
tracked radio, text, and numeric questions, plus two tracked code exercises.
The questions use the generic `tracked_question()` helper. The code exercises
use explicit calls to `track_gradethis_attempt()` inside
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

The four built-in `learnr` question families can be tracked with
`tracked_question()`, or with the explicit wrappers
`tracked_question_radio()`, `tracked_question_checkbox()`,
`tracked_question_text()`, and `tracked_question_numeric()`.
