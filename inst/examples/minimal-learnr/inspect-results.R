library(learnrTrackR)

db_path <- Sys.getenv(
  "LEARNRTRACKR_DB",
  unset = file.path(tempdir(), "learnrtrackr-minimal.sqlite")
)
group_id <- Sys.getenv("LEARNRTRACKR_GROUP_ID", unset = "")
group_filter <- if (nzchar(group_id)) group_id else NULL

if (!file.exists(db_path)) {
  stop(
    "No tracking database was found at: ",
    db_path,
    "\nRun the tutorial and submit at least one tracked code exercise first.",
    call. = FALSE
  )
}

con <- connect_tracking_db(db_path)
on.exit(DBI::dbDisconnect(con), add = TRUE)

attempts <- get_attempts(con)
students <- get_students(con)
scores <- compute_scores(con, tutorial_id = "minimal_learnr", rule = "last")
grades <- gradebook(con, tutorial_id = "minimal_learnr", rule = "last")
dashboard <- dashboard_data(
  con,
  tutorial_id = "minimal_learnr",
  group_id = group_filter,
  rule = "last"
)

print(students)
print(attempts)
print(scores)
print(grades)
print(dashboard$summary)

attempts_path <- file.path(dirname(db_path), "minimal-learnr-attempts.csv")
scores_path <- file.path(dirname(db_path), "minimal-learnr-scores.csv")
gradebook_path <- file.path(dirname(db_path), "minimal-learnr-gradebook.csv")
moodle_path <- file.path(dirname(db_path), "minimal-learnr-moodle.csv")
bundle_dir <- file.path(dirname(db_path), "minimal-learnr-export-bundle")

export_results(con, attempts_path, type = "attempts")
export_results(con, scores_path, type = "scores", tutorial_id = "minimal_learnr")
export_results(con, gradebook_path, type = "gradebook", tutorial_id = "minimal_learnr")
export_moodle_grades(
  con,
  moodle_path,
  tutorial_id = "minimal_learnr",
  grade_item = "Minimal learnr tutorial"
)
bundle_paths <- export_tracking_bundle(
  con,
  bundle_dir,
  tutorial_id = "minimal_learnr",
  group_id = group_filter
)

message("Wrote attempts to: ", attempts_path)
message("Wrote scores to: ", scores_path)
message("Wrote gradebook to: ", gradebook_path)
message("Wrote Moodle-ready grades to: ", moodle_path)
message("Wrote rich export bundle to: ", bundle_dir)
print(bundle_paths)
