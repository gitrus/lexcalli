# The way

How we develop and ship Lexcalli. This is a lightweight working agreement for a small, AI-assisted product, not an enterprise SDLC template.

Product decisions live in [product](product.md), [data layering](data-layering.md), and [learning engine](learning-engine.md). This document describes **how we work**. Changes to these documents are committed alongside the decisions they capture; Git history is our decision log. No separate ADR process.

## Principles

- **Ship vertical slices.** Prefer one usable end-to-end behavior over completing a whole architectural layer.
- **Prove behavior, not activity.** Generated code, successful compilation, and a green CI job are not evidence of a working feature by themselves.
- **Keep the core testable without SwiftUI.** Learning, scheduling, import/export, and persistence must not depend on UI interaction to be verified.
- **Keep the workflow cheaper than the work.** No sprint ceremony, mandatory ticket for every edit, permanent agent swarm, or framework chosen for hypothetical scale.
- **Use native tools first.** SwiftUI, Swift Testing, XCTest where needed, Xcode tooling, and existing [agent instructions](../.agents/AGENTS.md). Add infrastructure only when it solves an observed problem.
- **Preserve learner data.** Silent corruption of notes, media, scheduling, or review history is a release-blocking defect.

## From idea to merged change

1. **Define the slice.** State the user-visible result, relevant boundaries, and a few observable acceptance criteria. Record open product questions before implementing assumptions. Use GitHub Issues for work worth tracking, not every trivial edit.
2. **Implement.** An agent or developer changes the smallest coherent surface, including tests and fixtures. Keep business logic isolated from presentation. Do not introduce a new abstraction without a current use case.
3. **Verify locally.** Build with Xcode; run relevant unit/integration tests; exercise changed screens in the simulator. Inspect actual behavior, screenshots, navigation, empty states, and errors where applicable. Report what ran and what could not run.
4. **Review independently.** For meaningful changes, use a separate review pass (another agent or developer) focused on correctness, missed cases, unnecessary complexity, and compatibility. The author addresses findings; review output is not an automatic approval.
5. **Merge a coherent change.** Confirm acceptance criteria and risk-appropriate verification. Prefer small diffs and useful commit messages. A PR is useful for substantial/agent-authored changes; do not require one for every documentation fix.

An agent may implement and test, but **human judgment owns scope, architectural tradeoffs, and release acceptance**. Parallel agents are optional and justified by independent work, not agent count.

## Verification strategy

Use the cheapest trustworthy feedback first:

- **Unit tests:** exercise validation, knowledge attribution, review transitions, FSRS-related policy, and other deterministic domain logic.
- **Integration/fixture tests:** real Anki imports, media references, compatible export/round-trip behavior, persistence, and schema migrations.
- **UI tests and simulator checks:** critical learning flows, typed input (including Greek accents), navigation, accessibility-sensitive interactions, and recovery from failed operations.
- **Device checks:** important interaction, audio, lifecycle, and storage behavior before wider distribution. Simulator success alone is insufficient.

CI should build and run relevant tests, **fail if expected tests were not actually executed**, and report results. Add expensive checks when the defect risk warrants them rather than running every possible test on every edit.

### Non-negotiable data invariants

- An exercise referencing multiple cards must not silently award knowledge or review credit to context/distractor cards.
- Exercise attempts and Anki-compatible review events are distinct; only explicitly designated reviews affect scheduling.
- Import/export must not silently discard supported card content, media, identifiers needed for compatibility, or review history.
- Interruptions, app restarts, upgrades, and retries must not silently duplicate or erase learning progress.
- Backend-supplied exercise definitions must respect explicit client capabilities and versioned contracts once that interface exists.

These requirements are specified in more detail by the product and learning-engine documents. Add regression fixtures when a bug reveals a missing invariant.

## Delivery and release

- **Development loop:** merge small verified slices continuously.
- **Internal distribution:** create TestFlight builds at useful milestones and after changes needing real-device feedback—not necessarily for every commit.
- **Release gate:** validate core review/import flows, migrations, data preservation, and relevant device behavior; inspect known issues; approve release manually.
- **App Store:** publishing is a separate deliberate step, including signing, privacy disclosures, metadata, and store review. Do not treat a merged PR as a production release.
- **Feedback:** turn observed user problems and release defects into the next small slices. Prefer fixing the loop to adding more process.

## First milestone

A device-installable build that can import a small Anki deck with media, study a card, record a scheduled review, and preserve history after relaunch. This is a **target**, not a claim that the build, CI, or TestFlight configuration already exists.

## Deferred decisions

- CI provider and macOS runner strategy (Xcode Cloud is a candidate, not a commitment).
- Exact branching/PR protection and release-versioning rules.
- TestFlight cadence and automated deployment/signing.
- How backend contracts and synchronization are tested once implemented.
- Whether additional agent roles or orchestration produce measurable value.

Revisit these when implementation creates a concrete need. Do not let tool selection block the first functioning slice.
