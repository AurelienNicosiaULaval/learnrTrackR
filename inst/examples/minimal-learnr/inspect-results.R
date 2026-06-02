library(learnrTrackR)

db_path <- Sys.getenv(
  "LEARNRTRACKR_DB",
  unset = file.path(tempdir(), "learnrtrackr-minimal.sqlite")
)

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
scores <- compute_scores(con, tutorial_id = "minimal_learnr", rule = "last")
grades <- gradebook(con, tutorial_id = "minimal_learnr", rule = "last")

print(attempts)
print(scores)
print(grades)

attempts_path <- file.path(dirname(db_path), "minimal-learnr-attempts.csv")
scores_path <- file.path(dirname(db_path), "minimal-learnr-scores.csv")
gradebook_path <- file.path(dirname(db_path), "minimal-learnr-gradebook.csv")

export_results(con, attempts_path, type = "attempts")
export_results(con, scores_path, type = "scores", tutorial_id = "minimal_learnr")
export_results(con, gradebook_path, type = "gradebook", tutorial_id = "minimal_learnr")

message("Wrote attempts to: ", attempts_path)
message("Wrote scores to: ", scores_path)
message("Wrote gradebook to: ", gradebook_path)
