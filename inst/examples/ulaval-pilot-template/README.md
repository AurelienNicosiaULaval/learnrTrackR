# ULaval pilot dry-run template

This installed example provides a safe local rehearsal for a course pilot. It
uses only fictional learners, empty email fields, a small CSV/YAML
configuration, and scripted attempts. It is designed to confirm that the local
database, scoring, readiness checks, Moodle export, Canvas export, and bundle
export work before adapting a real course setup.

The files are:

```text
ulaval-pilot-template/
  run-dry-run.R
  config/
    tracking.yml
  config-csv/
    courses.csv
    tutorials.csv
    students.csv
    questions.csv
```

`config-csv/` and `config/tracking.yml` contain the same fictional
configuration. The dry-run script loads the CSV directory because it mirrors the
multi-file configuration format used for pilot operations.

## Run the dry-run

From the package source directory, install the package locally first:

```r
devtools::install(dependencies = FALSE)
```

Then run:

```r
source("inst/examples/ulaval-pilot-template/run-dry-run.R")
```

The script creates a SQLite database and an output directory under `tempdir()`
unless you set explicit paths:

```r
Sys.setenv(
  LEARNRTRACKR_DB = "ulaval-pilot-template.sqlite",
  LEARNRTRACKR_OUTPUT_DIR = "ulaval-pilot-template-outputs",
  LEARNRTRACKR_GROUP_ID = "A"
)

source("inst/examples/ulaval-pilot-template/run-dry-run.R")
```

The default group filter is `A`. In the fictional data, group A is complete, so
the readiness CSV should contain only `ok` statuses. Group B is included as a
partial cohort to make it clear that the default dry-run is scoped to a
selected pilot group.

The script writes:

- `dry-run-readiness.csv`;
- `dry-run-attempts.csv`;
- `dry-run-scores.csv`;
- `dry-run-gradebook.csv`;
- `dry-run-moodle.csv`;
- `dry-run-canvas.csv`;
- `dry-run-bundle/`;
- `dry-run-teacher-report.html`, when `rmarkdown` is installed and report
  rendering is enabled.

To disable HTML report rendering:

```r
Sys.setenv(LEARNRTRACKR_RENDER_REPORT = "false")
```

## Adapt for a real pilot

Copy the directory outside the package source before editing it for a real
course. Replace the fictional `student_id` values with the chosen institutional
identifiers only in a private working area, keep email fields empty unless they
are needed for the selected LMS import, and do not commit identifiable learner
data to the repository.
