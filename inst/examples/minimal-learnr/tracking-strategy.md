# Tracking strategy for the minimal learnr prototype

## Strategy retained

The prototype uses two R-side strategies.

The setup chunk first reads and validates the launch environment:

```r
tracking_env <- learnrTrackR::get_learnr_tracking_env(
  default_db_path = file.path(tempdir(), "learnrtrackr-minimal.sqlite"),
  default_group_id = "demo_group"
)
```

It then creates a reusable tracking context:

```r
tracking <- learnrTrackR::setup_learnr_tracking(
  tutorial_id = tutorial_id,
  student_id = tracking_env$student_id,
  db_path = tracking_env$db_path,
  group_id = tracking_env$group_id,
  config_path = tracking_config_path
)
```

For `learnr` questions, it uses `tracked_question()`, which dispatches to
`tracked_question_radio()`, `tracked_question_checkbox()`,
`tracked_question_text()`, or `tracked_question_numeric()`. These helpers create
normal `learnr` questions and add a small custom S3 class. When
`learnr::question_is_correct()` evaluates the submitted value, `learnrTrackR`
records the submission and then returns the usual `learnr` result.

For code exercises, it uses an explicit call inside `gradethis::grade_this()`
check chunks:

```r
learnrTrackR::track_gradethis_attempt(
  context = tracking,
  question_id = "q2_mean_temperature",
  submitted_answer = .user_code,
  correct = correct,
  feedback = feedback,
  max_score = 1
)
```

This is a low-fragility first strategy because it uses public R-side extension
points documented by the installed packages: `learnr::question_is_correct()`
for questions, and `.user_code` plus `.result` inside `gradethis::grade_this()`
for code exercises. The helpers record attempts and return the usual `learnr`
or `gradethis` result for the learner.

## What is tracked

- Student identifier from `LEARNRTRACKR_STUDENT_ID`, read with
  `get_tracking_student_id()`.
- Tutorial identifier.
- Question identifier.
- Submitted values for tracked radio, checkbox, text, and numeric questions.
- Submitted code from `.user_code` for tracked code exercises.
- Correct or incorrect status.
- Score and maximum score.
- Feedback message.
- Timestamp and attempt number from `learnrTrackR`.

## What is not tracked yet

- Custom `learnr` question types outside the four built-in wrappers.
- Browser events.
- Shiny session metadata.
- Authenticated student identity.
- `learnr` internal progress state.

## Next technical question

The next investigation should focus on whether student identifiers should be
provided only through environment variables or collected through an explicit
tutorial launch workflow.
