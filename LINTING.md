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
- `ruff-check --fix` — lints the code and auto-fixes safe issues (unused imports, `== None` → `is None`, etc.)
- `ruff-format` — formats the code (indentation, spacing, line length)

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

## 6. Test GitHub Actions locally with `act`

**Requirement:** Docker installed and running.

`act` simulates GitHub Actions locally in a Docker container — no push needed to test the workflow.

Install:
```cmd
winget install nektos.act
```

Run the workflow locally from the repo root:
```cmd
act push          # simulates a push event (default)
act pull_request  # simulates a pull_request event
```

Both trigger the `lint` job since the workflow listens to both events. Use `act pull_request` to simulate exactly what happens when a PR is opened.

First run asks for an image size — **Micro** is sufficient for this workflow.

## 7. VS Code integration

Install the **Ruff** extension from the marketplace: `astral-sh.ruff`

Workspace settings are already configured in `.vscode/settings.json` — no manual setup needed. Ruff will lint, fix, and format automatically on every save.

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
