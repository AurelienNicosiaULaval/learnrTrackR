# Course pilot preflight checklist

This checklist is intended before using the course pilot workflow with real
learners. The example data are simulated, but the same checks apply before a
small controlled class rehearsal.

## Configuration

- Confirm the course and tutorial identifiers in `config-csv/tutorials.csv`.
- Confirm the same identifiers in `config/tracking.yml` if using the YAML
  configuration.
- Confirm that every assessed question in `tutorial.Rmd` appears in
  `config-csv/questions.csv`.
- Confirm that `max_score` values match the intended grading scheme.
- Confirm that each expected learner appears exactly once in
  `config-csv/students.csv`.
- Confirm the group identifiers used for dashboard filters and Moodle exports.

## Privacy

- Use only the student identifier required for Moodle matching.
- Leave email blank unless it is operationally required.
- Do not commit `.env`, `student.env`, `teacher.env`, SQLite databases, or
  generated exports.
- Store exported CSV files in a location with access restricted to the teaching
  team.
- Decide how long attempts, exports, and reports will be retained.

## Student launch

- Copy `student.env.example` to `student.env` for local rehearsal.
- Set `LEARNRTRACKR_DB` to the intended tracking database.
- Set `LEARNRTRACKR_STUDENT_ID` to a configured student identifier.
- Set `LEARNRTRACKR_GROUP_ID` to the configured group for that learner.
- Launch with `Rscript run-student.R` and submit at least one answer.

## Teacher launch

- Copy `teacher.env.example` to `teacher.env` for local rehearsal.
- Set `LEARNRTRACKR_DB` to the same tracking database used by learners.
- Set `LEARNRTRACKR_GROUP_ID` to the group being inspected.
- Run `Rscript run-teacher.R`.
- Confirm that attempts, scores, gradebook, Moodle CSV, bundle, and report are
  created in `LEARNRTRACKR_OUTPUT_DIR`.
- Set `LEARNRTRACKR_TEACHER_OPEN_DASHBOARD=true` only when opening the local
  dashboard is intended.

## Moodle import

- Inspect `course-pilot-moodle.csv` before import.
- Confirm that the exported identifier column matches Moodle user identifiers.
- Confirm that group filtering did not include learners from another group.
- Import first into a test activity or sandbox course when possible.

## PostgreSQL rehearsal

- Use `inst/examples/postgres-docker/env.example` as the template.
- Replace the placeholder PostgreSQL password.
- Use a dedicated test database or schema.
- Run `Rscript course-pilot-smoke-test.R`.
- Run `Rscript run-dashboard.R` only from a controlled local or protected
  environment.
