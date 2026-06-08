# Publication Preparation Plan

This document tracks work needed before a possible journal submission. It is a
planning document, not a claim that the package is already accepted or ready
for peer review.

## Current status

`learnrTrackR` has a released `0.2.0` pilot kit and a development version
`0.2.0.9000`. It includes SQLite tracking, optional PostgreSQL deployment
rehearsal, tracked `learnr` examples, teacher exports, Moodle-ready CSV files,
dashboard launchers, privacy utilities, and a realistic course pilot example.

The package is not yet supported by an empirical teaching evaluation. It should
therefore be presented first as educational software or research software, not
as evidence that a teaching intervention improves learning outcomes.

## Candidate outlets

The most natural first target is the Journal of Open Source Education (JOSE),
because it publishes open-source educational materials and software. The
official JOSE scope should be checked before submission:

https://jose.theoj.org/about

The Journal of Open Source Software (JOSS) is also plausible if the submission
is framed as research software and if the package is mature enough for external
use:

https://joss.theoj.org/

The R Journal is a later-stage possibility if the package reaches a stronger R
package maturity level, ideally including CRAN or Bioconductor availability and
an article that goes beyond an ordinary vignette:

https://journal.r-project.org/

## Submission readiness checklist

- [x] Add citation metadata in `CITATION.cff`.
- [x] Add R citation metadata in `inst/CITATION`.
- [x] Add preliminary Zenodo metadata in `.zenodo.json`.
- [x] Add an instructor adoption vignette for external teachers.
- [x] Add a controlled pilot protocol in
  `inst/examples/course-pilot/pilot-protocol.md`.
- [ ] Archive a tagged release with Zenodo after enabling the GitHub
  integration.
- [ ] Add the resulting DOI to `CITATION.cff`, `.zenodo.json`, `README.md`, and
  `inst/CITATION`.
- [ ] Run a small controlled pilot with a real or semi-real tutorial section.
- [ ] Record the pilot protocol, privacy decisions, deployment context, and
  known limitations after the pilot.
- [ ] Prepare a short paper with problem statement, design goals, package
  architecture, example workflow, reproducibility notes, limitations, and
  future work.
- [ ] Keep all claims descriptive unless they are supported by collected data
  and an appropriate evaluation design.

## Next publication increment

The next useful publication-oriented increment is a first `paper.md` draft in
Open Journals style. It should describe the software and adoption workflow
without claiming learning gains.

## Evidence to avoid claiming without data

- Learning gains.
- Improved retention.
- Reduced grading workload at scale.
- Better student engagement.
- Institutional deployment readiness.

These could become research claims only after a documented study, appropriate
ethics review when required, and reproducible analysis.
