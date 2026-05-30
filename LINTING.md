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

---

## Manual run

To run Ruff manually on the app:
```powershell
Dockerapp\.venv\Scripts\ruff check Dockerapp\app.py
```
