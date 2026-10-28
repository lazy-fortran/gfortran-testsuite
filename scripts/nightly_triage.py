#!/usr/bin/env python3
"""Run the nightly jobs and triage their failures.

Subcommands, run inside GitHub Actions:

  plan      turn the dispatch input into the list of jobs to run
  run       run one job's command in the current checkout
  bisect    after `run` failed: find the last green nightly that ran the job,
            rerun the job there and bisect the range; write the result as JSON
  step      one `git bisect run` step: the job's command, exit 0 good, 1 bad
  report    file or update the issue labelled nightly-failure
  success   close that issue once every job it records has passed again

`bisect`, `report` and `success` need GH_TOKEN.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

# Each nightly job runs one shell command from the repository root; the
# bisection reruns exactly this command at every step.
JOBS = {
    # The quick subset with the runner's gfortran; `make summary` always runs.
    "system-gfortran": """
        gfortran --version
        status=0
        make test-quick FC=gfortran || status=$?
        make summary
        exit "$status"
    """,
    # GCC at .gcc-commit, built into gcc-build (restored from the cache when the
    # commit is unchanged), then the full gfortran.dg suite. Test failures are
    # reported in the summary but do not fail the job.
    "gcc": """
        commit=$(cat .gcc-commit)
        if [ "$(git -C .gcc-upstream rev-parse HEAD 2>/dev/null)" != "$commit" ]; then
          rm -rf .gcc-upstream
          git init -q .gcc-upstream
          git -C .gcc-upstream remote add origin git://gcc.gnu.org/git/gcc.git
          git -C .gcc-upstream fetch -q --depth 1 origin "$commit"
          git -C .gcc-upstream checkout -q FETCH_HEAD
        fi
        if [ -f gcc-build/.gcc-commit ] && [ "$(cat gcc-build/.gcc-commit)" != "$commit" ]; then
          rm -rf gcc-build
        fi
        if [ ! -f gcc-build/Makefile ]; then
          mkdir -p gcc-build
          (cd gcc-build && ../.gcc-upstream/configure \
            --enable-languages=fortran --disable-multilib --disable-bootstrap \
            --disable-libsanitizer --disable-libvtv --disable-libgomp \
            CFLAGS='-O2 -g0' CXXFLAGS='-O2 -g0')
        fi
        echo "$commit" > gcc-build/.gcc-commit
        make -C gcc-build -j"$(nproc)"
        ./gcc-build/gcc/gfortran -v
        echo "GCC commit: $commit"
        make test FC="$PWD/gcc-build/gcc/gfortran" GCC="$PWD/gcc-build/gcc/gcc" \
          JOBS="$(nproc)" || echo "::warning::make test exited with $?"
        make summary
        if [ -f results/gfortran.sum ]; then
          echo "Total failures: $(grep -c '^FAIL:' results/gfortran.sum || true)"
        fi
    """,
}

WORKFLOW = "nightly.yml"
LABEL = "nightly-failure"
JOB_NAME = re.compile(r"^(?:.+ / )?Nightly (\S+)$")
MARKER = re.compile(r"<!-- nightly-failing-jobs: ([\w,.-]*) -->")


def parse_jobs(text):
    """Job list from a dispatch input; empty means every job."""
    text = (text or "").strip()
    if not text or text == "all":
        return list(JOBS)
    jobs = sorted({item.strip() for item in text.split(",") if item.strip()})
    unknown = [job for job in jobs if job not in JOBS]
    if not jobs or unknown:
        raise ValueError(f"jobs must be among {', '.join(JOBS)}: {text!r}")
    return jobs


def title_jobs(title):
    """Jobs a run covered, from its run title; None if not a nightly title."""
    if title == "nightly: all jobs":
        return set(JOBS)
    match = re.fullmatch(r"nightly: jobs (.+)", title or "")
    if not match:
        return None
    try:
        return set(parse_jobs(match.group(1)))
    except ValueError:
        return None


def job_key(name):
    match = JOB_NAME.match(name or "")
    return match.group(1) if match and match.group(1) in JOBS else None


def failing_jobs(jobs):
    return sorted({job_key(job["name"]) for job in jobs
                   if job_key(job["name"])
                   and job.get("conclusion") in ("failure", "timed_out", "cancelled")})


def last_green(runs, job, current_run):
    """Newest green nightly, other than this run, whose title covers the job."""
    for run in runs:
        if run["databaseId"] == current_run or run.get("conclusion") != "success":
            continue
        covered = title_jobs(run.get("displayTitle"))
        if covered is not None and job in covered:
            return run
    return None


def issue_title(branch):
    return f"Nightly failure on {branch}"


def issue_jobs(texts):
    """All failing jobs recorded in an issue body and its comments."""
    jobs = set()
    for text in texts:
        for match in MARKER.finditer(text or ""):
            jobs.update(job for job in match.group(1).split(",") if job)
    return jobs


def job_line(job, url, result, server, repo):
    name = f"[{job}]({url})" if url else job
    if not result:
        return f"- {name}: failed before its command ran, so it was not bisected."
    good, bad = result.get("good"), result["bad"]
    if not good:
        text = "no earlier green nightly ran this job, so the commit range is unknown"
    else:
        text = (f"commit range {good}..{bad} ({result['commits']} commits since its "
                f"last green nightly, [compare]({server}/{repo}/compare/{good}...{bad}))")
    culprit = result.get("culprit")
    if culprit:
        via = f" from #{result['pull']}" if result.get("pull") else ""
        text += f"; first bad commit {culprit['sha']} {culprit['subject']}{via}"
    if result.get("note"):
        text += ". " + result["note"]
    return f"- {name}: {text}"


def failure_report(*, branch, bad, jobs, job_urls, results, run_url, server, repo):
    lines = [f"The nightly run failed on `{branch}` at {bad}.", ""]
    lines.append("Failing jobs:")
    for job in jobs:
        lines.append(job_line(job, job_urls.get(job), results.get(job), server, repo))
    lines.append("")
    lines.append(f"Run with job logs and bisection logs: {run_url}")
    lines.append("")
    lines.append(f"<!-- nightly-failing-jobs: {','.join(jobs)} -->")
    return "\n".join(lines)


def should_close(green_jobs, recorded_jobs):
    return bool(recorded_jobs) and set(recorded_jobs) <= set(green_jobs)


# ---- GitHub and git plumbing -------------------------------------------------

def gh(*args, json_output=True):
    out = subprocess.run(["gh", *args], check=True, capture_output=True,
                         text=True).stdout
    return json.loads(out) if json_output and out.strip() else out


def git(*args, check=True):
    return subprocess.run(["git", *args], check=check, capture_output=True,
                          text=True).stdout.strip()


def env(name):
    return os.environ[name]


def run_command(job):
    print(f"$ {JOBS[job]}", flush=True)
    return subprocess.run(["bash", "-eo", "pipefail", "-c", JOBS[job]]).returncode


def open_issue(repo, branch):
    issues = gh("issue", "list", "--repo", repo, "--label", LABEL, "--state",
                "open", "--limit", "50", "--json", "number,title")
    for issue in issues:
        if issue["title"] == issue_title(branch):
            return issue["number"]
    return None


def cmd_plan(args):
    jobs = parse_jobs(args.jobs)
    with open(env("GITHUB_OUTPUT"), "a") as out:
        out.write(f"jobs={json.dumps(jobs)}\n")


def cmd_run(args):
    return 1 if run_command(args.job) else 0


def cmd_step(args):
    """Exit 0 for good, 1 for bad; a build failure counts as bad."""
    return 1 if run_command(args.job) else 0


def bisect(good, bad, job):
    """First bad commit in good..bad, or None when the job also fails at good."""
    script = Path(os.environ.get("RUNNER_TEMP", "/tmp")) / "nightly_triage.py"
    shutil.copy(__file__, script)  # bisect checks out older versions of this file
    step = [sys.executable, str(script), "step", job]
    git("checkout", "--quiet", good)
    try:
        good_still_passes = subprocess.run(step).returncode == 0
    finally:
        git("checkout", "--quiet", bad)
    if not good_still_passes:
        return None
    git("bisect", "start", bad, good)
    try:
        subprocess.run(["git", "bisect", "run", *step], check=True)
        sha = git("rev-parse", "refs/bisect/bad")
    finally:
        print(git("bisect", "log", check=False))
        git("bisect", "reset", check=False)
    return {"sha": sha, "subject": git("log", "-1", "--format=%s", sha)}


def cmd_bisect(args):
    repo, run_id = env("GITHUB_REPOSITORY"), int(env("GITHUB_RUN_ID"))
    branch, bad = env("GITHUB_REF_NAME"), env("GITHUB_SHA")
    runs = gh("run", "list", "--repo", repo, "--workflow", WORKFLOW, "--branch",
              branch, "--limit", "100", "--json",
              "databaseId,headSha,conclusion,displayTitle")
    green = last_green(runs, args.job, run_id)
    result = {"job": args.job, "bad": bad, "good": None, "commits": 0,
              "culprit": None, "pull": None, "note": None}
    good = green["headSha"] if green else None
    if good:
        result["good"] = good
        if good == bad:
            result["note"] = ("No commit since its last green nightly, so the "
                              "failure is not from a code change")
        elif subprocess.run(["git", "merge-base", "--is-ancestor", good, bad]).returncode:
            result["note"] = "The last green commit is not an ancestor; bisection skipped"
        else:
            result["commits"] = int(git("rev-list", "--count", f"{good}..{bad}"))
            try:
                culprit = bisect(good, bad, args.job)
            except subprocess.CalledProcessError as error:
                culprit = None
                result["note"] = f"Bisection did not complete ({error.cmd[:3]})"
            if culprit:
                result["culprit"] = culprit
                pulls = gh("api", f"repos/{repo}/commits/{culprit['sha']}/pulls")
                result["pull"] = pulls[0]["number"] if pulls else None
            elif not result["note"]:
                result["note"] = ("The job also fails at its last green commit when "
                                  "rerun, so no commit in the range caused it")
    print(json.dumps(result, indent=2))
    Path(args.out).write_text(json.dumps(result))


def cmd_report(args):
    repo, run_id = env("GITHUB_REPOSITORY"), int(env("GITHUB_RUN_ID"))
    server, branch, bad = env("GITHUB_SERVER_URL"), env("GITHUB_REF_NAME"), env("GITHUB_SHA")
    jobs = gh("api", "--paginate", f"repos/{repo}/actions/runs/{run_id}/jobs",
              "--jq", ".jobs[]", json_output=False)
    jobs = [json.loads(line) for line in jobs.splitlines() if line.strip()]
    failing = failing_jobs(jobs)
    if not failing:
        raise SystemExit("the nightly failed but no nightly job did")
    job_urls = {job_key(job["name"]): job["html_url"] for job in jobs if job_key(job["name"])}
    results = {}
    for path in Path(args.results).glob("**/*.json"):
        result = json.loads(path.read_text())
        results[result["job"]] = result
    body = failure_report(branch=branch, bad=bad, jobs=failing, job_urls=job_urls,
                          results=results, run_url=f"{server}/{repo}/actions/runs/{run_id}",
                          server=server, repo=repo)
    print(body)
    number = open_issue(repo, branch)
    if number:
        gh("issue", "comment", str(number), "--repo", repo, "--body", body,
           json_output=False)
    else:
        gh("label", "create", LABEL, "--repo", repo, "--color", "B60205",
           "--description", "A nightly CI job failed", "--force", json_output=False)
        gh("issue", "create", "--repo", repo, "--title", issue_title(branch),
           "--label", LABEL, "--body", body, json_output=False)


def cmd_success(args):
    repo, branch = env("GITHUB_REPOSITORY"), env("GITHUB_REF_NAME")
    number = open_issue(repo, branch)
    if not number:
        return
    issue = gh("issue", "view", str(number), "--repo", repo, "--json", "body,comments")
    recorded = issue_jobs([issue["body"]] + [c["body"] for c in issue["comments"]])
    green = parse_jobs(args.jobs)
    if not should_close(green, recorded):
        print(f"issue #{number} records jobs {sorted(recorded)}; this run covered {green}")
        return
    run_url = f"{env('GITHUB_SERVER_URL')}/{repo}/actions/runs/{env('GITHUB_RUN_ID')}"
    gh("issue", "close", str(number), "--repo", repo, "--comment",
       f"The nightly jobs are green again at {env('GITHUB_SHA')}: {run_url}",
       json_output=False)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="action", required=True)
    for name in ("plan", "success"):
        sub.add_parser(name).add_argument("--jobs", default="")
    for name in ("run", "step"):
        sub.add_parser(name).add_argument("job", choices=list(JOBS))
    bis = sub.add_parser("bisect")
    bis.add_argument("job", choices=list(JOBS))
    bis.add_argument("--out", required=True)
    sub.add_parser("report").add_argument("--results", required=True)
    args = parser.parse_args(argv)
    return {"plan": cmd_plan, "run": cmd_run, "step": cmd_step, "bisect": cmd_bisect,
            "report": cmd_report, "success": cmd_success}[args.action](args) or 0


if __name__ == "__main__":
    sys.exit(main())
