# learnrTrackR 0.3.0

- Added citation and archival metadata for future scholarly software
  publication work.
- Added a publication preparation plan for a possible open-source education or
  research software submission.
- Added an initial Open Journals style paper draft in `paper/paper.md`.
- Added an instructor adoption vignette for external teachers.
- Added a controlled course pilot protocol checklist.
- Added a post-pilot record template for documenting pilot evidence,
  limitations, and privacy decisions.
- Added Canvas Gradebook CSV export helpers and a Canvas export vignette.

# learnrTrackR 0.2.0

- Added a course pilot example showing a realistic tracked `learnr` tutorial,
  CSV configuration, simulated learner results, Moodle export, and teacher
  report generation.
- Added group filtering to `moodle_grades()` and `export_moodle_grades()`.
- Added a controlled PostgreSQL pilot deployment smoke test and vignette.
- Added PostgreSQL-aware teacher dashboard launchers for open DBI connections
  and environment-variable based PostgreSQL settings.
- Added explicit course pilot student and teacher launch scripts.
- Added a course pilot single-file YAML configuration alongside the CSV
  configuration.
- Added a course pilot preflight checklist covering configuration, privacy,
  launch, exports, Moodle import, and dashboard access.

# learnrTrackR 0.1.1

- Added `setup_learnr_tracking()` and `open_learnr_tracking_db()` to simplify
  explicit `learnr` tutorial setup.
- Allowed tracked `learnr` questions and `track_gradethis_attempt()` to use a
  reusable tracking context.
- Added a vignette documenting the reusable `learnr` tracking context workflow.
- Added `get_learnr_tracking_env()` to validate tracked `learnr` launch
  environment variables together.

# learnrTrackR 0.1.0

- Added SQLite tracking database.
- Added functions for tracking simulated attempts.
- Added score computation.
- Added CSV export.
- Added a minimal `learnr` and `gradethis` prototype for tracked code
  exercises.
- Added tracked radio-button and checkbox `learnr` question helpers.
- Added tracked text and numeric `learnr` question helpers.
- Added `tracked_question()` as a generic helper for built-in `learnr` question
  types.
- Added `get_tracking_student_id()` for minimal environment-variable based
  student identification.
- Added expected-question registration and gradebook scoring with unanswered
  questions.
- Added Moodle-ready CSV grade export.
- Added a Moodle CSV export vignette.
- Added a minimal Shiny teacher dashboard.
- Added local dashboard launch safeguards and an optional dashboard token gate.
- Added student registration helpers and optional registered-student checks for
  attempts.
- Added student metadata display and registered-group filtering to the teacher
  dashboard and its CSV downloads.
- Added course and tutorial registration helpers.
- Added YAML and CSV tracking configuration loading.
- Added rich teacher export bundles filtered by group or student.
- Added a teacher workflow vignette and updated the minimal `learnr` example to
  use configuration and registered students.
- Added CSV and YAML tracking configuration template generation.
- Added optional PostgreSQL schema creation and connection support through
  `connect_postgres_tracking_db()`.
- Added a PostgreSQL deployment vignette and a local Docker Compose example.
- Added privacy utilities and a repository privacy guide for student data.
- Added pedagogical analytics helpers for question summaries, student
  summaries, difficult-question detection, and stalled-student detection.
- Added HTML teacher report generation.
- Added GitHub repository metadata and `gradethis` remote metadata for CI.

# learnrTrackR 0.0.1

- Initial package skeleton.
