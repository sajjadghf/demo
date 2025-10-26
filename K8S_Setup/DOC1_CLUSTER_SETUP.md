# Part 1 — Kubernetes Cluster + Prometheus + Elasticsearch/Kibana (Stateless) Setup

This document explains exactly how I provisioned a minimal Kubernetes cluster on two ArvanCloud VMs using **Kubespray** (CRI: `containerd`, CNI: `calico`), added **NGINX Ingress**, and deployed **Prometheus (kube-prometheus-stack)** and **Elasticsearch + Kibana** via Helm. It is intentionally simple and reproducible so reviewers can follow along quickly.

---

## 0) Topology & Goals

**Cloud:** ArvanCloud  
**Nodes (2×):** 4 vCPU, 8 GB RAM

| Role | Hostname       | Public IP       | Private IP    | Notes |
|------|----------------|-----------------|---------------|-------|
| CP/ETCD | `arvan-k8s-m1` | `185.204.168.86` | `192.168.1.10` | Kubernetes control‑plane + etcd |
| Worker | `arvan-k8s-w1` | `185.204.170.77` | `192.168.1.6`  | Kubernetes worker |

**Objective:**  
- Use an **internal (private) network** for cluster traffic; public IPs only for SSH/bootstrap.  
- Keep **Prometheus** deployment **default/minimal**.  
- Deploy **Elasticsearch+Kibana** in a **stateless mode** (no PV/PVC) to demonstrate a quick ELK install without persistence.

> ⚠️ The ELK stack here is **not** production-ready (persistence is disabled by design for speed & simplicity).

---

## 1) Prerequisites 

From a control machine:
- SSH to both nodes as `ubuntu` is available.
- Sudo is allowed (I used `-b -k -K` with Ansible for become & password prompts).
- Nodes have a **private NIC**/address configured; we want Kubernetes to bind to these **private IPs**.

---

## 2) Kubernetes with Kubespray (containerd + calico)

### 2.1 Clone & prepare Kubespray
```bash
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
pip install -r requirements.txt
```

### 2.2 Inventory
I started from the sample inventory and edited the host/IPs so Kubernetes uses the **private IPs**:

```ini
# inventory/sample/inventory.ini

[kube_control_plane]
arvan-k8s-m1 ansible_host=185.204.168.86 ip=192.168.1.10 ansible_user=ubuntu etcd_member_name=etcd1

[etcd:children]
kube_control_plane

[kube_node]
arvan-k8s-w1 ansible_host=185.204.170.77 ip=192.168.1.6 ansible_user=ubuntu
```

> `ansible_host` = SSH/public IP, `ip` = private/cluster IP

Kubespray defaults already suit the task:
- **CRI:** `containerd`
- **CNI:** `calico`

(Alternatively you can pin them in `inventory/<your-inventory>/group_vars/k8s_cluster/k8s-cluster.yml`:
```yaml
container_manager: containerd
kube_network_plugin: calico
```
)

### 2.3 Bootstrap the cluster
```bash
# Run from kubespray root
ansible-playbook -i inventory/sample/inventory.ini cluster.yml -b -vvv -k -K
```
---

## 3) NGINX Ingress Controller

A standard Helm install:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

Check:
```bash
kubectl -n ingress-nginx get deploy,svc,pods
```
---

## 4) Prometheus (kube-prometheus-stack) — **default/minimal**

Per the task requirement to keep monitoring **minimal** and **simple**, I deployed the **defaults** of the community stack:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitor prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
```

**Access (quickest option):**
```bash
kubectl -n monitoring port-forward svc/monitor-kube-prometheus-stack-grafana 3000:80
```

Get the Grafana admin password:
```bash
kubectl get secret -n monitoring -o name | grep grafana
kubectl get secret <grafana-secret-name> -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

---

## 5) Elasticsearch + Kibana (Bitnami) — **stateless mode**

To showcase a second installation approach and keep startup **fast** with **no storage dependency**, I used the Bitnami chart locally with a minimal, **persistence-disabled** values file.

### 5.1 Get the chart source
```bash
git clone https://github.com/bitnami/charts.git
cp -r charts/bitnami/elasticsearch ./elasticsearch
cd elasticsearch
```

### 5.2 Custom values (no PV/PVC)
Create `custom_values.yaml`:

```yaml
# custom_values.yaml
# Minimal, single-replica, stateless deployment (NOT for production)

master:
  replicaCount: 1
  persistence:
    enabled: false

data:
  replicaCount: 1
  persistence:
    enabled: false

coordinating:
  replicaCount: 1
  persistence:
    enabled: false

ingest:
  enabled: true

kibana:
  enabled: true
  replicaCount: 1
  persistence:
    enabled: false
```

### 5.3 Install / upgrade
```bash
helm dependency build
helm upgrade --install elk . -n elastic-stack --create-namespace -f custom_values.yaml
```

Validate:
```bash
kubectl -n elastic-stack get pods -w
```

Quick access to Kibana:
```bash
kubectl -n elastic-stack port-forward svc/elk-kibana 5601:5601
```

> Because persistence is **disabled**, any pod restarts will clear indices. This is expected for a **demo**.

---

## 6) Why two installation modes?

- **Prometheus:** Installed with **default values** to reflect the “minimal and simple” requirement and keep the footprint small.
- **Elasticsearch/Kibana:** Demonstrates a **stateless** path (no PV/PVC) so the stack comes up quickly even without storage provisioning. This is **not** production-grade but is perfect for the challenge demo.

---

## 7) GitHub Actions runner on `arvan-k8s-m1`

To allow GitHub Actions jobs to target the control-plane node, I stood up a self-hosted runner under the default runner group:

```bash
mkdir actions-runner && cd actions-runner

curl -o actions-runner-linux-x64-2.329.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.329.0/actions-runner-linux-x64-2.329.0.tar.gz
echo "194f1e1e4bd02f80b7e9633fc546084d8d4e19f3928a324d512ea53430102e1d  actions-runner-linux-x64-2.329.0.tar.gz" | shasum -a 256 -c
tar xzf ./actions-runner-linux-x64-2.329.0.tar.gz

./config.sh --url https://github.com/sajjadghf/demo --token ***REDACTED***
```

```bash
./run.sh

√ Connected to GitHub
Current runner version: '2.329.0'
2025-10-26 19:44:30Z: Listening for Jobs
```

---

## Command History (as executed)

```bash
# Kubespray
ansible-playbook -i inventory/sample/inventory.ini cluster.yml -b -vvv -k -K

# NGINX Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace

# Prometheus (minimal/default)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitor prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace

# Elasticsearch + Kibana (Bitnami, stateless)
git clone https://github.com/bitnami/charts.git
cp -r charts/bitnami/elasticsearch .
cd elasticsearch
vim custom_values.yaml
helm dependency build
helm upgrade --install elk . -n elastic-stack -f custom_values.yaml
```
