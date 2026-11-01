set shell := ["zsh", "-cu"]

core := "LexcalliCore"
project := "Lexcalli.xcodeproj"
scheme := "Lexcalli"
bundle_id := "dev.gitrus.lexcalli"
derived_data := ".build/xcode"
device := "iPhone 17"
swift_paths := "Lexcalli LexcalliUITests LexcalliCore/Sources LexcalliCore/Tests LexcalliCore/Package.swift"

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

# Run core tests (no simulator needed); extra args go to `swift test`, e.g. `just test --filter Compatibility`
test *args:
    swift test --package-path {{ core }} {{ test_flags }} {{ args }}

# Build the iOS app for the simulator (requires Xcode)
build: _require-xcode
    xcodebuild -project {{ project }} -scheme {{ scheme }} -destination 'generic/platform=iOS Simulator' -derivedDataPath {{ derived_data }} -quiet build

# Run the app's UI tests in a simulator, by name or UDID (requires Xcode); fails unless the expected tests ran
ui-test name=device: _require-xcode
    #!/usr/bin/env zsh
    set -euo pipefail
    rm -rf {{ derived_data }}/ui-tests.xcresult
    # Two simulators can share a name; a UDID picks one.
    if [[ '{{ name }}' =~ '^[0-9A-Fa-f-]{36}$' ]]; then destination='id={{ name }}'; else destination='name={{ name }}'; fi
    xcodebuild -project {{ project }} -scheme {{ scheme }} -destination "platform=iOS Simulator,$destination" \
        -derivedDataPath {{ derived_data }} -resultBundlePath {{ derived_data }}/ui-tests.xcresult -quiet test
    xcrun xcresulttool get test-results summary --path {{ derived_data }}/ui-tests.xcresult --compact \
        | python3 -c "import json, sys; s = json.load(sys.stdin); p, f = s['passedTests'], s['failedTests']; print(f'UI tests: {p} passed, {f} failed'); sys.exit(0 if p >= 1 and f == 0 else 1)"

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

# Show upstream swift-fsrs tags and main head to compare with the pin in LexcalliCore/Package.swift
fsrs-upstream:
    git ls-remote --tags --refs https://github.com/open-spaced-repetition/swift-fsrs.git | tail -3
    git ls-remote https://github.com/open-spaced-repetition/swift-fsrs.git HEAD

# Remove build outputs
clean:
    rm -rf .build {{ core }}/.build

# Update repository-local agent skills
skill-update:
    npx skills update
