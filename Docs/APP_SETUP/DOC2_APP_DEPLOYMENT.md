# Part 2 — Application Deployment (Django Crypto Exchange)

This document summarizes how I deployed the Django-based crypto exchange application onto the Kubernetes cluster from Part 1. It follows the same minimal, reproducible, report-style approach: only the essentials to stand it up quickly.

---

## 0) Scope & Targets

- Ingress host: `demo.iransre.ir`
- Namespace: `crypto-exchange`
- Helm release: `crypto-exchange`
- Container registry: `ghcr.io` (GitHub Container Registry)

---

## 0.1) Architecture Diagram

```
                          Internet
                              │
                              ▼
                  ┌──────────────────────────┐
                  │  NGINX Ingress (nginx)  │  demo.iransre.ir
                  └──────────────┬──────────┘
                                 │
                                 ▼
                  ┌──────────────────────────┐
                  │  Service: ClusterIP      │  port 80 → 8000
                  │  crypto-exchange         │
                  └──────────────┬──────────┘
                                 │
                                 ▼
                ┌───────────────────────────────────┐
                │  Deployment: Django (replicas=1) │  container port 8000
                │  Image: ghcr.io/<repo>:main      │
                └──────────────┬────────────────────┘
                               │
                               ▼
                  ┌──────────────────────────┐
                  │ PostgreSQL Primary       │  port 5432
                  │ (StatefulSet, ephemeral) │
                  └──────────────┬──────────┘
                                 │         (optional)
                                 │──────────────▶ Read Replicas (x2)

                  ┌──────────────────────────┐
                  │  Backup CronJob (daily)  │  pg_dump → /var/backups/crypto-exchange
                  └──────────────────────────┘
```

Notes:
- Demo uses ephemeral storage (no PVs) for speed and simplicity.
- Backups go to node hostPath;

---

## 1) Prerequisites

- Cluster and NGINX Ingress from Part 1 are running.
- Self-hosted GitHub Actions runner set up on `arvan-k8s-m1` (see K8S_Setup/DOC1_CLUSTER_SETUP.md §7).
- GitHub repo secrets configured:
  - `KUBECONFIG` (base64 of kubeconfig)
  - `DJANGO_SECRET_KEY`
  - `POSTGRES_PASSWORD`

---

## 2) Helm Chart Configuration

Primary values file: `helm/crypto-exchange/values.yaml`.

Minimal application settings used:

```yaml
replicaCount: 1

image:
  repository: ghcr.io/sajjadghf/demo
  pullPolicy: Always
  tag: "main"

django:
  debug: "False"
  secretKey: "${DJANGO_SECRET_KEY}"
  allowedHosts: "*"

ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: demo.iransre.ir
      paths:
        - path: /
          pathType: Prefix
  tls: []

postgresql:
  write:
    enabled: true
    persistence:
      enabled: false   # demo: ephemeral
  read:
    enabled: false     # enable later if needed

backup:
  enabled: true
  schedule: "0 2 * * *"    # daily 02:00 UTC
  retention: 7
  persistence:
    enabled: false          # demo: hostPath used on node
  hostPath: "/var/backups/crypto-exchange"
```

### 2.1 Objects Created
- Namespace: `crypto-exchange` (if not existing)
- Ingress: host `demo.iransre.ir` → service `crypto-exchange`
- Service: `crypto-exchange` (ClusterIP 80 → app 8000)
- Deployment: `crypto-exchange` (Django app)
- Secret/Config: app credentials/settings from values and CI secrets
- CronJob: `crypto-exchange-db-backup` (if `backup.enabled=true`)

### 2.2 Ports & Endpoints
- App container: `8000/tcp`
- Service: `80/tcp`
- PostgreSQL: `5432/tcp`

### 2.3 Labels (selectors)
- `app.kubernetes.io/name=crypto-exchange`
- `app.kubernetes.io/instance=crypto-exchange`

### 2.4 Config & secrets mapping
- `DJANGO_SECRET_KEY` → `django.secretKey`
- `POSTGRES_PASSWORD` → DB password for primary and app connection

---

## 3) CI/CD (Build + Deploy)

- Build workflow: `.github/workflows/build.yml`
  - Uses the self-hosted runner.
  - uses Docker Engine on the runner and builds/pushes `ghcr.io/<repo>:latest`.

- Deploy workflow: `.github/workflows/deploy.yml`
  - Applies Helm release using `KUBECONFIG`, `DJANGO_SECRET_KEY`, `POSTGRES_PASSWORD` secrets.

Trigger: push to `main` builds and deploys.

CI/CD flow:

```
Dev push → GitHub (main)
      │
      ▼
Build workflow (self-hosted runner: arvan-k8s-m1)
  - Install Docker Engine
  - docker build → ghcr.io/<repo>:latest
  - docker push
      │
      ▼
Deploy workflow
  - setup kubeconfig (secret)
  - helm upgrade --install crypto-exchange
      │
      ▼
Kubernetes cluster (Ingress/Service/Deployment/DB/Backup)
```