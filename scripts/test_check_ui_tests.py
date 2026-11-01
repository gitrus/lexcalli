import unittest

from check_ui_tests import REQUIRED_TESTS, validate


class UITestGateTests(unittest.TestCase):
    def setUp(self):
        self.summary = {"result": "Passed", "failedTests": 0, "passedTests": 3}
        self.cases = [
            {"nodeType": "Test Case", "nodeIdentifier": name, "result": "Passed"}
            for name in REQUIRED_TESTS
        ]

    def report(self):
        return {"testNodes": [{"children": [{"children": self.cases}]}]}

    def test_all_required_journeys_pass(self):
        self.assertEqual(validate(self.summary, self.report()), [])

    def test_settings_alone_does_not_satisfy_gate(self):
        self.summary["passedTests"] = 1
        self.cases = self.cases[:1]
        errors = validate(self.summary, self.report())
        for name in REQUIRED_TESTS[1:]:
            self.assertIn(f"Required test did not run: {name}", errors)

    def test_missing_required_test_fails_even_with_enough_other_passes(self):
        missing = self.cases.pop()["nodeIdentifier"]
        self.cases.append(
            {
                "nodeType": "Test Case",
                "nodeIdentifier": "Unrelated/test()",
                "result": "Passed",
            }
        )
        self.assertIn(
            f"Required test did not run: {missing}",
            validate(self.summary, self.report()),
        )

    def test_skipped_failed_or_expected_failure_does_not_count(self):
        for result in ("Skipped", "Failed", "Expected Failure"):
            with self.subTest(result=result):
                self.cases[0]["result"] = result
                self.assertTrue(validate(self.summary, self.report()))

    def test_one_failed_device_cannot_be_hidden_by_another_passing_device(self):
        failed = dict(self.cases[0], result="Failed")
        self.cases.append(failed)
        self.assertTrue(validate(self.summary, self.report()))

    def test_other_failures_reject_the_run(self):
        self.summary.update(result="Failed", failedTests=1)
        self.assertTrue(validate(self.summary, self.report()))

    def test_missing_result_data_fails_closed(self):
        self.assertTrue(validate({}, {}))
        self.assertTrue(validate(self.summary, {}))


if __name__ == "__main__":
    unittest.main()
