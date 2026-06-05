# Tracking strategy for the course pilot

The pilot uses explicit tracking. It does not intercept internal `learnr`
browser events, and it does not modify `learnr` or `gradethis`.

## Launch context

The setup chunk reads:

- `LEARNRTRACKR_STUDENT_ID`;
- `LEARNRTRACKR_GROUP_ID`;
- `LEARNRTRACKR_DB`.

It then creates a reusable context with:

```r
learnrTrackR::setup_learnr_tracking()
```

The context stores the tutorial identifier, learner identifier, group, database
path, and configuration path.

## Built-in learnr questions

Radio, checkbox, text, and numeric questions use:

```r
learnrTrackR::tracked_question()
```

Each question receives a stable `question_id` that matches
`config-csv/questions.csv`.

## Code exercises

Code exercise check chunks use:

```r
learnrTrackR::track_gradethis_attempt()
```

The helper is called inside `gradethis::grade_this()` and records the submitted
code, grading status, score, maximum score, and feedback.

## Teacher workflow

The teacher workflow uses the same database to produce:

- attempts;
- scores;
- gradebook rows;
- Moodle-ready grades;
- export bundles;
- dashboard data;
- a teacher report.

The database created by the example is suitable for local testing and small
pilots only. A real course pilot should use a controlled deployment plan,
documented retention rules, and an approved student identification strategy.
