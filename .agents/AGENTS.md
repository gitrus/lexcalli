# iOS engineering guide

Build Lexcalli as a native SwiftUI application. Prefer simple, testable platform-native patterns over additional architectural frameworks.

## Skills

Use these two skills when available locally:

- **SwiftUI Expert** — `.agents/skills/swiftui-expert-skill/SKILL.md`; upstream: https://github.com/AvdLee/SwiftUI-Agent-Skill. Consult for views, Observation, state, navigation, accessibility, and UI performance.
- **Swift Concurrency** — `.agents/skills/swift-concurrency/SKILL.md`; upstream: https://github.com/AvdLee/Swift-Concurrency-Agent-Skill. Consult for async/await, actor isolation, Sendable, task lifecycle, cancellation, and concurrency diagnostics.

```sh
npx skills add AvdLee/SwiftUI-Agent-Skill

npx skills add AvdLee/Swift-Concurrency-Agent-Skill
```

The upstream links are installation sources, not substitutes for local files. If skills have not been installed, consult upstream guidance explicitly rather than claiming to have read local files.

## Project layout

- `Lexcalli.xcodeproj` — iOS app project. The `Lexcalli/` folder is a synchronized group: files added on disk are picked up by Xcode without editing the project file.
- `Lexcalli/` — SwiftUI app target (views and app entry point only). Default actor isolation is `MainActor`; Swift 6 language mode; deployment target iOS 26.
- `LexcalliCore/` — local Swift package with the UI-independent learning and content model. Not main-actor isolated; tested with Swift Testing via `just test`, no simulator needed.
- Scheduling uses [swift-fsrs](https://github.com/open-spaced-repetition/swift-fsrs) pinned to a commit on `main` (FSRS-6; the latest tag is FSRS-5). Pass FSRS-6 weights explicitly — the library defaults to FSRS-5. Use `just fsrs-upstream` to check for a tagged release.

## Commands

Run `just` to list recipes. Before handing off a change run `just check` (lint, core tests, app build). The app build and `just run` need Xcode selected via `xcode-select`; with Command Line Tools only, `just check` fails at the app build step on purpose.

## Engineering decisions

- Prefer current Apple APIs compatible with the project's actual deployment target; verify availability before use.
- Use Apple Developer documentation as the primary API authority. For a deeper understanding of SwiftUI behavior, consider objc.io, Swift with Majid, SwiftLee, and Fatbobman; validate advice against SDK versions.
- Keep state ownership explicit and UI updates actor-safe. Avoid unstructured tasks unless their lifecycle and cancellation are managed.
- Avoid adding TCA or other frameworks without a demonstrated need.
- Verify changes with an Xcode build and relevant tests; do not claim validation without running them.
