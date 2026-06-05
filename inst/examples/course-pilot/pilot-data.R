pilot_survey <- tibble::tibble(
  learner_case = paste0("case_", sprintf("%02d", 1:12)),
  region = c(
    "Quebec City", "Quebec City", "Quebec City", "Quebec City",
    "Montreal", "Montreal", "Montreal", "Montreal",
    "Sherbrooke", "Sherbrooke", "Sherbrooke", "Sherbrooke"
  ),
  program = c(
    "Statistics", "Data science", "Statistics", "Mathematics",
    "Data science", "Statistics", "Mathematics", "Data science",
    "Statistics", "Mathematics", "Data science", "Statistics"
  ),
  study_hours = c(6.5, 7.0, 5.5, 8.0, 4.0, 5.0, 6.0, 5.5, 7.5, 8.5, 6.5, 7.0),
  commute_minutes = c(20, 15, 25, 30, 45, 35, 50, 40, 25, 20, 30, 35),
  quiz_score = c(78, 82, 74, 88, 70, 73, 76, 79, 85, 90, 81, 84)
)
