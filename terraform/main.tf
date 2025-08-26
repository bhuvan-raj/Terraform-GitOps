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

# Provider configurations
provider "kubernetes" {
  config_path = "/tmp/runner_home/.kube/config"
  config_context = "my-gitops-cluster"
}

provider "helm" {
  kubernetes {
    config_path = "/tmp/runner_home/.kube/config"
    config_context = "my-gitops-cluster"
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
  depends_on       = [null_resource.kind_cluster]
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
}

# Prometheus and Grafana Helm Chart
resource "helm_release" "prometheus" {
  depends_on       = [null_resource.kind_cluster]
  name             = "prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 1200 # 20 minutes
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
        repoURL        = "https://github.com/kiranrajeev1/Terraform-GitOps.git"
        targetRevision = "main"
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