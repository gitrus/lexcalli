"""Reject UI-test results unless every required journey ran and passed."""

import argparse
import json
import subprocess
import sys

REQUIRED_TESTS = (
    "NavigationUITests/testEverySettingsPageOpens()",
    "StudyRelaunchUITests/testAnsweringLastCardEndsSession()",
    "StudyRelaunchUITests/testReviewHistoryAndDueDatesSurviveTermination()",
    "MixedExerciseUITests/testMixedUnlocksAfterSavedReviewAndRelaunch()",
    "MixedExerciseUITests/testWritingRetryRetainsFinalFeedbackAndSurvivesRelaunch()",
    "MixedExerciseUITests/testPickOneSelectionIsPrivateUntilConfirmationAndFinishSaves()",
    "MixedExerciseUITests/testInsufficientChoicesUseFlashcardFallback()",
    "MixedExerciseUITests/testWritingAtAccessibilitySizeKeepsConfirmationReachable()",
)


def validate(summary, tests):
    errors = []
    if (
        summary.get("result") != "Passed"
        or summary.get("failedTests", 1) != 0
        or summary.get("passedTests", 0) < len(REQUIRED_TESTS)
    ):
        errors.append("The UI test run did not pass.")

    results = {}
    pending = list(tests.get("testNodes", []))
    while pending:
        node = pending.pop()
        pending.extend(node.get("children", []))
        if node.get("nodeType") == "Test Case":
            results.setdefault(node.get("nodeIdentifier"), []).append(
                node.get("result")
            )

    for name in REQUIRED_TESTS:
        outcomes = results.get(name, [])
        if not outcomes:
            errors.append(f"Required test did not run: {name}")
        elif any(outcome != "Passed" for outcome in outcomes):
            errors.append(f"Required test did not pass: {name}: {outcomes}")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("result_bundle")
    args = parser.parse_args()
    try:
        reports = []
        for section in ("summary", "tests"):
            output = subprocess.run(
                [
                    "xcrun",
                    "xcresulttool",
                    "get",
                    "test-results",
                    section,
                    "--path",
                    args.result_bundle,
                    "--compact",
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            reports.append(json.loads(output.stdout))
        errors = validate(*reports)
    except (
        OSError,
        subprocess.CalledProcessError,
        ValueError,
        TypeError,
        AttributeError,
    ) as error:
        print(f"Cannot validate UI test results: {error}", file=sys.stderr)
        return 1
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        return 1
    print(f"UI tests: all {len(REQUIRED_TESTS)} required journeys passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
