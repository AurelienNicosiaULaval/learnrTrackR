# PostgreSQL Docker example

This directory contains a local PostgreSQL example for testing the optional
`learnrTrackR` PostgreSQL backend and rehearsing a controlled course pilot.

This setup is intended for local development and deployment rehearsal. It is
not a full production configuration.

## Start PostgreSQL

Copy the example environment file and replace the password:

```sh
cp env.example .env
```

Edit `.env`, then start the service:

```sh
docker compose --env-file .env up -d
```

## Run the R smoke test

From this directory:

```sh
Rscript smoke-test.R
```

The script connects to PostgreSQL, creates the tracking schema, inserts a
unique demo course, student, question set, and attempt, then prints the
gradebook row.

## Run the course pilot smoke test

The course pilot smoke test uses the installed `course-pilot` example. It
creates an isolated PostgreSQL schema, loads the CSV configuration, records the
simulated cohort, prepares dashboard data, writes Moodle-ready grades filtered
by group, writes a rich export bundle, and renders a teacher report when
`rmarkdown` is installed.

Relevant `.env` values:

```text
LEARNRTRACKR_POSTGRES_SCHEMA=learnrtrackr_pilot
LEARNRTRACKR_PILOT_GROUP_ID=A
LEARNRTRACKR_PILOT_OUTPUT_DIR=pilot-outputs
LEARNRTRACKR_PILOT_RESET=true
```

Run:

```sh
Rscript course-pilot-smoke-test.R
```

The default output directory is `pilot-outputs/` in this directory. It is
ignored by Git because it may contain student identifiers in real deployments.

The interactive Shiny launcher still expects a SQLite path. For PostgreSQL,
this pilot verifies the non-interactive dashboard data with
`learnrTrackR::dashboard_data(con, ...)`, plus exports and report generation.

## Stop PostgreSQL

```sh
docker compose --env-file .env down
```

To delete the local PostgreSQL data volume:

```sh
docker compose --env-file .env down -v
```
