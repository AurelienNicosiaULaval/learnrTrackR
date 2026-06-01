# Minimal learnr tracking example

This directory contains a minimal `learnr` prototype for `learnrTrackR`.

It uses two explicit tracking strategies:

- `learnrTrackR::tracked_question_radio()` for the multiple-choice question.
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

If the package is installed, the tutorial path can be found with:

```r
system.file("examples/minimal-learnr/tutorial.Rmd", package = "learnrTrackR")
```

## Inspect the results

After submitting the code exercises in the tutorial:

```r
source("inst/examples/minimal-learnr/inspect-results.R")
```

## Current limitation

This prototype tracks radio-button and checkbox-style questions through custom
`learnr` question classes. It does not yet track free-text or numeric `learnr`
questions, although the same pattern can be extended to those question types.
