#!/usr/bin/env python3
"""Lint task JSON files for structural validity and semantic quality.

Checks two categories of issues:

Structural (errors):
  - Valid JSON
  - Required fields present on every task
  - No duplicate task IDs across all files
  - Dependency references resolve to real task IDs
  - No dependency cycles (DAG validation)
  - Meta block present with required fields

Semantic (warnings):
  - Description quality (not empty, not placeholder text)
  - Completed tasks have completion dates
  - Current tasks aren't duplicated in backlog
  - Modification counter is a non-negative integer
  - Review thresholds are a sorted list of positive integers

Exit codes:
  0 - All checks pass
  1 - Errors found (structural problems that must be fixed)
  2 - Warnings only (semantic issues worth reviewing)
"""

from __future__ import annotations

import json
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


# -- Data types ----------------------------------------------------------------

@dataclass
class LintResult:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def error(self, file: str, msg: str) -> None:
        self.errors.append(f"ERROR [{file}]: {msg}")

    def warn(self, file: str, msg: str) -> None:
        self.warnings.append(f"WARN  [{file}]: {msg}")

    @property
    def ok(self) -> bool:
        return not self.errors

    @property
    def clean(self) -> bool:
        return not self.errors and not self.warnings

    def print_report(self) -> None:
        for e in self.errors:
            print(e, file=sys.stderr)
        for w in self.warnings:
            print(w, file=sys.stderr)
        if self.clean:
            print("task lint: all checks passed")
        elif self.ok:
            print(f"task lint: passed with {len(self.warnings)} warning(s)")
        else:
            print(
                f"task lint: FAILED with {len(self.errors)} error(s), "
                f"{len(self.warnings)} warning(s)",
                file=sys.stderr,
            )


# -- File loading --------------------------------------------------------------

def load_json(path: Path, result: LintResult) -> dict[str, Any] | None:
    """Load and parse a JSON file. Returns None on failure."""
    if not path.exists():
        result.error(path.name, f"file not found: {path}")
        return None
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as e:
        result.error(path.name, f"cannot read file: {e}")
        return None
    try:
        data = json.loads(text)
    except json.JSONDecodeError as e:
        result.error(path.name, f"invalid JSON: {e}")
        return None
    if not isinstance(data, dict):
        result.error(path.name, "top-level value must be an object")
        return None
    return data


# -- Structural checks ---------------------------------------------------------

REQUIRED_TASK_FIELDS = {"id", "description"}
OPTIONAL_TASK_FIELDS = {
    "title", "depends_on", "status", "added_date", "completed_date",
    "notes", "agent_type", "value", "priority",
}
KNOWN_TASK_FIELDS = REQUIRED_TASK_FIELDS | OPTIONAL_TASK_FIELDS

PLACEHOLDER_DESCRIPTIONS = {
    "", "todo", "tbd", "fix this", "placeholder", "...", "xxx",
    "description", "fill in later",
}


def check_meta(data: dict, filename: str, result: LintResult) -> None:
    """Validate the meta block."""
    meta = data.get("meta")
    if meta is None:
        result.error(filename, "missing 'meta' block")
        return
    if not isinstance(meta, dict):
        result.error(filename, "'meta' must be an object")
        return
    if "purpose" not in meta:
        result.warn(filename, "meta block missing 'purpose' field")


def check_tasks_meta(data: dict, filename: str, result: LintResult) -> None:
    """Additional meta checks specific to the main tasks.json."""
    meta = data.get("meta", {})
    mod_count = meta.get("modification_count")
    if mod_count is not None:
        if not isinstance(mod_count, int) or mod_count < 0:
            result.error(filename, "modification_count must be a non-negative integer")

    thresholds = meta.get("review_thresholds")
    if thresholds is not None:
        if not isinstance(thresholds, list):
            result.error(filename, "review_thresholds must be a list")
        elif thresholds != sorted(thresholds):
            result.warn(filename, "review_thresholds should be sorted ascending")
        elif any(not isinstance(t, int) or t <= 0 for t in thresholds):
            result.warn(filename, "review_thresholds should be positive integers")


def extract_tasks(
    data: dict, filename: str, sections: list[str], result: LintResult,
) -> list[dict]:
    """Pull task objects from named sections of a data file."""
    tasks: list[dict] = []
    for section in sections:
        items = data.get(section)
        if items is None:
            continue
        if not isinstance(items, list):
            result.error(filename, f"'{section}' must be a list")
            continue
        for i, task in enumerate(items):
            if not isinstance(task, dict):
                result.error(filename, f"{section}[{i}] is not an object")
                continue
            tasks.append(task)
    return tasks


def extract_archive_tasks(data: dict, filename: str, result: LintResult) -> list[dict]:
    """Pull tasks from archive format (grouped by phase)."""
    tasks: list[dict] = []
    archived = data.get("archived")
    if archived is None:
        return tasks
    if not isinstance(archived, list):
        result.error(filename, "'archived' must be a list")
        return tasks
    for i, phase in enumerate(archived):
        if not isinstance(phase, dict):
            result.error(filename, f"archived[{i}] is not an object")
            continue
        phase_tasks = phase.get("tasks", [])
        if not isinstance(phase_tasks, list):
            result.error(filename, f"archived[{i}].tasks must be a list")
            continue
        for j, task in enumerate(phase_tasks):
            if not isinstance(task, dict):
                result.error(filename, f"archived[{i}].tasks[{j}] is not an object")
                continue
            tasks.append(task)
    return tasks


def check_task_fields(task: dict, filename: str, result: LintResult) -> str | None:
    """Validate required fields on a single task. Returns the task ID or None."""
    task_id = task.get("id")
    if task_id is None:
        result.error(filename, f"task missing 'id': {json.dumps(task, default=str)[:120]}")
        return None
    if not isinstance(task_id, str) or not task_id.strip():
        result.error(filename, f"task 'id' must be a non-empty string: {task_id!r}")
        return None

    desc = task.get("description")
    if desc is None:
        result.error(filename, f"task '{task_id}' missing 'description'")
    elif not isinstance(desc, str):
        result.error(filename, f"task '{task_id}' description must be a string")

    # Check for unknown fields (warn, not error -- allow extension)
    for key in task:
        if key not in KNOWN_TASK_FIELDS:
            result.warn(filename, f"task '{task_id}' has unknown field '{key}'")

    return task_id


def check_description_quality(task: dict, filename: str, result: LintResult) -> None:
    """Flag placeholder or suspiciously short descriptions."""
    task_id = task.get("id", "?")
    desc = task.get("description", "")
    if not isinstance(desc, str):
        return
    normalized = desc.strip().lower().rstrip(".")
    if normalized in PLACEHOLDER_DESCRIPTIONS:
        result.warn(filename, f"task '{task_id}' has placeholder description: {desc!r}")
    elif len(desc.strip()) < 10:
        result.warn(filename, f"task '{task_id}' has very short description ({len(desc.strip())} chars)")


def check_completed_dates(
    tasks: list[dict], filename: str, section: str, result: LintResult,
) -> None:
    """Completed tasks should have a completed_date."""
    for task in tasks:
        task_id = task.get("id", "?")
        if "completed_date" not in task:
            result.warn(
                filename,
                f"task '{task_id}' in '{section}' has no completed_date",
            )


def check_duplicates(
    all_ids: dict[str, list[str]], result: LintResult,
) -> None:
    """Check for duplicate IDs across all files."""
    seen: dict[str, str] = {}
    for task_id, locations in all_ids.items():
        if len(locations) > 1:
            loc_str = ", ".join(locations)
            result.error("cross-file", f"duplicate task ID '{task_id}' found in: {loc_str}")


def check_dependencies(
    all_ids: set[str],
    tasks_with_deps: list[tuple[str, dict]],
    result: LintResult,
) -> None:
    """Validate dependency references and detect cycles."""
    # Check references exist
    graph: dict[str, list[str]] = defaultdict(list)
    for filename, task in tasks_with_deps:
        task_id = task.get("id")
        if not task_id:
            continue
        deps = task.get("depends_on")
        if deps is None:
            continue
        if isinstance(deps, str):
            deps = [deps]
        if not isinstance(deps, list):
            result.error(filename, f"task '{task_id}' depends_on must be a list or string")
            continue
        for dep in deps:
            if not isinstance(dep, str):
                result.error(filename, f"task '{task_id}' has non-string dependency: {dep!r}")
                continue
            if dep not in all_ids:
                result.error(filename, f"task '{task_id}' depends on unknown task '{dep}'")
            graph[task_id].append(dep)

    # Cycle detection via DFS
    WHITE, GRAY, BLACK = 0, 1, 2
    color: dict[str, int] = defaultdict(int)
    path: list[str] = []

    def dfs(node: str) -> bool:
        color[node] = GRAY
        path.append(node)
        for neighbor in graph.get(node, []):
            if color[neighbor] == GRAY:
                cycle_start = path.index(neighbor)
                cycle = path[cycle_start:] + [neighbor]
                result.error(
                    "cross-file",
                    f"dependency cycle: {' -> '.join(cycle)}",
                )
                return True
            if color[neighbor] == WHITE:
                if dfs(neighbor):
                    return True
        path.pop()
        color[node] = BLACK
        return False

    for node in graph:
        if color[node] == WHITE:
            if dfs(node):
                break  # Report first cycle only


# -- Main entry point ----------------------------------------------------------

def lint_tasks(tasks_dir: Path) -> LintResult:
    """Run all lint checks on the task files in the given directory."""
    result = LintResult()

    tasks_file = tasks_dir / "tasks.json"
    archive_file = tasks_dir / "tasks_archive.json"
    icebox_file = tasks_dir / "tasks_icebox.json"

    # Load files (missing archive/icebox is okay for new projects)
    tasks_data = load_json(tasks_file, result)

    archive_data = None
    if archive_file.exists():
        archive_data = load_json(archive_file, result)

    icebox_data = None
    if icebox_file.exists():
        icebox_data = load_json(icebox_file, result)

    if tasks_data is None:
        return result  # Can't proceed without main tasks file

    # Meta checks
    check_meta(tasks_data, "tasks.json", result)
    check_tasks_meta(tasks_data, "tasks.json", result)
    if archive_data:
        check_meta(archive_data, "tasks_archive.json", result)
    if icebox_data:
        check_meta(icebox_data, "tasks_icebox.json", result)

    # Required sections in tasks.json
    for section in ("completed", "current", "backlog"):
        if section not in tasks_data:
            result.error("tasks.json", f"missing required section '{section}'")

    # Extract all tasks
    main_tasks = extract_tasks(
        tasks_data, "tasks.json", ["completed", "current", "backlog"], result,
    )
    archive_tasks = extract_archive_tasks(
        archive_data, "tasks_archive.json", result,
    ) if archive_data else []
    icebox_tasks = extract_tasks(
        icebox_data, "tasks_icebox.json", ["icebox"], result,
    ) if icebox_data else []

    # Field validation and ID collection
    all_ids: dict[str, list[str]] = defaultdict(list)
    tasks_with_deps: list[tuple[str, dict]] = []

    for task in main_tasks:
        tid = check_task_fields(task, "tasks.json", result)
        if tid:
            all_ids[tid].append("tasks.json")
        check_description_quality(task, "tasks.json", result)
        tasks_with_deps.append(("tasks.json", task))

    for task in archive_tasks:
        tid = check_task_fields(task, "tasks_archive.json", result)
        if tid:
            all_ids[tid].append("tasks_archive.json")

    for task in icebox_tasks:
        tid = check_task_fields(task, "tasks_icebox.json", result)
        if tid:
            all_ids[tid].append("tasks_icebox.json")
        check_description_quality(task, "tasks_icebox.json", result)

    # Completed tasks should have dates
    completed_tasks = extract_tasks(tasks_data, "tasks.json", ["completed"], result)
    check_completed_dates(completed_tasks, "tasks.json", "completed", result)
    check_completed_dates(archive_tasks, "tasks_archive.json", "archived", result)

    # Cross-file checks
    check_duplicates(all_ids, result)

    all_id_set = set(all_ids.keys())
    check_dependencies(all_id_set, tasks_with_deps, result)

    return result


def main() -> int:
    """CLI entry point."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Lint task JSON files for structural and semantic issues.",
    )
    parser.add_argument(
        "tasks_dir",
        nargs="?",
        default=None,
        help="Path to the tasks directory (default: auto-detect from script location)",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat warnings as errors",
    )
    args = parser.parse_args()

    if args.tasks_dir:
        tasks_dir = Path(args.tasks_dir)
    else:
        # Default: assume script is in semantic_stack/scripts/, tasks are in semantic_stack/tasks/
        script_dir = Path(__file__).resolve().parent
        tasks_dir = script_dir.parent / "tasks"

    if not tasks_dir.is_dir():
        print(f"error: tasks directory not found: {tasks_dir}", file=sys.stderr)
        return 1

    result = lint_tasks(tasks_dir)
    result.print_report()

    if not result.ok:
        return 1
    if args.strict and not result.clean:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
