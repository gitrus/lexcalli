# iOS engineering guide

Build Lexcalli as a native SwiftUI application. Prefer simple, testable platform-native patterns over additional architectural frameworks.

## Skills

Use these two skills when available locally:

- **SwiftUI Expert** — `.agents/skills/swiftui-expert/SKILL.md`; upstream: https://github.com/AvdLee/SwiftUI-Agent-Skill. Consult for views, Observation, state, navigation, accessibility, and UI performance.
- **Swift Concurrency** — `.agents/skills/swift-concurrency/SKILL.md`; upstream: https://github.com/AvdLee/Swift-Concurrency-Agent-Skill. Consult for async/await, actor isolation, Sendable, task lifecycle, cancellation, and concurrency diagnostics.

The upstream links are installation sources, not substitutes for local files. If skills have not been installed, consult upstream guidance explicitly rather than claiming to have read local files.

## Engineering decisions

- Prefer current Apple APIs compatible with the project's actual deployment target; verify availability before use.
- Use Apple Developer documentation as the primary API authority. For deeper SwiftUI behavior, consider objc.io, Swift with Majid, SwiftLee, and Fatbobman; validate advice against SDK versions.
- Keep state ownership explicit and UI updates actor-safe. Avoid unstructured tasks unless their lifecycle and cancellation are managed.
- Avoid adding TCA or other frameworks without a demonstrated need.
- Verify changes with Xcode build and relevant tests; do not claim validation without executing it.
