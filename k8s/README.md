# Kubernetes Configuration

This folder contains the Kubernetes manifests for the `cicd-k8s-webapp` Flask app, structured with **Kustomize** for multi-environment deployments.

---

## How Kustomize works

Kustomize is built into `kubectl` (no extra install needed). It lets you define a **base** configuration once and apply **overlays** per environment — avoiding duplication while keeping each environment independently configurable.

```
k8s/
  base/              ← shared configuration for all environments
  overlays/
    dev/             ← overrides for dev
    staging/         ← overrides for staging
    prod/            ← overrides for prod
```

To preview what Kustomize will generate for an environment (without applying it):
```cmd
kubectl kustomize k8s/overlays/dev
```

To apply to the cluster:
```cmd
kubectl apply -k k8s/overlays/dev
```

---

## Files

### `base/deployment.yaml`
Defines a Kubernetes **Deployment**: tells the cluster to run N replicas of the `cicd-k8s-webapp` container, which image to use, and which port to expose. The base sets `replicas: 1` as a default — overlays override this per environment.

### `base/service.yaml`
Defines a Kubernetes **Service**: a stable internal endpoint that routes traffic to the pods created by the Deployment. Without a Service, pods are unreachable. It maps port `80` (service) → port `5000` (container, where Flask listens).

### `base/kustomization.yaml`
Tells Kustomize which resources belong to the base. Every file listed here gets included when an overlay references this base.

### `overlays/<env>/namespace.yaml`
Declares the Kubernetes Namespace resource for that environment. Including it in the overlay means the namespace is created automatically as part of `kubectl apply -k` — no manual setup needed.

### `overlays/<env>/configmap.yaml`
Stores environment-specific configuration as key/value pairs (`CUSTOM_HEADER`, `BG_COLOR`, `FONT_COLOR`). The Deployment reads all keys from this ConfigMap as environment variables via `envFrom`. This follows the 12-factor app principle: same image in all environments, different configuration injected at deploy time.

| Environment | CUSTOM_HEADER | BG_COLOR | FONT_COLOR |
|-------------|---------------|----------|------------|
| dev | k8s (dev) | `#d4edda` (green) | `#155724` |
| staging | k8s (staging) | `#fff3cd` (yellow) | `#856404` |
| prod | k8s (prod) | `#f8d7da` (red) | `#721c24` |

### `overlays/<env>/kustomization.yaml`
Each overlay declares:
- `namespace` — which Kubernetes namespace to deploy into (`dev`, `staging`, `prod`)
- `resources` — points to the shared base, `namespace.yaml`, and `configmap.yaml`
- `patches` — JSON patch to override specific fields (e.g. replica count)

---

## Environment differences

| Environment | Namespace | Replicas |
|-------------|-----------|----------|
| dev         | dev       | 1        |
| staging     | staging   | 2        |
| prod        | prod      | 3        |

---

## What's not configured yet

### Service type: LoadBalancer
The current `service.yaml` uses the default `ClusterIP` type — the app is reachable only inside the cluster. To expose it externally:
- **Locally (Minikube):** change type to `LoadBalancer` and run `minikube service cicd-k8s -n dev` to open it in the browser
- **AWS EKS:** a `LoadBalancer` Service automatically provisions an AWS ALB

This will be added to the base when we test external access.

### Resource requests and limits
In production every container should declare how much CPU and memory it needs and what its maximum is — this prevents a single pod from starving others. Example to be added to `base/deployment.yaml`:

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "128Mi"
    cpu: "100m"
```

This will be configured per environment via overlays when we move toward production readiness.

---

## Applying an environment

A single command creates the namespace and deploys everything:
```cmd
kubectl apply -k k8s/overlays/dev
```

`kubectl apply -k <folder>` reads the `kustomization.yaml` in that folder and applies all listed resources in one shot. Kubernetes handles creation order automatically (namespace first, then deployment and service).

Check the deployment:
```cmd
kubectl get all -n dev
```
