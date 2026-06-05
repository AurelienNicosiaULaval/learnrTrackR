# Minimal learnr tracking example

This directory contains a minimal `learnr` example for `learnrTrackR`.

It uses two explicit tracking strategies:

- `learnrTrackR::tracked_question()` for `learnr` radio, checkbox, text, and
  numeric questions, using a shared context created by
  `learnrTrackR::setup_learnr_tracking()`.
- `learnrTrackR::track_gradethis_attempt()` inside `gradethis::grade_this()`
  check chunks for code exercises, using the same shared context.

Both strategies avoid relying on internal `learnr` JavaScript implementation
details.

The example also includes declarative tracking configuration files:

- `config/tracking.yml`
- `config-csv/courses.csv`
- `config-csv/tutorials.csv`
- `config-csv/students.csv`
- `config-csv/questions.csv`

## Run the tutorial

From the package source directory, install the package locally first:

```r
devtools::install(dependencies = FALSE)
```

Then run the tutorial:

```r
Sys.setenv(
  LEARNRTRACKR_DB = file.path(tempdir(), "learnrtrackr-minimal.sqlite"),
  LEARNRTRACKR_STUDENT_ID = "student_demo",
  LEARNRTRACKR_GROUP_ID = "demo_group"
)

learnr::run_tutorial(
  "inst/examples/minimal-learnr/tutorial.Rmd",
  clean = TRUE,
  as_rstudio_job = FALSE
)
```

The `LEARNRTRACKR_STUDENT_ID` value is required. The tutorial uses
`get_learnr_tracking_env()` and stops with an informative error if required
launch values are missing or empty. The tutorial creates a context with
`setup_learnr_tracking()`, registers the current learner, and loads the
expected course, tutorial, student, and question metadata from the CSV
configuration directory.

If the package is installed, the tutorial path can be found with:

```r
system.file("examples/minimal-learnr/tutorial.Rmd", package = "learnrTrackR")
```

## Inspect the results

After submitting the code exercises in the tutorial:

```r
source("inst/examples/minimal-learnr/inspect-results.R")
```

You can also inspect the same database with the teacher dashboard:

```r
learnrTrackR::run_dashboard(Sys.getenv("LEARNRTRACKR_DB"))
```

To open the dashboard with the group selected:

```r
learnrTrackR::run_dashboard(
  Sys.getenv("LEARNRTRACKR_DB"),
  group_id = Sys.getenv("LEARNRTRACKR_GROUP_ID")
)
```

## Current limitation

This example tracks the four built-in `learnr` question types covered by
`tracked_question()`: radio, checkbox, text, and numeric. Custom question types
are not covered yet.
