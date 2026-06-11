# Development, Staging, Production (from var.environments).
# allow_dynamic_infrastructure = true lets the Kubernetes Agent register itself
# as a deployment target into these environments.
#
# sort_order is set from each environment's index in var.environments so the
# global environment order is Development -> Staging -> Production. A plain
# toset() iterates alphabetically, which created them — and assigned sort_order —
# as Development, Production, Staging (Production ahead of Staging).

locals {
  # name => position, e.g. { "Development" = 0, "Staging" = 1, "Production" = 2 }
  environment_sort = { for idx, name in var.environments : name => idx }
}

resource "octopusdeploy_environment" "this" {
  for_each = local.environment_sort

  name                         = each.key
  description                  = "${each.key} — managed by Terraform"
  allow_dynamic_infrastructure = true
  use_guided_failure           = false
  sort_order                   = each.value
}

output "octopus_environment_ids" {
  description = "Octopus environment IDs"
  value       = { for k, v in octopusdeploy_environment.this : k => v.id }
}
