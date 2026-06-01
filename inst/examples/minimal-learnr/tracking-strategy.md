# Tracking strategy for the minimal learnr prototype

## Strategy retained

The prototype uses two R-side strategies.

For `learnr` multiple-choice questions, it uses `tracked_question_radio()` or
`tracked_question_checkbox()`. These wrappers create normal `learnr` questions
and add a small custom S3 class. When `learnr::question_is_correct()` evaluates
the submitted value, `learnrTrackR` records the submission and then returns the
usual `learnr` result.

For code exercises, it uses an explicit call inside `gradethis::grade_this()`
check chunks:

```r
learnrTrackR::track_gradethis_attempt(
  con = con,
  student_id = student_id,
  tutorial_id = tutorial_id,
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

- Student identifier from `LEARNRTRACKR_STUDENT_ID`.
- Tutorial identifier.
- Question identifier.
- Submitted choices for tracked radio and checkbox questions.
- Submitted code from `.user_code` for tracked code exercises.
- Correct or incorrect status.
- Score and maximum score.
- Feedback message.
- Timestamp and attempt number from `learnrTrackR`.

## What is not tracked yet

- Free-text and numeric `learnr` questions.
- Browser events.
- Shiny session metadata.
- Authenticated student identity.
- `learnr` internal progress state.

## Next technical question

The next investigation should focus on extending the same question wrapper
pattern to free-text and numeric `learnr` questions, then deciding whether the
package should expose a single generic `tracked_question()` helper.
