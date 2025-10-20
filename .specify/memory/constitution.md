# [PROJECT_NAME] Constitution

<!-- Example: Spec Constitution, TaskFlow Constitution, etc. -->

## Core Principles

### [PRINCIPLE_1_NAME]

<!-- Example: I. Library-First -->

[PRINCIPLE_1_DESCRIPTION]

<!-- Example: Every feature starts as a standalone library; Libraries must be self-contained, independently testable, documented; Clear purpose required - no organizational-only libraries -->
<!--
Sync Impact Report

- Version change: unknown -> 1.0.0
- Modified principles: Added Code Quality; Testing Standards; User Experience Consistency; Performance & Scalability
- Added sections: Constraints & Standards; Development Workflow & Quality Gates
- Removed sections: none
- Templates updated: .specify/templates/plan-template.md ✅ updated
                     .specify/templates/spec-template.md (pending)
                     .specify/templates/tasks-template.md (pending)
                     .specify/templates/commands/*.md ⚠ pending (no files found)
- Follow-up TODOs: RATIFICATION_DATE is unknown and marked TODO(RATIFICATION_DATE)
- Assumptions: Project display name set to "Speckit" (inferred). If incorrect, update the H1 line.
- Report generated: 2025-10-16

-->

# Speckit Constitution

## Core Principles

### I. Code Quality (NON-NEGOTIABLE)

Code and architecture MUST be written for clarity, maintainability, and safe evolution.

- All code MUST pass automated linting and formatting checks before review (CI gate).
- Public APIs and modules MUST include clear documentation and examples; breaking changes MUST follow the versioning policy in Governance and include migration notes.
- Complexity limits: functions or classes that exceed agreed cyclomatic complexity or LOC thresholds MUST be refactored before merge or have an explicit justification recorded in the PR. Large design deviations require a documented architecture decision record (ADR).
- Static analysis and type checks (where applicable) MUST be enabled in CI.

Rationale: Enforcing consistent code quality reduces defects, eases onboarding, and lowers maintenance cost.

### II. Testing Standards (NON-NEGOTIABLE)

Testing is a first-class artifact of every change and MUST be used to express requirements, prevent regressions, and document behavior.

- Tests MUST be written prior to implementation for new behavior (TDD / red-green-refactor) or submitted alongside the initial PR implementing the change.
- Each user story or feature slice MUST include at least unit tests; for multi-component behavior, include integration/contract tests. End-to-end tests are required for user-facing flows where practical.
- CI MUST run the full test suite and fail the build on test failures. New flaky tests MUST be fixed or quarantined with an explicit remediation plan.
- Coverage: teams SHOULD track coverage metrics and investigate significant drops; numerical thresholds (e.g., 80%) are guidelines, not a substitute for thoughtful tests.

Rationale: Tests capture intent, enable safe refactoring, and form the primary mechanism for automated quality assurance.

### III. User Experience Consistency

User-facing behavior and messaging MUST be consistent, accessible, and predictable.

- Apply a shared design system or component guidelines for visual and interaction consistency. Visual or behavioral changes to components used across flows require a UX/design review and backwards-compatibility consideration.
- Accessibility targets: follow WCAG 2.1 AA for public-facing interfaces where applicable; include accessibility checks in the definition of done for UX work.
- Error messaging MUST be helpful, localizable, and actionable. UX acceptance criteria MUST include validation steps for core user journeys.

Rationale: Consistent UX reduces user confusion, support load, and increases product trust.

### IV. Performance & Scalability Requirements

Performance expectations MUST be explicit, measurable, and validated during development and CI where feasible.

- Define performance goals in feature plans (e.g., latency p95/p99, throughput, memory budgets). Performance budgets MUST be included for features that affect critical paths.
- New work that affects runtime performance MUST include benchmarks or load tests that demonstrate compliance with stated goals before merging.
- Prevent regressions: CI or pre-merge checks SHOULD run lightweight benchmarks or smoke profiling for critical components. Significant regressions MUST be blocked or accompanied by a mitigation plan.

Rationale: Explicit performance requirements protect user experience and platform costs as the project scales.

<!--
Sync Impact Report

- Version change: unknown -> 1.0.0
- Modified principles: Added Code Quality; Testing Standards; User Experience Consistency; Performance & Scalability
- Added sections: Constraints & Standards; Development Workflow & Quality Gates
- Removed sections: none
- Templates updated: .specify/templates/plan-template.md ✅ updated
                     .specify/templates/spec-template.md (pending)
                     .specify/templates/tasks-template.md (pending)
                     .specify/templates/commands/*.md ⚠ pending (no files found)
- Follow-up TODOs: RATIFICATION_DATE is unknown and marked TODO(RATIFICATION_DATE)
- Assumptions: Project display name set to "Speckit" (inferred). If incorrect, update the H1 line.
- Report generated: 2025-10-16

-->

# Speckit Constitution

## Core Principles

### I. Code Quality (NON-NEGOTIABLE)

Code and architecture MUST be written for clarity, maintainability, and safe evolution.

- All code MUST pass automated linting and formatting checks before review (CI gate).
- Public APIs and modules MUST include clear documentation and examples; breaking changes MUST follow the versioning policy in Governance and include migration notes.
- Complexity limits: functions or classes that exceed agreed cyclomatic complexity or LOC thresholds MUST be refactored before merge or have an explicit justification recorded in the PR. Large design deviations require a documented architecture decision record (ADR).
- Static analysis and type checks (where applicable) MUST be enabled in CI.

Rationale: Enforcing consistent code quality reduces defects, eases onboarding, and lowers maintenance cost.

### II. Testing Standards (NON-NEGOTIABLE)

Testing is a first-class artifact of every change and MUST be used to express requirements, prevent regressions, and document behavior.

- Tests MUST be written prior to implementation for new behavior (TDD / red-green-refactor) or submitted alongside the initial PR implementing the change.
- Each user story or feature slice MUST include at least unit tests; for multi-component behavior, include integration/contract tests. End-to-end tests are required for user-facing flows where practical.
- CI MUST run the full test suite and fail the build on test failures. New flaky tests MUST be fixed or quarantined with an explicit remediation plan.
- Coverage: teams SHOULD track coverage metrics and investigate significant drops; numerical thresholds (e.g., 80%) are guidelines, not a substitute for thoughtful tests.

Rationale: Tests capture intent, enable safe refactoring, and form the primary mechanism for automated quality assurance.

### III. User Experience Consistency

User-facing behavior and messaging MUST be consistent, accessible, and predictable.

- Apply a shared design system or component guidelines for visual and interaction consistency. Visual or behavioral changes to components used across flows require a UX/design review and backwards-compatibility consideration.
- Accessibility targets: follow WCAG 2.1 AA for public-facing interfaces where applicable; include accessibility checks in the definition of done for UX work.
- Error messaging MUST be helpful, localizable, and actionable. UX acceptance criteria MUST include validation steps for core user journeys.

Rationale: Consistent UX reduces user confusion, support load, and increases product trust.

### IV. Performance & Scalability Requirements

Performance expectations MUST be explicit, measurable, and validated during development and CI where feasible.

- Define performance goals in feature plans (e.g., latency p95/p99, throughput, memory budgets). Performance budgets MUST be included for features that affect critical paths.
- New work that affects runtime performance MUST include benchmarks or load tests that demonstrate compliance with stated goals before merging.
- Prevent regressions: CI or pre-merge checks SHOULD run lightweight benchmarks or smoke profiling for critical components. Significant regressions MUST be blocked or accompanied by a mitigation plan.

Rationale: Explicit performance requirements protect user experience and platform costs as the project scales.

<!--
Sync Impact Report

- Version change: unknown -> 1.0.0
- Modified principles: Added Code Quality; Testing Standards; User Experience Consistency; Performance & Scalability
- Added sections: Constraints & Standards; Development Workflow & Quality Gates
- Removed sections: none
- Templates updated: .specify/templates/plan-template.md ✅ updated
                     .specify/templates/spec-template.md (pending)
                     .specify/templates/tasks-template.md (pending)
                     .specify/templates/commands/*.md ⚠ pending (no files found)
- Follow-up TODOs: RATIFICATION_DATE is unknown and marked TODO(RATIFICATION_DATE)
- Assumptions: Project display name set to "Speckit" (inferred). If incorrect, update the H1 line.
- Report generated: 2025-10-16

-->

# Speckit Constitution

## Core Principles

### I. Code Quality (NON-NEGOTIABLE)

Code and architecture MUST be written for clarity, maintainability, and safe evolution.

- All code MUST pass automated linting and formatting checks before review (CI gate).
- Public APIs and modules MUST include clear documentation and examples; breaking changes MUST follow the versioning policy in Governance and include migration notes.
- Complexity limits: functions or classes that exceed agreed cyclomatic complexity or LOC thresholds MUST be refactored before merge or have an explicit justification recorded in the PR. Large design deviations require a documented architecture decision record (ADR).
- Static analysis and type checks (where applicable) MUST be enabled in CI.

Rationale: Enforcing consistent code quality reduces defects, eases onboarding, and lowers maintenance cost.

### II. Testing Standards (NON-NEGOTIABLE)

Testing is a first-class artifact of every change and MUST be used to express requirements, prevent regressions, and document behavior.

- Tests MUST be written prior to implementation for new behavior (TDD / red-green-refactor) or submitted alongside the initial PR implementing the change.
- Each user story or feature slice MUST include at least unit tests; for multi-component behavior, include integration/contract tests. End-to-end tests are required for user-facing flows where practical.
- CI MUST run the full test suite and fail the build on test failures. New flaky tests MUST be fixed or quarantined with an explicit remediation plan.
- Coverage: teams SHOULD track coverage metrics and investigate significant drops; numerical thresholds (e.g., 80%) are guidelines, not a substitute for thoughtful tests.

Rationale: Tests capture intent, enable safe refactoring, and form the primary mechanism for automated quality assurance.

### III. User Experience Consistency

User-facing behavior and messaging MUST be consistent, accessible, and predictable.

- Apply a shared design system or component guidelines for visual and interaction consistency. Visual or behavioral changes to components used across flows require a UX/design review and backwards-compatibility consideration.
- Accessibility targets: follow WCAG 2.1 AA for public-facing interfaces where applicable; include accessibility checks in the definition of done for UX work.
- Error messaging MUST be helpful, localizable, and actionable. UX acceptance criteria MUST include validation steps for core user journeys.

Rationale: Consistent UX reduces user confusion, support load, and increases product trust.

### IV. Performance & Scalability Requirements

Performance expectations MUST be explicit, measurable, and validated during development and CI where feasible.

- Define performance goals in feature plans (e.g., latency p95/p99, throughput, memory budgets). Performance budgets MUST be included for features that affect critical paths.
- New work that affects runtime performance MUST include benchmarks or load tests that demonstrate compliance with stated goals before merging.
- Prevent regressions: CI or pre-merge checks SHOULD run lightweight benchmarks or smoke profiling for critical components. Significant regressions MUST be blocked or accompanied by a mitigation plan.

Rationale: Explicit performance requirements protect user experience and platform costs as the project scales.

<!--
Sync Impact Report

- Version change: unknown -> 1.0.0
- Modified principles: Added Code Quality; Testing Standards; User Experience Consistency; Performance & Scalability
- Added sections: Constraints & Standards; Development Workflow & Quality Gates
- Removed sections: none
- Templates updated: .specify/templates/plan-template.md ✅ updated
                     .specify/templates/spec-template.md (pending)
                     .specify/templates/tasks-template.md (pending)
                     .specify/templates/commands/*.md ⚠ pending (no files found)
- Follow-up TODOs: RATIFICATION_DATE is unknown and marked TODO(RATIFICATION_DATE)
- Assumptions: Project display name set to "Speckit" (inferred). If incorrect, update the H1 line.
- Report generated: 2025-10-16

-->

<!--
Sync Impact Report

- Version change: unknown -> 1.0.0
- Modified principles: Added Code Quality; Testing Standards; User Experience Consistency; Performance & Scalability
- Added sections: Constraints & Standards; Development Workflow & Quality Gates
- Removed sections: none
- Templates updated: .specify/templates/plan-template.md ✅ updated
                     .specify/templates/spec-template.md (pending)
                     .specify/templates/tasks-template.md (pending)
                     .specify/templates/commands/*.md ⚠ pending (no files found)
- Follow-up TODOs: RATIFICATION_DATE is unknown and marked TODO(RATIFICATION_DATE)
- Assumptions: Project display name set to "Speckit" (inferred). If incorrect, update the H1 line.
- Report generated: 2025-10-16

-->

# Speckit Constitution

## Core Principles

### I. Code Quality (NON-NEGOTIABLE)

Code and architecture MUST be written for clarity, maintainability, and safe evolution.

- All code MUST pass automated linting and formatting checks before review (CI gate).
- Public APIs and modules MUST include clear documentation and examples; breaking changes MUST follow the versioning policy in Governance and include migration notes.
- Complexity limits: functions or classes that exceed agreed cyclomatic complexity or LOC thresholds MUST be refactored before merge or have an explicit justification recorded in the PR. Large design deviations require a documented architecture decision record (ADR).
- Static analysis and type checks (where applicable) MUST be enabled in CI.

Rationale: Enforcing consistent code quality reduces defects, eases onboarding, and lowers maintenance cost.

### II. Testing Standards (NON-NEGOTIABLE)

Testing is a first-class artifact of every change and MUST be used to express requirements, prevent regressions, and document behavior.

- Tests MUST be written prior to implementation for new behavior (TDD / red-green-refactor) or submitted alongside the initial PR implementing the change.
- Each user story or feature slice MUST include at least unit tests; for multi-component behavior, include integration/contract tests. End-to-end tests are required for user-facing flows where practical.
- CI MUST run the full test suite and fail the build on test failures. New flaky tests MUST be fixed or quarantined with an explicit remediation plan.
- Coverage: teams SHOULD track coverage metrics and investigate significant drops; numerical thresholds (e.g., 80%) are guidelines, not a substitute for thoughtful tests.

Rationale: Tests capture intent, enable safe refactoring, and form the primary mechanism for automated quality assurance.

### III. User Experience Consistency

User-facing behavior and messaging MUST be consistent, accessible, and predictable.

- Apply a shared design system or component guidelines for visual and interaction consistency. Visual or behavioral changes to components used across flows require a UX/design review and backwards-compatibility consideration.
- Accessibility targets: follow WCAG 2.1 AA for public-facing interfaces where applicable; include accessibility checks in the definition of done for UX work.
- Error messaging MUST be helpful, localizable, and actionable. UX acceptance criteria MUST include validation steps for core user journeys.

Rationale: Consistent UX reduces user confusion, support load, and increases product trust.

### IV. Performance & Scalability Requirements

Performance expectations MUST be explicit, measurable, and validated during development and CI where feasible.

- Define performance goals in feature plans (e.g., latency p95/p99, throughput, memory budgets). Performance budgets MUST be included for features that affect critical paths.
- New work that affects runtime performance MUST include benchmarks or load tests that demonstrate compliance with stated goals before merging.
- Prevent regressions: CI or pre-merge checks SHOULD run lightweight benchmarks or smoke profiling for critical components. Significant regressions MUST be blocked or accompanied by a mitigation plan.

Rationale: Explicit performance requirements protect user experience and platform costs as the project scales.

## Constraints & Standards

This section captures cross-cutting constraints that implement the principles above.

- Technology choices SHOULD be justified in the implementation plan; legacy or constrained environments MUST be documented with tradeoffs.
- Security and privacy requirements MUST follow the project's compliance guidance and be considered early in the plan; sensitive data handling MUST be explicit.

## Development Workflow & Quality Gates

- All PRs for code changes MUST include a short checklist: lint, unit tests, CI pass, changelog entry (if user-visible), and documentation updates as needed.
- Significant changes (API, UX, architecture) MUST include a Plan/ADR and a sign-off from at least one maintainer and, for UX, a designer where available.
- The `/speckit.plan` output MUST include a "Constitution Check" section which lists how the plan satisfies the principles (quality, testing, UX, performance) and links to evidence (tests, benchmarks, ADRs).

## Governance

### Amendments

- Proposals to amend the constitution MUST be opened as a documented proposal in the repository (pull request against `.specify/memory/constitution.md`).
- Non-substantive edits (typos, clarifications) are PATCH bumps. Adding new principles or changing obligations is a MINOR bump. Removing or redefining principles in an incompatible way is a MAJOR bump and requires broader stakeholder agreement.

### Decision & Review

- Changes to governance MUST include rationale, a migration plan for affected artifacts, and automated checks where applicable. A proposal requires approval from the project maintainers (or a documented quorum) before merging.

### Versioning Policy

- Versioning follows semantic versioning semantics for this constitution file: MAJOR.MINOR.PATCH with the meanings documented above.

### Compliance & Enforcement

- Automated checks (linters, test runs, basic performance smoke tests) are the first line of enforcement. PRs that do not meet mandatory gates MUST not be merged.
- Periodic compliance reviews (at least quarterly) SHOULD be scheduled to validate that practices are followed and to surface technical debt.

**Version**: 1.0.0 | **Ratified**: TODO(RATIFICATION_DATE) | **Last Amended**: 2025-10-16

<!-- End of constitution -->
