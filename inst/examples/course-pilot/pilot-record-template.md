# Course Pilot Record Template

Use this template after a controlled pilot. Keep the completed record outside
Git if it contains dates, identifiers, free-text notes, screenshots, exports,
or other information that could identify learners.

This record is for technical and workflow evidence. It is not, by itself, an
evaluation of learning gains.

## Administrative context

```text
pilot_date:
course_id:
course_label:
tutorial_id:
tutorial_version:
instructor:
technical_operator:
data_steward:
package_version:
git_commit:
database_backend:
deployment_context:
```

## Privacy and data decisions

```text
student_identifier_used:
direct_identifiers_collected:
group_identifier_used:
access_restrictions:
output_storage_location:
retention_period:
deletion_plan:
ethics_or_privacy_review_checked:
ethics_or_privacy_review_notes:
```

## Configuration evidence

```text
configuration_source:
number_configured_learners:
number_configured_groups:
number_expected_questions:
scoring_rule:
moodle_export_used:
canvas_export_used:
group_filter_used:
```

Attach or archive separately:

- the course configuration files used for the pilot;
- the tutorial version used for the pilot;
- a copy of the package version or release tag;
- the command used to launch the learner workflow;
- the command used to generate teacher outputs.

Do not attach identifiable exports to a public repository.

## Technical results

```text
number_participating_learners:
number_learners_with_recorded_attempts:
number_recorded_attempts:
number_gradebook_rows:
moodle_export_rows:
canvas_export_rows:
dashboard_used:
teacher_report_generated:
bundle_generated:
```

## Checks completed

- [ ] At least one attempt was recorded for every participating learner who
      submitted an answer.
- [ ] Attempt numbers increased correctly for repeated submissions.
- [ ] Every expected assessed question appeared in the gradebook.
- [ ] Unanswered registered questions were represented in the gradebook.
- [ ] Group-filtered exports excluded learners from other groups.
- [ ] Moodle export rows matched the intended cohort.
- [ ] Canvas export rows matched the intended cohort.
- [ ] The teacher report was generated from the same database and
      configuration.
- [ ] The teacher could reproduce exports from the recorded commands.

## Issues observed

```text
launch_issues:
tracking_issues:
database_issues:
dashboard_issues:
export_issues:
documentation_issues:
student_experience_notes:
teacher_experience_notes:
```

## Evidence boundaries

Record only descriptive evidence unless a separate evaluation design has been
approved.

Acceptable descriptive evidence:

- package version and Git commit;
- aggregate learner and attempt counts;
- list of technical issues;
- teacher notes about workflow clarity;
- anonymised or pseudonymised summaries when permitted.

Claims that require a separate evaluation design:

- learning gains;
- improved retention;
- reduced grading workload at scale;
- better engagement;
- superiority over another teaching method.

## Next actions

```text
fixes_needed_before_next_pilot:
documentation_updates_needed:
deployment_updates_needed:
privacy_updates_needed:
research_design_questions:
release_decision:
```

