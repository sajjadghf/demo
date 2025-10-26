# Part 0 — Proposal: Kubernetes, Monitoring, Logging, and App Delivery

This proposal documents the selected approaches and rationale for bringing up a minimal but coherent platform: Kubernetes cluster, ingress, observability (monitoring + logging), and application delivery for the Django crypto exchange. It mirrors the simple, reproducible style used in Part 1 and Part 2 while explaining trade‑offs and future upgrades.

---

## Executive Summary

- Kubernetes via Kubespray using containerd + Calico on 2 nodes for fast, controllable bootstrap.
- Ingress via community NGINX chart for straightforward HTTP routing.
- Monitoring via kube‑prometheus‑stack (defaults) to keep setup minimal while covering core metrics and dashboards.
- Logging via Elasticsearch + Kibana (Bitnami) in stateless mode for the demo; optional Fluent Bit forwarder when needed.
- Application delivered with GitHub Actions, GHCR, and a self‑hosted runner on the control‑plane node.

Why this set: fastest path to a working, inspectable environment with common building blocks and low configuration surface.

---

## High‑Level Architecture

```
Users ─────────▶ ArvanCloud CDN
                   │
                   ▼
          ┌──────────────────────┐
          │ NGINX Ingress (L7)  │  demo.iransre.ir
          └───────────┬─────────┘
                      │
                      ▼
          ┌──────────────────────┐
          │  Service (ClusterIP) │  80 → 8000
          └───────────┬─────────┘
                      │
                      ▼
      ┌──────────────────────────────┐
      │ Django Deployment (replica=1)│  app:8000
      └───────────┬──────────────────┘
                  │
                  ▼
      ┌──────────────────────────────┐
      │ PostgreSQL Primary (stateful)│  5432 (demo: ephemeral)
      └──────────────────────────────┘
```

---

## Kubernetes Approach

- Bootstrap: Kubespray
  - container runtime: containerd
  - CNI: Calico
  - Single control‑plane (arvan‑k8s‑m1) + one worker (arvan‑k8s‑w1) for the demo
- Networking: private IPs for cluster traffic; public IP only for SSH/bootstrap
- Ingress: `ingress-nginx` Helm chart, stock config

Rationale:
- Kubespray provides predictable, idempotent provisioning without managed dependencies.
- containerd + Calico are Kubernetes defaults with wide ecosystem support.
- NGINX Ingress is ubiquitous and works well with Helm + DNS.

---

## Monitoring (Metrics + Dashboards)

Selected: `kube-prometheus-stack` (Prometheus, Alertmanager, Grafana) with defaults.

Diagram
```
Node/Pods (kube-state-metrics, cAdvisor, exporters)
    │              │
    └──── metrics ─┴──▶ Prometheus (TSDB)
                           │
                           └──▶ Grafana (dashboards)
```

Notes:
- Default values keep footprint and config minimal.
- Grafana admin password available from the chart’s secret; port‑forward for quick access.
---

## Logging (Application Logs)

Selected: Bitnami Elasticsearch + Kibana in stateless mode for the demo.

Notes:
- persistence is disabled for speed; restarts will clear indices.

---

## Application Delivery (CI/CD)

Selected: GitHub Actions with GHCR and a self‑hosted runner on `arvan-k8s-m1`.

Flow
```
Push to main
  │
  ▼
Self‑Hosted Runner (Docker)
  - docker build → ghcr.io/<repo>:latest
  - docker push
  │
  ▼
Deploy workflow
  - set kubeconfig from secret
  - helm upgrade --install crypto-exchange
```

Notes:
- Runner configured once; Docker Engine installed so images can build on host.
- Secrets used: KUBECONFIG, DJANGO_SECRET_KEY, POSTGRES_PASSWORD.
- Ingress routes `demo.iransre.ir` to the service; Helm values keep `replicaCount=1` and ephemeral DB for simplicity.

---

## Risks, Trade‑offs, and Next Steps

Known trade‑offs in the demo build:
- Single control‑plane node; no HA.
- No persistent storage by default.
- Minimal monitoring/alerting.
---

## References

- Cluster + Observability setup: `K8S_Setup/DOC1_CLUSTER_SETUP.md`
- App deployment and CI/CD: `Docs/APP_SETUP/DOC2_APP_DEPLOYMENT.md`

