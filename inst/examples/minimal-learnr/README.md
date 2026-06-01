# Minimal learnr tracking example

This directory contains a minimal `learnr` prototype for `learnrTrackR`.

It uses the safest first integration strategy: explicit calls to
`learnrTrackR::track_gradethis_attempt()` inside `gradethis::grade_this()`
check chunks. This records code exercise submissions without relying on
internal `learnr` JavaScript or Shiny implementation details.

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

The multiple-choice question is included to keep the tutorial structure close
to the target use case, but it is not tracked by this helper. The helper is
called from `gradethis::grade_this()` check chunks, and the multiple-choice
question is not a code exercise with a `*-check` chunk.
