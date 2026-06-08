# ── Project group ─────────────────────────────────────────────────────────────

resource "octopusdeploy_project_group" "tooling" {
  name        = var.kubearchinspect_project_group_name
  description = "Platform verification and tooling projects"
}

# ── Lifecycle ─────────────────────────────────────────────────────────────────
# Reuse the built-in Default Lifecycle, which auto-includes all environments
# (Development -> Staging -> Production created in octopus-environments.tf).

data "octopusdeploy_lifecycles" "default" {
  partial_name = "Default Lifecycle"
  skip         = 0
  take         = 1
}

# ── Project ───────────────────────────────────────────────────────────────────

resource "octopusdeploy_project" "kubearchinspect" {
  name             = var.kubearchinspect_project_name
  description      = "Verifies all running container images support arm64 (Graviton) via Arm's kubearchinspect, run as a Kubernetes Job."
  project_group_id = octopusdeploy_project_group.tooling.id
  lifecycle_id     = data.octopusdeploy_lifecycles.default.lifecycles[0].id

  is_disabled                       = false
  tenanted_deployment_participation = "Untenanted"

  depends_on = [
    octopusdeploy_project_group.tooling,
    octopusdeploy_environment.this,
    data.octopusdeploy_lifecycles.default,
  ]

  lifecycle {
    ignore_changes = [connectivity_policy]
  }
}

# Default channel created with every project — handy to reference in pipelines.
data "octopusdeploy_channels" "default" {
  partial_name = "Default"
  project_id   = octopusdeploy_project.kubearchinspect.id
  skip         = 0
  take         = 1

  depends_on = [octopusdeploy_project.kubearchinspect]
}

output "kubearchinspect_project_id" {
  description = "Octopus project ID for kubearchinspect"
  value       = octopusdeploy_project.kubearchinspect.id
}

output "kubearchinspect_channel_id" {
  description = "Default channel ID for the kubearchinspect project"
  value       = data.octopusdeploy_channels.default.channels[0].id
}
