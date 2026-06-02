# Minimal learnr tracking example

This directory contains a minimal `learnr` prototype for `learnrTrackR`.

It uses two explicit tracking strategies:

- `learnrTrackR::tracked_question()` for `learnr` radio, checkbox, text, and
  numeric questions.
- `learnrTrackR::track_gradethis_attempt()` inside `gradethis::grade_this()`
  check chunks for code exercises.

Both strategies avoid relying on internal `learnr` JavaScript implementation
details.

## Run the tutorial

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

The `LEARNRTRACKR_STUDENT_ID` value is required. The tutorial uses
`get_tracking_student_id()` and stops with an informative error if the variable
is missing or empty.

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

## Current limitation

This prototype tracks the four built-in `learnr` question types covered by
`tracked_question()`: radio, checkbox, text, and numeric. Custom question types
are not covered yet.
