# Scripts

Tools for validating and maintaining the task management system.

## Contents

- `lint_tasks.py` -- Structural and semantic validation for task JSON files
- `hooks/` -- Git hooks that enforce task validation at commit time

## Usage

Run the linter directly:
```bash
python3 lint_tasks.py                    # auto-detect tasks directory
python3 lint_tasks.py /path/to/tasks/    # explicit directory
python3 lint_tasks.py --strict           # treat warnings as errors
```

Install hooks by symlinking into `.git/hooks/` or by calling them from your existing hook chain. See `hooks/` for details.
