set shell := ["zsh", "-cu"]

# CI runs the lint, test, build and ui-test commands directly; update .github/workflows/swift.yml when they change.

core := "LexcalliKit"
project := "Lexcalli.xcodeproj"
scheme := "Lexcalli"
bundle_id := "dev.gitrus.lexcalli"
derived_data := ".build/xcode"
device := "iPhone 17"
swift_paths := "Lexcalli LexcalliUITests LexcalliKit/Sources LexcalliKit/Tests LexcalliKit/Package.swift"

# Command Line Tools ship Swift Testing outside the default search paths; with Xcode selected no flags are needed.

clt_dev := "/Library/Developer/CommandLineTools/Library/Developer"
test_flags := if `xcode-select -p` =~ "CommandLineTools" { "-Xswiftc -F" + clt_dev + "/Frameworks -Xlinker -rpath -Xlinker " + clt_dev + "/Frameworks -Xlinker -rpath -Xlinker " + clt_dev + "/usr/lib" } else { "" }

# List recipes
default:
    @just --list --unsorted

# Format Swift sources in place
fmt:
    swift format format -i --recursive --parallel {{ swift_paths }}

# Fail on formatting or style issues
lint:
    swift format lint --strict --recursive --parallel {{ swift_paths }}

# Run core tests (no simulator needed); use one filter per invocation, e.g. `just test --filter Compatibility`.
# Arguments are expanded by zsh; for a regex containing `|`, call `swift test` directly with a quoted filter.
test *args:
    swift test --package-path {{ core }} {{ test_flags }} {{ args }}

# Build the iOS app for the simulator (requires Xcode)
build: _require-xcode
    xcodebuild -project {{ project }} -scheme {{ scheme }} -destination 'generic/platform=iOS Simulator' -derivedDataPath {{ derived_data }} -quiet build

# Run the app's UI tests in a simulator, by name or UDID (requires Xcode); fails unless the expected tests ran
ui-test name=device: _require-xcode
    #!/usr/bin/env zsh
    set -euo pipefail
    python3 -m unittest discover -s scripts -p test_check_ui_tests.py
    rm -rf {{ derived_data }}/ui-tests.xcresult
    # Two simulators can share a name; a UDID picks one.
    if [[ '{{ name }}' =~ '^[0-9A-Fa-f-]{36}$' ]]; then destination='id={{ name }}'; else destination='name={{ name }}'; fi
    xcodebuild -project {{ project }} -scheme {{ scheme }} -destination "platform=iOS Simulator,$destination" \
        -derivedDataPath {{ derived_data }} -resultBundlePath {{ derived_data }}/ui-tests.xcresult \
        -parallel-testing-enabled NO -quiet test
    python3 scripts/check_ui_tests.py {{ derived_data }}/ui-tests.xcresult

# Build, install, and launch the app in a simulator (requires Xcode); `just run booted` uses the one already running
run name=device: build
    xcrun simctl boot '{{ name }}' 2>/dev/null || true
    # Xcode 27 replaces Simulator.app with DeviceHub.app
    open -a Simulator 2>/dev/null || open "$(xcode-select -p)/../Applications/DeviceHub.app"
    xcrun simctl install '{{ name }}' {{ derived_data }}/Build/Products/Debug-iphonesimulator/{{ scheme }}.app
    xcrun simctl launch '{{ name }}' {{ bundle_id }}

# Everything to run before a commit: lint, package tests (core, stores, import), app build
check: lint test
    just build

# `check` plus the app's UI tests in a simulator
check-all: check ui-test

[private]
_require-xcode:
    #!/usr/bin/env zsh
    [[ "$(xcode-select -p)" != *CommandLineTools* ]] && exit 0
    if [[ -d /Applications/Xcode.app ]]; then
        echo "Xcode is installed but not selected (xcode-select points to Command Line Tools). Run once:" >&2
    else
        echo "Xcode is not installed. Install it from the App Store, then run:" >&2
    fi
    echo "  sudo xcode-select -s /Applications/Xcode.app" >&2
    exit 1

# Open the project in Xcode
open:
    open {{ project }}

# Resolve core package dependencies
resolve:
    swift package --package-path {{ core }} resolve

# Show upstream swift-fsrs tags and main head to compare with the pin in LexcalliKit/Package.swift
fsrs-upstream:
    git ls-remote --tags --refs https://github.com/open-spaced-repetition/swift-fsrs.git | tail -3
    git ls-remote https://github.com/open-spaced-repetition/swift-fsrs.git HEAD

# Remove build outputs
clean:
    rm -rf .build {{ core }}/.build

# Update repository-local agent skills
skill-update:
    npx skills update
