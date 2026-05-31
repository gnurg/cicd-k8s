# Kubernetes Experiments

Learning Kubernetes and Minikube through hands-on examples. Configuration files are in `solution/`.

> **Tip:** It is common practice to alias `kubectl` to `k` for speed:
> ```cmd
> doskey k=kubectl $*
> ```

## Ultimate Goal

Simulate a real-world CI/CD pipeline with **dev → staging → prod** environments, running locally on Minikube, then deployable to AWS EKS with minimal changes.

The full flow a developer triggers by pushing code:

```
git push
    → GitHub Actions: lint + test
    → build Docker image
    → tag image with commit SHA (e.g. gnurg/cicd-k8s-webapp:a1b2c3d) — never use "latest" in production
    → push image to Docker Hub (or AWS ECR for production)
    → kubectl apply -k k8s/overlays/dev   (automatic on every push to main)
    → kubectl apply -k k8s/overlays/staging  (automatic or manual gate)
    → kubectl apply -k k8s/overlays/prod     (manual approval required)
```

Using the commit SHA as the image tag ensures every deployment is traceable — you always know exactly which version of the code is running in each environment.

Environments are simulated locally as **Kubernetes namespaces** — no real cloud needed until the AWS step.

### Roadmap

- [x] Start Minikube locally
- [x] Configure Kustomize structure (base + overlays per environment)
- [x] Add namespaces: dev, staging, prod (via namespace.yaml in each overlay)
- [x] Configure namespace-specific deployments (replicas, ConfigMap env vars)
- [x] Publish Docker image to Docker Hub
- [x] Deploy the Flask app to Minikube (dev namespace) and verify in browser
- [x] Deploy staging (2 pods running)
- [x] Deploy prod (3 pods)
- [ ] Add GitHub Actions step to build and push Docker image to Docker Hub
- [ ] Add GitHub Actions step to deploy to dev on every push to `main`
- [ ] Add staging deployment with a manual gate
- [ ] Add prod deployment with manual approval
- [ ] Migrate to AWS EKS

---

## 2. Publish the Docker image to Docker Hub

The image must be on Docker Hub so Kubernetes can pull it. All images for this project use the prefix `gnurg/cicd-k8s-*` to keep them grouped.

Create the repository on Docker Hub first: go to hub.docker.com → **Create Repository** → name it `cicd-k8s-webapp` → set visibility as needed.

Build and push:
```cmd
docker build -t gnurg/cicd-k8s-webapp:latest -f Dockerapp/Dockerfile Dockerapp
docker push gnurg/cicd-k8s-webapp:latest
```

> **Note:** `latest` is used here for local experimentation only. In production the CI/CD pipeline tags the image with the commit SHA automatically.

---

## 1. Start Minikube

Minikube runs a local single-node Kubernetes cluster inside a Docker container.

```cmd
minikube start
```

After startup, Docker Desktop will show the Minikube container and image running.

Verify the cluster is up by listing all pods across all namespaces:

```cmd
kubectl get pods -A -o wide
```

You will see the system pods running under the `kube-system` namespace (coredns, etcd, kube-apiserver, etc.).

## 3. Deploy to dev

Delete any previous failed deployment, then apply:
```cmd
kubectl delete -k k8s/overlays/dev
kubectl apply -k k8s/overlays/dev
```

Verify the deployment:
```cmd
kubectl get all -n dev
```

## 5. Expose the app externally (LoadBalancer + tunnel)

The Service is configured as `LoadBalancer` — the production-ready type. On AWS EKS this automatically provisions a load balancer. On Minikube it requires a tunnel to simulate the same behaviour.

Open a **second terminal** and keep it running:
```cmd
minikube tunnel
```

Then apply and check the external IP:
```cmd
kubectl apply -k k8s/overlays/dev
kubectl get service -n dev
```

You will see an `EXTERNAL-IP` assigned to the service. Open `http://<EXTERNAL-IP>` in the browser.

> **Note:** `kubectl apply` is idempotent — it compares the desired state (your yaml files) with the current cluster state and applies only the differences. Re-running it is always safe.
> The one exception is the Docker image: if you push a new image with the **same tag** (`latest`), Kubernetes won't detect a change. This is why production uses commit SHA tags — the tag changes on every build, triggering an automatic rolling update.

When iterating locally with `latest`, after rebuilding and pushing the image force a rolling update manually:
```cmd
kubectl rollout restart deployment/cicd-k8s-webapp -n dev
```
This recreates pods one at a time (zero downtime), pulling the new image from Docker Hub. Not needed in production where the image tag always changes.

During a rollout you will briefly see two ReplicaSets — the old one scaling down and the new one scaling up. Kubernetes keeps the old ReplicaSet at 0 replicas (not deleted) to allow a fast rollback:
```cmd
kubectl rollout undo deployment/cicd-k8s-webapp -n dev
```
Kubernetes retains the last 10 ReplicaSets by default, then cleans up older ones automatically.

---

## 6. Deploy to staging and prod

Same single command as dev — Kustomize applies the correct namespace, replicas, and ConfigMap for each environment:

```cmd
kubectl apply -k k8s/overlays/staging
kubectl apply -k k8s/overlays/prod
```

Verify all resources in a namespace:
```cmd
kubectl get all -n staging
kubectl get all -n prod
```

Expected: staging shows 2 pods, prod shows 3 pods — as configured in the overlays.

### Testing each environment locally

Due to a Minikube + Docker on Windows limitation, all `LoadBalancer` Services share the same `127.0.0.1:80` via `minikube tunnel`. Only one environment can be tested at a time in the browser.

To switch environment, delete the current one and apply the next:

```cmd
kubectl delete -k k8s/overlays/dev
kubectl apply -k k8s/overlays/staging
```

```cmd
kubectl delete -k k8s/overlays/staging
kubectl apply -k k8s/overlays/prod
```

Then open `http://127.0.0.1` — the background color confirms the active environment (green=dev, yellow=staging, red=prod).

> This is a local simulation constraint only. On AWS EKS each environment gets its own DNS endpoint and all three can run simultaneously on port 80.

---

## 4. Minikube Dashboard

Minikube includes a built-in web dashboard — one of its best features. It gives a full visual overview of the cluster: deployments, pods, replicasets, services, configmaps, namespaces and more.

```cmd
minikube dashboard --url
```

This prints a localhost URL and keeps the dashboard running in the terminal. Open the URL in the browser to inspect the cluster visually. Use the namespace dropdown (top left) to switch between `dev`, `staging`, `prod` and `kube-system`.
