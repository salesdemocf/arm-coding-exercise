# AWS — the terminal running terraform must already be authenticated (SSO,
# env vars, or a profile). This is the only AWS credential the workflow needs.
provider "aws" {
  region = var.aws_region
}

# kubernetes/helm authenticate to the cluster THIS module creates, via
# `aws eks get-token`. Using exec auth (rather than a kubeconfig file path)
# means the providers connect at apply time against the freshly created
# cluster, so the whole thing works in a single `terraform apply` — no
# chicken-and-egg with a kubeconfig that doesn't exist yet.
provider "kubernetes" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this.name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this.name, "--region", var.aws_region]
    }
  }
}

provider "octopusdeploy" {
  address  = var.octopus_server_url
  api_key  = var.octopus_api_key
  space_id = var.octopus_space_id
}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}
