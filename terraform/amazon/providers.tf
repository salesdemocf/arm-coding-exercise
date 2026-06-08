# Point kubernetes/helm at the kubeconfig written by:
#   aws eks update-kubeconfig --name <cluster> --region <region> --alias <cluster>
# Set var.kube_context to that alias so Terraform targets the right cluster
# even if your current-context points elsewhere.

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context != "" ? var.kube_context : null
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context != "" ? var.kube_context : null
  }
}

provider "octopusdeploy" {
  address  = var.octopus_server_url
  api_key  = var.octopus_api_key
  space_id = var.octopus_space_id
}
