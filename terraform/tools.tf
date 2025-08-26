provider "kubernetes" {
  # This tells the provider to use the kubeconfig file created by kind
  config_path = "~/.kube/config" 
}
#... (your helm_release and kubernetes_manifest resources)
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
        repoURL        = "https://github.com/bhuvan-raj/Terraform-GitOps.git" # Replace with your repo
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
