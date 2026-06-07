# Course pilot example

This example is a course-like pilot for `learnrTrackR`. It uses a simulated
descriptive statistics tutorial and shows the full teacher workflow:

- launch a tracked `learnr` tutorial;
- load course, tutorial, student, and question metadata from CSV files;
- record tracked `learnr` questions and `gradethis` code checks;
- simulate a small cohort without manual browser interaction;
- inspect attempts, scores, gradebook rows, Moodle-ready grades, export
  bundles, and a teacher report.
- launch a student-style session and a teacher output workflow from explicit R
  scripts.

The data are simulated and do not represent real students.

## Files

```text
course-pilot/
  tutorial.Rmd
  pilot-data.R
  pilot-workflow.R
  simulate-results.R
  inspect-results.R
  run-student.R
  run-teacher.R
  student.env.example
  teacher.env.example
  pilot-checklist.md
  tracking-strategy.md
  config/
    tracking.yml
  config-csv/
    courses.csv
    tutorials.csv
    students.csv
    questions.csv
```

`config-csv/` is used by the launch scripts. `config/tracking.yml` is the same
pilot configuration in a compact single-file format.

## Student launch script

For a student-style launch:

```sh
cp student.env.example student.env
Rscript run-student.R
```

Edit `student.env` to set:

```text
LEARNRTRACKR_DB=course-pilot.sqlite
LEARNRTRACKR_STUDENT_ID=student_demo
LEARNRTRACKR_GROUP_ID=A
```

## Run the tutorial

From the package source directory, install the package locally first:

```r
devtools::install(dependencies = FALSE)
```

Then launch the tutorial:

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

For the intended pilot workflow, use one of the identifiers listed in
`config-csv/students.csv` so the group filters and teacher exports match the
configured cohort.

## Teacher launch script

For a teacher-style output workflow:

```sh
cp teacher.env.example teacher.env
Rscript run-teacher.R
```

The script writes attempts, scores, gradebook rows, Moodle-ready grades, a rich
export bundle, and a teacher report. Set
`LEARNRTRACKR_TEACHER_OPEN_DASHBOARD=true` in `teacher.env` to open the local
dashboard after the exports are created.

## Simulate a cohort

To create a reproducible database without manually using the browser:

```r
source("inst/examples/course-pilot/simulate-results.R")
```

This creates a SQLite database at `LEARNRTRACKR_DB`, or at a temporary path when
the environment variable is not set.

## Inspect teacher outputs

After running the tutorial or the simulation:

```r
source("inst/examples/course-pilot/inspect-results.R")
```

The script writes:

- attempts CSV;
- scores CSV;
- gradebook CSV;
- Moodle-ready CSV;
- rich export bundle;
- HTML teacher report, when `rmarkdown` is installed.

The default output directory is:

```r
file.path(dirname(Sys.getenv("LEARNRTRACKR_DB")), "course-pilot-outputs")
```

You can override it with:

```r
Sys.setenv(LEARNRTRACKR_OUTPUT_DIR = "course-pilot-outputs")
```

## Open the dashboard

```r
learnrTrackR::run_dashboard(Sys.getenv("LEARNRTRACKR_DB"), group_id = "A")
```

The dashboard remains a local inspection tool. It is not an institutional
authentication layer.

## Preflight checklist

Before a real controlled pilot, read `pilot-checklist.md`.
