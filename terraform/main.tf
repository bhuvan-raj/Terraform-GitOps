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

resource "null_resource" "minikube_cluster" {
  provisioner "local-exec" {
    command = "minikube start --driver=docker --profile=my-gitops-cluster"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "minikube delete --profile=my-gitops-cluster"
  }
}

# ArgoCD Helm Chart
resource "helm_release" "argocd" {
  depends_on = [null_resource.minikube_cluster]
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  create_namespace = true
}

# Prometheus and Grafana Helm Chart
resource "helm_release" "prometheus" {
  depends_on = [null_resource.minikube_cluster]
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
        repoURL        = "https://github.com/kiranrajeev1/Terraform-GitOps.git" # Replace with your repo
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
