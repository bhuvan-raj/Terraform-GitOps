terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# Provider configurations
# This is a temporary provider config for the `null` resource.
# The Kubernetes and Helm providers will be configured in `tools.tf`.
provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

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
