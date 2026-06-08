# Development, Staging, Production (from var.environments).
# allow_dynamic_infrastructure = true lets the Kubernetes Agent register itself
# as a deployment target into these environments.

resource "octopusdeploy_environment" "this" {
  for_each = toset(var.environments)

  name                         = each.value
  description                  = "${each.value} — managed by Terraform"
  allow_dynamic_infrastructure = true
  use_guided_failure           = false

  lifecycle {
    ignore_changes = [sort_order]
  }
}

output "octopus_environment_ids" {
  description = "Octopus environment IDs"
  value       = { for k, v in octopusdeploy_environment.this : k => v.id }
}
