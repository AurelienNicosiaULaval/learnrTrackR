# learnrTrackR 0.0.1

- Initial package skeleton.
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
