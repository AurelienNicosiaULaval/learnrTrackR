# Tracking strategy for the minimal learnr prototype

## Strategy retained

The prototype uses an explicit R-side call inside `gradethis::grade_this()`
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

This is the least fragile strategy for the first prototype because `grade_this()`
documents `.user_code` and `.result` as available objects in the checking
environment. The helper records the attempt and returns a `gradethis` graded
result for the learner.

## What is tracked

- Student identifier from `LEARNRTRACKR_STUDENT_ID`.
- Tutorial identifier.
- Question identifier.
- Submitted code from `.user_code`.
- Correct or incorrect status.
- Score and maximum score.
- Feedback message.
- Timestamp and attempt number from `learnrTrackR`.

## What is not tracked yet

- Multiple-choice submissions from `learnr::question()`.
- Browser events.
- Shiny session metadata.
- Authenticated student identity.
- `learnr` internal progress state.

## Next technical question

The next investigation should focus on whether multiple-choice questions can be
tracked through a public and stable `learnr` extension point. If not, the
package should keep code exercises as the first supported integration and defer
quiz widgets until a robust Shiny or JavaScript strategy is documented and
tested.
