**Introduction**

This document explains how to build, test and privately use the Docker image for the app located at [Dockerapp/Dockerfile](Dockerapp/Dockerfile) and [Dockerapp/app.py](Dockerapp/app.py#L1-L20).

The app is a small Flask web application that returns a customizable HTML page. The content is driven by environment variables:

- `CUSTOM_HEADER`: main heading text.
- `CUSTOM_PHOTO`: image shown on the page.
- `BG_COLOR` and `FONT_COLOR`: background and text colors.
- It also displays the host/container name using `socket.gethostname()`.

This app is a configurable "demo web container" useful to test how a container exposes a customizable web page.

**Image name suggestions**

Instead of a generic name like `dockerapp`, consider a descriptive image name such as:

- `personal-webapp`
- `custom-greeting-app`
- `env-branded-page`
- `private-flask-app`
- `k8s-demo-webapp`

Choose a name that fits your usage. For example, `cicd-k8s:latest` works well for a personal project.

**Prerequisites**

- Docker Desktop (or a Docker engine) installed and running.
- Command-line access (`bash`, PowerShell or `cmd`).
- (Optional) Access to a private registry (e.g. AWS ECR, Azure ACR, GitHub Container Registry).

**Build the image**

Open a shell at the project root and run:

```bash
docker build -t cicd-k8s:latest -f Dockerapp/Dockerfile Dockerapp
```

- `-t cicd-k8s:latest`: image name and tag.
- `-f Dockerapp/Dockerfile Dockerapp`: use the `Dockerfile` in the `Dockerapp` folder.

Verify the image was created:

```bash
docker images | grep cicd-k8s || docker images cicd-k8s
```

**Run the app locally with Docker**

Quick example (maps container port `80` to host port `8080`):

```bash
docker run --rm -p 8080:80 cicd-k8s:latest
```

Open http://localhost:8080 in your browser.

To pass environment variables (custom header, colors, etc.):

```bash
docker run --rm -p 8080:80 \
  -e CUSTOM_HEADER="Hello from container" -e BG_COLOR=lightblue \
  cicd-k8s:latest
```

Or use an environment override file (e.g. `.dockerapp.env.override`) with selected variables:

```bash
docker run --rm -p 8080:80 --env-file Dockerapp/.dockerapp.env.override cicd-k8s:latest
```

The `.dockerapp.env.override` file overrides only the specified variables; all others use Dockerfile defaults.

**Keeping the image private**

You have several options to keep the image private:

1) Private registry (recommended)

- Create a private repository on a registry (e.g. Azure ACR, AWS ECR, GitHub Packages) or use a self-hosted registry.
- Tag and push the image with authentication.

Example (generic):

```bash
docker tag cicd-k8s:latest myregistry.example.com/myrepo/cicd-k8s:latest
docker login myregistry.example.com
docker push myregistry.example.com/myrepo/cicd-k8s:latest
```

Example (AWS ECR):

```bash
aws ecr get-login-password --region <REGION> | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com
docker tag cicd-k8s:latest <AWS_ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/myrepo/cicd-k8s:latest
docker push <AWS_ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/myrepo/cicd-k8s:latest
```

Example (GitHub Container Registry - private):

```bash
docker login ghcr.io -u <USERNAME> -p <PERSONAL_ACCESS_TOKEN>
docker tag cicd-k8s:latest ghcr.io/<USERNAME>/cicd-k8s:latest
docker push ghcr.io/<USERNAME>/cicd-k8s:latest
```

Example (Docker Hub private):

```bash
docker login -u <USERNAME> -p <PASSWORD>
docker tag cicd-k8s:latest <USERNAME>/<REPO>:cicd-k8s
docker push <USERNAME>/<REPO>:cicd-k8s
```

On Docker Hub, create a repository and set it to **Private** in the repository settings.

2) Transfer the image without a registry

If you prefer not to use a registry, export the image to a file, transfer it, and import it on the target server:

```bash
docker save -o cicd-k8s.tar cicd-k8s:latest
# transfer cicd-k8s.tar to the target server (scp, rsync, USB...)
# on the target server:
docker load -i cicd-k8s.tar
docker run --rm -p 8080:80 cicd-k8s:latest
```

3) Self-hosted registry

Install and configure a private Docker Registry (e.g. `registry:2`), protect it with TLS and authentication, then tag and push as above.

**Best practices for private images**

- Do not bake secrets into the `Dockerfile`; use environment variables or a secret manager (Docker secrets, Kubernetes Secrets, Vault).
- Add a `.dockerignore` to avoid copying sensitive files into the build context.
- Limit access to the registry and use tokens with least privilege.
- Consider signing images (e.g. `notary` or `cosign`) if required.

**Cleanup and inspection**

Remove local image:

```bash
docker rmi cicd-k8s:latest
```

List containers:

```bash
docker ps -a
```

**Relevant files**

- [Dockerapp/Dockerfile](Dockerapp/Dockerfile)
- [Dockerapp/app.py](Dockerapp/app.py#L1-L20)
- `Dockerapp/requirements.txt` (pip dependencies)

**Local (non-Docker) run**

If you want to run the app locally on your machine for development (without Docker), the `Dockerapp` folder contains a helper `run.bat` and an example `.env` file.

- `Dockerapp/.env`: example environment variables for local runs. Do NOT store real secrets here.
- `Dockerapp/run.bat`: creates/activates a `.venv` virtual environment, installs dependencies and runs `python app.py` (the app will load `.env`).

Manual equivalent commands on Windows (cmd):

```bat
cd /d d:\dev\personale\cicd-k8s\Dockerapp
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

Important: do not commit `Dockerapp/.env`, `.venv` or `Dockerapp/run.bat` to a public repository. The repository root `.gitignore` has been updated to exclude these files. If you prefer, create a `Dockerapp/.env.example` (without secrets) to document required variables.
