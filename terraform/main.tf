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
# Provision a Kind Cluster
resource "null_resource" "kind_cluster" {
  provisioner "local-exec" {
    command = "sudo sh -c '/home/bubu/bin/kind create cluster --name my-gitops-cluster'"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "sudo sh -c '/home/bubu/bin/kind delete cluster --name my-gitops-cluster'"
  }
}
