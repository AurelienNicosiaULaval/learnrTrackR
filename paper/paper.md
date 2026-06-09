---
title: "learnrTrackR: Reproducible Tracking and Grade Export for learnr-Style Tutorials"
tags:
  - R
  - learnr
  - educational software
  - statistics education
  - learning analytics
  - reproducible teaching
authors:
  - name: "Aurélien Nicosia"
    affiliation: 1
affiliations:
  - name: "Université Laval"
    index: 1
date: 9 June 2026
bibliography: paper.bib
---

# Summary

`learnrTrackR` is an R package [@R] for tracking learner attempts in interactive
`learnr`-style tutorials. The package records submitted answers, grading
outcomes, attempt metadata, scores, and teacher-facing exports in a reproducible
database-backed workflow. It supports a local SQLite workflow for small pilots,
an optional PostgreSQL workflow for controlled deployment rehearsals, explicit
helpers for tracked `learnr` and `gradethis` activities, CSV exports for
teacher inspection, and gradebook-style exports for Moodle and Canvas.

The package is designed for instructors who want to evaluate whether interactive
R tutorials can be used as accountable teaching activities without committing to
a full learning management system integration. It does not replace `learnr`,
`gradethis`, Moodle, Canvas, Posit Connect, or institutional authentication.
Instead, it provides a small tracking layer that can be inspected, tested, and
adapted by teaching teams.

# Statement of need

Interactive R tutorials are useful in statistics and data science teaching, but
classroom use often requires more than immediate feedback. Instructors need to
know who submitted an answer, how many attempts were made, which grading result
was returned, how final scores were derived, and which records should be
exported to a course gradebook. `learnr` provides an interactive tutorial
framework [@learnr], and `gradethis` provides automated feedback for `learnr`
exercises [@gradethis]. `learnrTrackR` complements those tools by focusing on
tracking, scoring, export, and teacher review.

The package targets a practical gap between local teaching prototypes and
institutional systems. It keeps the data model simple enough for classroom
pilots while exposing the database and export files directly to the instructor.
This makes the workflow auditable and reproducible, and it avoids making
unsupported claims about authentication, privacy compliance, or learning gains.

# Design and functionality

The current pilot-ready release provides:

- SQLite storage for local pilots;
- optional PostgreSQL connection and schema creation through `DBI` [@DBI];
- explicit tracking of simulated attempts and `learnr` question helpers;
- score computation using first, last, or best attempt rules;
- gradebook summaries that include unanswered registered questions;
- CSV exports for attempts, scores, gradebooks, Moodle, Canvas, and teacher
  bundles;
- a minimal Shiny dashboard for local teacher inspection [@shiny];
- teacher-facing pedagogical summaries and HTML report generation;
- privacy utilities for deletion, anonymisation, and pseudonymisation;
- a realistic course pilot example with configuration files and preflight
  documentation.

SQLite storage is accessed from R through `RSQLite` [@RSQLite].

The workflow deliberately uses explicit calls rather than automatic
instrumentation of arbitrary tutorials. This makes the implementation easier to
audit and reduces the risk of silently changing tutorial behavior when upstream
packages evolve.

# Example workflow

A minimal teacher workflow is:

1. create or connect to a tracking database;
2. register course, tutorial, student, and question metadata;
3. launch a tracked tutorial or simulate attempts;
4. compute scores and gradebook rows;
5. inspect the dashboard or HTML report;
6. export CSV files for Moodle or Canvas only after identifier mapping has been
   verified.

The repository includes a course pilot example under
`inst/examples/course-pilot/`. The example uses simulated learner records and is
intended to rehearse the workflow before any real student data are collected.

# Quality control

The package includes unit tests for database creation, schema idempotence,
attempt tracking, scoring rules, metadata registration, exports, dashboards,
privacy helpers, and course-pilot workflows. The GitHub Actions configuration
runs `R CMD check` on Ubuntu, macOS, and Windows with R release, and a separate
workflow builds the pkgdown site.

# Limitations

`learnrTrackR` is not an institutional authentication layer and does not provide
role-based access control. Moodle and Canvas support is CSV-based; the package
does not use LMS APIs. The dashboard is intended for local or protected
inspection, not for open public deployment. The package also does not provide
evidence that interactive tutorials improve learning outcomes. Such claims
would require a separate research design, appropriate privacy or ethics review,
and reproducible analysis.

# Future work

Planned work includes running and documenting a controlled pilot, hardening
deployment guidance for managed Shiny or Posit Connect environments, adding
more operational checks for pilot data quality, and refining the API before a
future stable release. A later research article could evaluate teaching
outcomes, but the current paper should be read as a software and workflow
description.

# References
