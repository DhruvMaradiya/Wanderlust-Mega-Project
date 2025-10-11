# Wanderlust Mega Project – DevSecOps + GitOps on Google Cloud

> **From a simple MERN travel blog → a full-fledged, secure, automated CI/CD pipeline on Google Kubernetes Engine (GKE)**

[![Wanderlust Preview](https://github.com/krishnaacharyaa/wanderlust/assets/116620586/17ba9da6-225f-481d-87c0-5d5a010a9538)](https://github.com/krishnaacharyaa/wanderlust)

## 🌍 Project Origin & Our Twist

- **Original App**: Forked from [`krishnaacharyaa/wanderlust`](https://github.com/krishnaacharyaa/wanderlust) — a standard MERN stack travel blog (MongoDB, Express, React, Node.js + Redis).
- **Our Focus**: **Zero changes to the application code**. All effort was invested in building a **production-grade DevSecOps and GitOps pipeline** on **Google Cloud Platform (GCP)**.
- **Cloud Choice**: While the reference project uses **AWS EKS**, this implementation is **100% GCP-native**, using **GKE**, **Compute Engine**, and **Cloud IAM**.

---

## 🚀 What We Built

| Layer          | Tool / Service                          | Purpose                                     |
|----------------|------------------------------------------|---------------------------------------------|
| **Source Code**| GitHub                                   | Central code repository                     |
| **CI**         | Jenkins (Master + Dedicated Worker VM)   | Orchestrate build, test, scan, and push     |
| **Container**  | Docker                                   | Package frontend & backend                  |
| **Security**   | OWASP Dependency-Check, SonarQube, Trivy | SCA, SAST, and container image scanning     |
| **Registry**   | Docker Hub                               | Store built images                          |
| **CD / GitOps**| ArgoCD                                   | Sync desired state from Git to Kubernetes   |
| **Orchestration**| Google Kubernetes Engine (GKE)         | Run the application at scale                |
| **Monitoring** | Prometheus + Grafana (via Helm)          | Observe cluster and app health              |
| **Infra as Code**| Terraform                             | Provision Jenkins Master VM                 |

---

## 🎯 End-to-End Pipeline Flow

1. **Trigger**: Manual `Build with Parameters` in Jenkins (supply `FRONTEND_TAG` & `BACKEND_TAG`).
2. **Code Checkout**: Pull latest from `main` branch.
3. **Security Scans**:
   - **OWASP**: Scan for vulnerable dependencies.
   - **SonarQube**: Static code analysis & quality gates.
   - **Trivy**: Scan Docker images for OS/library vulnerabilities.
4. **Build & Push**:
   - Build Docker images for frontend & backend.
   - Push to **your** Docker Hub (`dhruv4810/...`).
5. **GitOps Update**:
   - Auto-commit new image tags to `kubernetes/*.yaml`.
   - Push changes back to GitHub.
6. **Deployment**:
   - **ArgoCD** detects Git change and syncs the cluster.
   - Rolling updates ensure zero downtime.
7. **Notification**: Email sent on success or failure.

---

## 🛠️ Step-by-Step Setup Commands

> **Note**: All commands were executed from a **Jenkins Master VM** provisioned via Terraform in GCP.

### 0. Provision Jenkins Master VM (Terraform)

```bash
cd terraform/
terraform init
terraform apply -auto-approve
```

### 1. Setup Jenkins Master

```bash
# Install prerequisites
sudo apt update && sudo apt install -y openjdk-17-jre docker.io
sudo usermod -aG docker $USER && newgrp docker

# Add Jenkins repo and install
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list
sudo apt update && sudo apt install -y jenkins
sudo systemctl enable --now jenkins
```

### 2. Create GKE Cluster

```bash
# Authenticate and install tools
gcloud auth login
gcloud components install kubectl gke-gcloud-auth-plugin

# Create cluster
gcloud container clusters create wanderlust \
  --zone=us-central1-a \
  --cluster-version=1.33 \
  --num-nodes=2 \
  --machine-type=e2-standard-2 \
  --disk-size=30 \
  --enable-ip-alias \
  --quiet

# Configure kubectl
gcloud container clusters get-credentials wanderlust --zone=us-central1-a
```

### 3. Create Jenkins Worker VM

```bash
# Create the VM
gcloud compute instances create jenkins-worker \
  --zone=us-central1-a \
  --machine-type=e2-standard-2 \
  --boot-disk-size=30 \
  --image-family=ubuntu-2204-lts \
  --scopes=cloud-platform

# Install Java & Docker on the worker
gcloud compute ssh jenkins-worker --zone=us-central1-a --command="
  sudo apt update && sudo apt install -y openjdk-17-jre docker.io &&
  sudo usermod -aG docker \$(whoami) && sudo systemctl enable --now docker"
```

### 4. Install & Configure ArgoCD

```bash
# Deploy ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Expose ArgoCD UI via NodePort
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

# Get password and login (run on master VM)
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Password: $ARGOCD_PASSWORD"

# Add GKE cluster to ArgoCD
argocd cluster add $(kubectl config current-context) --name wanderlust-gke-cluster
```

### 5. Setup Monitoring (Prometheus + Grafana)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
kubectl create namespace prometheus
helm install stable prometheus-community/kube-prometheus-stack -n prometheus

# Expose services via NodePort
kubectl edit svc stable-kube-prometheus-sta-prometheus -n prometheus
kubectl edit svc stable-grafana -n prometheus

# Get Grafana password
kubectl get secret --namespace prometheus stable-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

### 6. Run SonarQube

```bash
docker run -d --name sonarqube -p 9000:9000 sonarqube:lts-community
# Access at http://<JENKINS_MASTER_IP>:9000
# Default creds: admin/admin → change password & generate token
```

### 7. Critical Fixes Applied

#### 🔧 MongoDB & Redis `CreateContainerError`
**Problem**: GKE's read-only root filesystem prevented container startup.
**Solution**: Added `subPath` to volume mounts.

```bash
kubectl patch deployment mongo-deployment -n wanderlust --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts/0/subPath", "value": "db"}]'

kubectl patch deployment redis-deployment -n wanderlust --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts/0/subPath", "value": "redis"}]'
```

#### 🔧 Immutable PVC Error
**Problem**: HostPath PV in Git conflicted with GKE’s dynamic provisioning.
**Solution**: Deleted the static PV and let GKE auto-provision a GCE Persistent Disk.

```bash
kubectl delete pvc mongo-pvc -n wanderlust
# ArgoCD then recreated a healthy, dynamic PVC
```

#### 🔧 Jenkins Disk Full & Permission Errors
**Problem**: Builds failed due to disk space and file permission issues.
**Solution**:
```bash
sudo journalctl --vacuum-time=1d
sudo mkdir -p /var/lib/jenkins/workspace
sudo chown -R jenkins:jenkins /var/lib/jenkins
sudo chmod 755 /var/lib/jenkins/workspace
sudo systemctl restart jenkins
```

---

## 🔒 Security & Credentials

All secrets are managed securely in Jenkins:
- **Docker Hub**: `usernamePassword` credential with ID `docker`.
- **SonarQube**: `Secret text` credential with your generated token (ID `sonar-token`).
- **GitHub**: `gitUsernamePassword` for committing version updates.
- **GCP**: Service account key stored as a `Secret file` for `gcloud` auth in pipelines.

---

## 🌐 Access URLs

| Service       | URL                                      | Credentials                     |
|---------------|------------------------------------------|---------------------------------|
| **Application** | `http://<NODE_PUBLIC_IP>:31000`        | N/A                             |
| **ArgoCD**      | `http://<NODE_PUBLIC_IP>:31399`        | `admin` / `<initial-password>` |
| **Grafana**     | `http://<NODE_PUBLIC_IP>:31532`        | `admin` / `prom-operator`      |
| **SonarQube**   | `http://<JENKINS_MASTER_IP>:9000`      | `admin` / `your-password`      |

> **To get your node IP**:
> ```bash
> kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}'
> ```

---

## 💸 Cost & Cleanup

### Estimated Cost (GCP)
- **2-node GKE cluster** (e2-standard-2): ~₹45/hour
- **2 VMs** (Jenkins Master + Worker): ~₹25/hour
- **Total**: < ₹600 for an 8-hour overnight run.
- With ₹20,000 credits: **~28 full days** of runtime.

### Full Cleanup
```bash
# Destroy Terraform-managed resources (Jenkins VM, network, etc.)
cd terraform/
terraform destroy -auto-approve

# Delete GKE cluster (created manually)
gcloud container clusters delete wanderlust --zone=us-central1-a --quiet

# Delete manual firewall rule
gcloud compute firewall-rules delete allow-nodeport --quiet
```

---

## ✅ What Works

- ✅ Full CI/CD/GitOps loop from code commit to production deployment.
- ✅ Security gates block vulnerable code or images.
- ✅ ArgoCD ensures the cluster state always matches Git.
- ✅ Real-time monitoring with Prometheus and Grafana.
- ✅ Parameterized builds for flexible tagging.

## 🚧 Known Limitations (Future Work)

- MongoDB runs as a single instance (no replica set).
- Secrets are in Jenkins (not HashiCorp Vault or Sealed Secrets).
- No TLS/SSL (HTTP only).
- No HPA/VPA for autoscaling.

---

## 📸 Screenshots

- Green Jenkins pipeline

- ArgoCD application sync status

- Grafana dashboard

- Wanderlust app running in browser

---

## 🙌 Conclusion

This project demonstrates a **real-world, secure, and automated DevOps workflow** on GCP. By leveraging Jenkins for CI and ArgoCD for GitOps CD, we’ve created a system that is **reproducible, auditable, and scalable** — all without modifying a single line of the original application.

**Star this repo if it helped you learn DevSecOps on GCP!**

