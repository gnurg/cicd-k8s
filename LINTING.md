# Linting Setup

Linting is handled by **Ruff** (linter + formatter) and runs automatically before every `git commit` via **pre-commit**.

---

## 1. Dev dependencies

Dev tools are kept separate from the app runtime in `Dockerapp/requirements-dev.txt`.

Install them:
```powershell
cd Dockerapp
.venv\Scripts\pip install -r requirements-dev.txt
```

## 2. Pre-commit configuration

`.pre-commit-config.yaml` lives at the **repo root** and defines two hooks:
- `ruff-check` — lints the code
- `ruff-format` — formats the code

## 3. Register the Git hook

Run once from the repo root to wire pre-commit into `.git/hooks`:
```powershell
Dockerapp\.venv\Scripts\pre-commit install
```

From now on, every `git commit` will automatically run Ruff.

## 4. CI/CD — GitHub Actions

`.github/workflows/lint.yml` runs Ruff automatically on every `push` and `pull_request` using the official `astral-sh/ruff-action`. No Python setup needed.

Ruff only checks the `Dockerapp/` folder (configured via `src: Dockerapp`). Results are visible under the **Actions** tab on GitHub.

## 5. Branch protection

The real value of CI is on **Pull Requests**: configure GitHub to block merges on `main` until the `lint` check passes.

Setup: **Settings → Branches → Add branch ruleset** → target `main` → enable **Require status checks to pass** → add `lint`.

This enforces the flow: `feature branch → PR → lint passes → merge to main`.

---

## Manual run

To run Ruff manually on the app:
```cmd
Dockerapp\.venv\Scripts\ruff check Dockerapp\app.py
```

## Bypass pre-commit (for testing)

To intentionally commit code with errors and test the CI pipeline:
```cmd
git commit -m "your message" --no-verify
```

This skips the pre-commit hook entirely. The CI pipeline on GitHub will still catch the errors.
