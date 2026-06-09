# ---------------------------------------------------------------------------
# Deployment process for the kubearchinspect project.
#
# A single "Upgrade a Helm Chart" step that:
#   - pulls the chart from the ECR chart feed (octopus-feeds.tf). The chart
#     version is selected at release creation, so the release version drives it.
#   - sets image.repository / image.tag via inline YAML values. Because the
#     workflow tags the image and chart with the same version and creates the
#     release with that version, image.tag = #{Octopus.Release.Number}.
#   - runs on the Kubernetes Agent target (matched by its target tags).
#
# NOTE: the v1 provider does not strongly-type Helm actions — the keys below are
# the raw Octopus action properties (confirmed against Octopus's own config-as-
# code example for Octopus.HelmChartUpgrade). If you tweak the step in the UI,
# re-export to confirm any added property keys. The one value most worth
# verifying against your Octopus version is primary_package.acquisition_location
# for an OCI chart pulled from an ECR feed.
# ---------------------------------------------------------------------------

resource "octopusdeploy_process" "kubearchinspect" {
  project_id = octopusdeploy_project.kubearchinspect.id
}

resource "octopusdeploy_process_step" "helm_upgrade" {
  process_id = octopusdeploy_process.kubearchinspect.id
  name       = "Upgrade kubearchinspect Helm chart"
  type       = "Octopus.HelmChartUpgrade"

  # Run on the Kubernetes Agent deployment target(s) matched by these tags.
  properties = {
    "Octopus.Action.TargetRoles" = join(",", var.octopus_agent_tags)
  }

  # The chart package. Version left empty -> selected at release creation, so
  # the release version (set by the GitHub workflow) drives which chart deploys.
  primary_package = {
    package_id           = local.chart_repo_name
    feed_id              = local.chart_feed_id
    acquisition_location = "ExecutionTarget"
  }

  execution_properties = {
    "Octopus.Action.RunOnServer"        = "False"
    "Octopus.Action.Helm.ClientVersion" = "V3"
    "Octopus.Action.Helm.ReleaseName"   = var.kubearchinspect_project_name
    "Octopus.Action.Helm.Namespace"     = "kube-system"
    "Octopus.Action.Helm.ResetValues"   = "True"

    # Inline values. ${...} is interpolated by Terraform (the ECR repo URL);
    # #{...} stays literal for Octopus to resolve at deploy time.
    "Octopus.Action.Helm.YamlValues" = <<-EOT
      image:
        repository: ${aws_ecr_repository.kubearchinspect.repository_url}
        tag: "#{Octopus.Release.Number}"
    EOT
  }

  depends_on = [
    octopusdeploy_project.kubearchinspect,
    octopusdeploy_aws_elastic_container_registry.chart,
  ]
}

output "kubearchinspect_process_id" {
  description = "Octopus deployment process ID for kubearchinspect"
  value       = octopusdeploy_process.kubearchinspect.id
}
