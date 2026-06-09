# ---------------------------------------------------------------------------
# Octopus package feeds — BOTH are AWS ECR feeds.
#
# Why not an octopusdeploy_helm_feed for the chart? That resource only accepts
# a static username/password. ECR registry auth needs the ephemeral token from
# ecr:GetAuthorizationToken (username "AWS" + a token that rotates every ~12h),
# so a static-cred Helm feed can't authenticate to ECR at all. The AWS ECR feed
# type calls GetAuthorizationToken and refreshes the token automatically, and —
# since Octopus added OCI Helm support — the "Upgrade a Helm Chart" step can use
# a container-registry feed as its chart source. So:
#
#   image feed  -> the kubearchinspect container image (release version source)
#   chart feed  -> the kubearchinspect Helm chart, pushed to ECR as an OCI artifact
#
# One ECR feed could technically serve both repositories; they're split here for
# clarity and because you asked for two feeds.
#
# Auth: static IAM access/secret keys from the scoped CI user (Octopus refreshes
# the ECR token from them). For a secretless setup, this same resource supports
# an `oidc_authentication { role_arn = ... }` block instead — see the provider
# docs; it needs an IAM role trusting Octopus's OIDC issuer.
# ---------------------------------------------------------------------------

# Credentials for the feeds. Default to the CI push user created in ecr.tf;
# override these when create_ecr_push_user = false.
variable "ecr_feed_access_key" {
  description = "AWS access key for the Octopus ECR feeds (used when create_ecr_push_user = false)"
  type        = string
  default     = ""
}

variable "ecr_feed_secret_key" {
  description = "AWS secret key for the Octopus ECR feeds (used when create_ecr_push_user = false)"
  type        = string
  sensitive   = true
  default     = ""
}

locals {
  feed_access_key = var.create_ecr_push_user ? aws_iam_access_key.ecr_push[0].id : var.ecr_feed_access_key
  feed_secret_key = var.create_ecr_push_user ? aws_iam_access_key.ecr_push[0].secret : var.ecr_feed_secret_key
}

resource "octopusdeploy_aws_elastic_container_registry" "image" {
  name       = "${var.ecr_repository_name} image (ECR)"
  region     = var.aws_region
  access_key = local.feed_access_key
  secret_key = local.feed_secret_key
}

resource "octopusdeploy_aws_elastic_container_registry" "chart" {
  name       = "${var.ecr_repository_name} chart (ECR OCI Helm)"
  region     = var.aws_region
  access_key = local.feed_access_key
  secret_key = local.feed_secret_key
}

locals {
  image_feed_id = octopusdeploy_aws_elastic_container_registry.image.id
  chart_feed_id = octopusdeploy_aws_elastic_container_registry.chart.id
}

output "octopus_image_feed_id" {
  description = "Octopus feed ID for the kubearchinspect image"
  value       = local.image_feed_id
}

output "octopus_chart_feed_id" {
  description = "Octopus feed ID for the kubearchinspect Helm chart"
  value       = local.chart_feed_id
}
