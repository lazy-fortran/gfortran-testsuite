"""Guards for the nightly triage logic, with no GitHub or git access."""
import unittest

import nightly_triage as nt

JOBS = list(nt.JOBS)
FIRST = JOBS[0]


class TriageTests(unittest.TestCase):
    def test_job_selection(self):
        self.assertEqual(nt.parse_jobs(""), JOBS)
        self.assertEqual(nt.parse_jobs(f" {FIRST},{FIRST}"), [FIRST])
        with self.assertRaises(ValueError):
            nt.parse_jobs("no-such-job")
        self.assertEqual(nt.title_jobs("nightly: all jobs"), set(JOBS))
        self.assertEqual(nt.title_jobs(f"nightly: jobs {FIRST}"), {FIRST})
        self.assertIsNone(nt.title_jobs("CI"))
        self.assertIsNone(nt.title_jobs("nightly: jobs no-such-job"))

    def test_failing_jobs_from_run(self):
        jobs = [{"name": f"Nightly {FIRST}", "conclusion": "failure"},
                {"name": "Nightly no-such-job", "conclusion": "failure"},
                {"name": "Plan", "conclusion": "failure"},
                {"name": "Report the failure", "conclusion": "failure"}]
        self.assertEqual(nt.failing_jobs(jobs), [FIRST])
        jobs[0]["conclusion"] = "success"
        self.assertEqual(nt.failing_jobs(jobs), [])

    def test_last_green_must_cover_the_job(self):
        runs = [
            {"databaseId": 9, "conclusion": "success", "headSha": "self",
             "displayTitle": "nightly: all jobs"},
            {"databaseId": 8, "conclusion": "success", "headSha": "other",
             "displayTitle": "nightly: jobs no-such-job"},
            {"databaseId": 7, "conclusion": "failure", "headSha": "red",
             "displayTitle": "nightly: all jobs"},
            {"databaseId": 6, "conclusion": "success", "headSha": "green",
             "displayTitle": f"nightly: jobs {FIRST}"}]
        self.assertEqual(nt.last_green(runs, FIRST, 9)["headSha"], "green")
        self.assertIsNone(nt.last_green(runs[:3], FIRST, 9))

    def test_report_and_closing(self):
        results = {FIRST: {"job": FIRST, "bad": "b" * 40, "good": "a" * 40,
                           "commits": 3, "pull": 42, "note": None,
                           "culprit": {"sha": "c" * 40, "subject": "Break it"}}}
        body = nt.failure_report(
            branch="main", bad="b" * 40, jobs=[FIRST, "setup-only"],
            job_urls={FIRST: "https://x/j"}, results=results,
            run_url="https://x/run", server="https://github.com", repo="o/r")
        self.assertIn(f"[{FIRST}](https://x/j): commit range", body)
        self.assertIn("first bad commit " + "c" * 40 + " Break it from #42", body)
        self.assertIn("compare/" + "a" * 40 + "..." + "b" * 40, body)
        self.assertIn("setup-only: failed before its command ran", body)
        self.assertNotIn("@", body)
        recorded = nt.issue_jobs([body, "a comment"])
        self.assertEqual(recorded, {FIRST, "setup-only"})
        self.assertFalse(nt.should_close([FIRST], recorded))
        self.assertTrue(nt.should_close([FIRST, "setup-only"], recorded))
        self.assertFalse(nt.should_close(JOBS, set()))

    def test_unknown_range_is_stated(self):
        results = {FIRST: {"job": FIRST, "bad": "b" * 40, "good": None,
                           "commits": 0, "culprit": None, "pull": None, "note": None}}
        body = nt.failure_report(
            branch="main", bad="b" * 40, jobs=[FIRST], job_urls={}, results=results,
            run_url="https://x/run", server="https://github.com", repo="o/r")
        self.assertIn("commit range is unknown", body)


if __name__ == "__main__":
    unittest.main()
