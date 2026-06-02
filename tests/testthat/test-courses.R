test_that("register_courses stores metadata and upserts rows", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_courses(
    con,
    data.frame(
      course_id = "stat101",
      course_label = "Statistics 101",
      semester = "W2026"
    )
  )
  register_courses(
    con,
    data.frame(
      course_id = "stat101",
      course_label = "Statistics I",
      semester = NA_character_
    )
  )

  courses <- get_courses(con, course_id = "stat101")

  expect_equal(nrow(courses), 1)
  expect_equal(courses$course_label, "Statistics I")
  expect_equal(courses$semester, "W2026")
})

test_that("register_tutorials stores metadata and filters by course", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_tutorials(
    con,
    data.frame(
      tutorial_id = c("module_01", "module_02"),
      tutorial_label = c("Module 1", "Module 2")
    ),
    course_id = "stat101"
  )
  register_tutorials(
    con,
    data.frame(
      tutorial_id = "module_02",
      course_id = "stat102",
      tutorial_label = "Module 2 revised",
      version = "0.0.2"
    )
  )

  tutorials <- get_tutorials(con)

  expect_equal(nrow(tutorials), 2)
  expect_equal(nrow(get_tutorials(con, course_id = "stat101")), 1)
  expect_equal(get_tutorials(con, tutorial_id = "module_02")$course_id, "stat102")
  expect_equal(get_tutorials(con, tutorial_id = "module_02")$version, "0.0.2")
})
