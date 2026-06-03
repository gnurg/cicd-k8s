# GitHub Actions

All workflows are in `.github/workflows/`. They run automatically on GitHub — results are visible under the **Actions** tab.

To test workflows locally before pushing, use `act` (see [LINTING.md](LINTING.md)).

---

## Secrets

Some workflows require credentials stored as **GitHub Secrets** — never hardcoded in workflow files.

Setup: **Settings → Secrets and variables → Actions → New repository secret**

| Secret | Value | Used by |
|--------|-------|---------|
| `DOCKERHUB_USERNAME` | Docker Hub username (e.g. `gnurg`) | Docker build & push |
| `DOCKERHUB_TOKEN` | Docker Hub personal access token (**Read & Write**) | Docker build & push |

To generate a Docker Hub token: **hub.docker.com → Account Settings → Personal Access Tokens → Generate new token** → select **Read & Write**.

---

## Workflows

### `lint.yml` — Lint

Runs Ruff (linter + formatter) on every `push` and `pull_request` against the `Dockerapp/` folder.

**Trigger:** `push`, `pull_request`  
**Job:** `lint`

Uses the official `astral-sh/ruff-action` — no Python or pip setup needed.

```yaml
- uses: astral-sh/ruff-action@v3
  with:
    src: Dockerapp
    version: "0.15.15"
```

Combined with branch protection (**Settings → Branches → ruleset → Require status checks → `lint`**), this blocks merges to `main` if linting fails.

---

### `build-push.yml` — Build and Push

Builds the Docker image and pushes it to Docker Hub on every push to `main`.

**Trigger:** `push` to `main` only  
**Job:** `build-push`

Uses three official Docker actions:
- `docker/login-action` — authenticates to Docker Hub using the `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets
- `docker/metadata-action` — generates image tags automatically:
  - `sha-a1b2c3d` — commit SHA tag for traceability (every build is uniquely identified)
  - `latest` — also applied on pushes to `main`
- `docker/build-push-action` — builds the image from `Dockerapp/Dockerfile` and pushes both tags to Docker Hub

Three deploy jobs follow `build-push` in sequence, each linked to a GitHub Environment:

| Job | Environment | Trigger |
|-----|-------------|---------|
| `deploy-dev` | `dev` | automatic after `build-push` |
| `deploy-staging` | `staging` | manual approval required |
| `deploy-prod` | `prod` | manual approval required |

Each job updates the image tag in the corresponding Kustomize overlay to the exact commit SHA. The actual `kubectl apply` is commented out until the cluster is migrated to AWS EKS — at that point, uncomment the `Configure kubectl` and `Deploy` steps in each job.

GitHub Environments are configured under **Settings → Environments**. Staging and prod have **Required reviewers** set — GitHub pauses the pipeline and sends a notification before those jobs start.
