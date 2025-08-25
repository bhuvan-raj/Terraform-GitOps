# GitOps CI/CD Pipeline with Kind, ArgoCD,Terraform and Prometheus

This project provides a complete, automated pipeline for deploying a web application using the GitOps methodology. It uses a combination of modern DevOps tools to demonstrate a robust and scalable continuous deployment workflow.

## Project Overview

This project automates the entire application lifecycle, from code changes to a deployed, monitored application. The pipeline is built on the following components:

* **GitHub Actions**: The Continuous Integration (CI) engine that orchestrates the entire workflow.
* **Terraform**: Manages the infrastructure as code, provisioning a Kubernetes cluster and installing core tools.
* **Kind**: A lightweight Kubernetes cluster run inside Docker, perfect for local development and CI/CD environments.
* **Trivy**: Scans the Docker image for vulnerabilities before deployment.
* **ArgoCD**: The GitOps controller that automatically synchronizes the desired state from the Git repository to the Kubernetes cluster.
* **Prometheus & Grafana**: The monitoring stack for collecting and visualizing application and infrastructure metrics.

## Project Structure

The repository is organized to separate different components logically.

```

.
├── .github/workflows/
│   └── main.yaml               \# GitHub Actions CI/CD workflow
├── app/
│   ├── main.py                 \# Sample Python web application with metrics
│   ├── Dockerfile
│   └── requirements.txt
├── manifests/
│   └── my-app/
│       ├── deployment.yaml     \# Kubernetes manifest for the app
│       └── service.yaml        \# Service to expose the app
├── terraform/
│   └── main.tf                 \# Terraform code to provision kind and tools
└── README.md

````

***

## Getting Started

### Prerequisites

* **Git**
* **Docker Desktop** (or Docker Engine)
* **Kind** CLI
* **kubectl**
* **Terraform** CLI
* A **GitHub** account and a new, empty repository.
* A **Docker Hub** account.
* A self-hosted GitHub Actions runner with the above tools installed.
* A GitHub Personal Access Token (PAT) with `repo` and `workflow` scopes.
* Docker Hub Access Token (or password).

### Step 1: Set up the Repository and Code

1.  Clone your empty GitHub repository.
2.  Create the file structure as shown above.
3.  Add the provided Python application, Dockerfile, Kubernetes manifests, and Terraform configuration to their respective directories.
4.  Commit and push the initial code to your repository's `main` branch.

### Step 2: Configure GitHub Actions Secrets

1.  In your GitHub repository, go to **Settings** > **Secrets and variables** > **Actions**.
2.  Add the following repository secrets:
    * `DOCKERHUB_USERNAME`: Your Docker Hub username.
    * `DOCKERHUB_TOKEN`: Your Docker Hub Access Token.

### Step 3: Run the Pipeline

The pipeline is fully automated and will be triggered by a push to the `main` branch or a manual trigger from the GitHub Actions tab. 

1.  Make a small change to `app/main.py` (e.g., change the greeting message).
2.  Commit and push the change to the `main` branch.
3.  Navigate to the **Actions** tab in your GitHub repository to watch the workflow run.

The workflow will perform the following steps:

1.  **Build & Scan**: Builds the Docker image and runs a Trivy scan. If a critical or high-severity vulnerability is found, the build will fail.
2.  **Provision Infrastructure**: Runs Terraform to create a **Kind** cluster, and then installs **ArgoCD** and the **kube-prometheus-stack** using Helm.
3.  **Update Manifests**: Updates the `deployment.yaml` with the new, scanned Docker image tag (based on the commit SHA).
4.  **Git Push**: Commits and pushes the updated manifest file back to the repository.

### Step 4: Access and Verify

After the workflow completes, you can access your tools to verify the deployment.

1.  **Access ArgoCD**:
    * Port-forward to the ArgoCD server service:
        ```bash
        kubectl -n argocd port-forward svc/argocd-server 8080:443
        ```
    * Get the initial admin password:
        ```bash
        kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
        ```
    * Open `https://localhost:8080` in your browser. Log in with `admin` and the retrieved password. You will see your application, `my-gitops-app`, automatically synced and healthy.

2.  **Access the Application**:
    * Find the NodePort assigned to your application's service:
        ```bash
        kubectl get svc my-app-service
        ```
    * Get the IP address of your Kind cluster node:
        ```bash
        kubectl get nodes -o wide
        ```
    * Open a web browser and navigate to `http://<node-ip>:<node-port>` to see your deployed application.

3.  **Access Grafana**:
    * Port-forward to the Grafana service:
        ```bash
        kubectl -n monitoring port-forward svc/prometheus-stack-grafana 3000:80
        ```
    * Open `http://localhost:3000` in your browser. The default credentials are `admin`/`prom-operator`.
    * Explore the pre-built dashboards or create a custom one to monitor your application's metrics.

This project demonstrates a fully automated, secure, and observable GitOps workflow that can be easily adapted for more complex applications and production environments.

### **Files**

Here are the files to be placed in the respective directories.

#### **1. `app/main.py`**

```python
from flask import Flask
from prometheus_client import Gauge, make_wsgi_app
from werkzeug.middleware.dispatcher import DispatcherMiddleware
from flask import request

app = Flask(__name__)
REQUEST_COUNT = Gauge('http_requests_total', 'Total HTTP Requests')

@app.route('/')
def hello_world():
    REQUEST_COUNT.inc()
    return 'Hello, World! I am a GitOps application.'

app.wsgi_app = DispatcherMiddleware(app.wsgi_app, {
    '/metrics': make_wsgi_app()
})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

#### **2. `app/requirements.txt`**

```
Flask==2.3.2
prometheus_client==0.17.1
```

#### **3. `app/Dockerfile`**

```dockerfile
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "main.py"]
```

#### **4. `manifests/my-app/deployment.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-deployment
  labels:
    app: my-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "5000"
    spec:
      containers:
      - name: my-app
        image: your-docker-hub-username/my-app:v1.0.0 # This tag is updated by CI
        ports:
        - containerPort: 5000
```

#### **5. `manifests/my-app/service.yaml`**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
spec:
  type: NodePort
  selector:
    app: my-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 5000
```

#### **6. `terraform/main.tf`**

```terraform
terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.22"
    }
  }
}

# Provision a Kind Cluster
resource "null_resource" "kind_cluster" {
  provisioner "local-exec" {
    command = "sudo sh -c 'kind create cluster --name my-gitops-cluster'"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "sudo sh -c 'kind delete cluster --name my-gitops-cluster'"
  }
}

# ArgoCD Helm Chart
resource "helm_release" "argocd" {
  depends_on = [null_resource.kind_cluster]
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  create_namespace = true
}

# Prometheus and Grafana Helm Chart
resource "helm_release" "prometheus" {
  depends_on = [null_resource.kind_cluster]
  name       = "prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  create_namespace = true
}

# ArgoCD Application
resource "kubernetes_manifest" "my_app_argocd" {
  depends_on = [helm_release.argocd]
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "my-gitops-app"
      namespace = "argocd"
    }
    spec = {
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "default"
      }
      project = "default"
      source = {
        repoURL        = "https://github.com/your-username/your-repo-name.git" # Replace with your repo
        targetRevision = "HEAD"
        path           = "manifests/my-app"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }
}
```

#### **7. `.github/workflows/main.yaml`**

```yaml
name: GitOps CD Pipeline with Local Runner

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  build-and-deploy:
    # Use 'self-hosted' to specify a local runner
    runs-on: bubu
    steps:
      - name: Checkout Code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Log in to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build and Push Docker image
        id: build_push
        uses: docker/build-push-action@v4
        with:
          context: ./app
          push: true
          tags: |
            ${{ secrets.DOCKERHUB_USERNAME }}/my-app:${{ github.sha }}
            ${{ secrets.DOCKERHUB_USERNAME }}/my-app:latest

      - name: Run Trivy scan on Docker image
        run: |
          IMAGE_NAME=${{ secrets.DOCKERHUB_USERNAME }}/my-app:${{ github.sha }}
          trivy image --exit-code 1 --severity HIGH,CRITICAL $IMAGE_NAME

      - name: Terraform Init
        run: terraform init
        working-directory: ./terraform

      - name: Terraform Apply - Create Cluster
        run: terraform apply -auto-approve -target=null_resource.kind_cluster
        working-directory: ./terraform
        env:
          HOME: /tmp/runner_home
          KUBECONFIG: /tmp/runner_home/.kube/config
      
      - name: Terraform Apply - Install Tools
        run: terraform apply -auto-approve
        working-directory: ./terraform
        env:
          KUBECONFIG: /tmp/runner_home/.kube/config


      - name: Update Kubernetes Manifest with new image tag
        run: |
          # Note: 'sed -i' may behave differently on macOS/Linux.
          # Use 'sed -i.bak' for macOS compatibility
          sed -i 's|image: .*|image: ${{ secrets.DOCKERHUB_USERNAME }}/my-app:${{ github.sha }}|' manifests/my-app/deployment.yaml

      - name: Commit and Push changes to manifests
        run: |
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add manifests/my-app/deployment.yaml
          git commit -m "Update application image to new build ${{ github.sha }}" || echo "No changes to commit"
          git push
```
