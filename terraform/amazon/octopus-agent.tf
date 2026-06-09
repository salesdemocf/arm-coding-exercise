# ── Octopus Kubernetes Agent — Deployment Target ──────────────────────────────
# Adapted from the local-k8s reference, but uses an EBS-backed StorageClass for
# the agent's shared filesystem instead of the in-cluster NFS server.

locals {
  agent_name = "${var.cluster_name}-agent"
}

resource "helm_release" "octopus_agent" {
  count = var.install_octopus_agent ? 1 : 0

  name             = local.agent_name
  repository       = "oci://registry-1.docker.io/octopusdeploy"
  chart            = "kubernetes-agent"
  version          = var.octopus_agent_chart_version
  namespace        = kubernetes_namespace.octopus_agent[0].metadata[0].name
  create_namespace = false
  atomic           = false
  timeout          = 600

  values = [
    yamlencode({
      agent = {
        acceptEula           = "Y"
        name                 = local.agent_name
        serverUrl            = var.octopus_server_url
        serverCommsAddresses = [var.octopus_polling_url]
        space                = var.octopus_space_name

        deploymentTarget = {
          enabled = true
          initial = {
            environments     = var.environments
            tags             = var.octopus_agent_tags
            defaultNamespace = var.octopus_agent_default_namespace
          }
        }

        worker = {
          enabled = false
        }
      }

      # EBS-backed shared filesystem. Providing storageClassName disables the
      # default in-cluster NFS server and creates a PVC against this class.
      persistence = {
        storageClassName = kubernetes_storage_class_v1.ebs_gp3.metadata[0].name
        size             = var.octopus_agent_storage_size
        nfs = {
          enabled = false
        }
      }

      kubernetesMonitor = {
        enabled = var.octopus_agent_k8s_monitor_enabled
        registration = var.octopus_agent_k8s_monitor_enabled ? {
          serverApiUrl = var.octopus_server_url
          spaceId      = var.octopus_space_id
          machineName  = local.agent_name
        } : {}
        monitor = var.octopus_agent_k8s_monitor_enabled ? {
          serverGrpcUrl = var.octopus_grpc_url
        } : {}
      }

      serviceAccount = {
        create = false
        name   = kubernetes_service_account.octopus_agent[0].metadata[0].name
      }

      resources = {
        requests = { cpu = "250m", memory = "512Mi" }
        limits   = { cpu = "500m", memory = "1Gi" }
      }
    })
  ]

  # Sensitive value passed separately so it doesn't land in the values yaml.
  set_sensitive {
    name  = "agent.serverApiKey"
    value = var.octopus_api_key
  }

  depends_on = [
    kubernetes_service_account.octopus_agent,
    kubernetes_storage_class_v1.ebs_gp3,
    octopusdeploy_environment.this,
  ]
}

# ── Deregister the deployment target from Octopus on destroy ───────────────────
# Requires curl + jq on the machine running terraform destroy.
#
# SECURITY: the Octopus API key is deliberately NOT stored in triggers. Unlike
# the provider config and the agent's set_sensitive value, trigger values are
# not treated as sensitive — they appear in plan output and sit readable in
# state. A destroy-time provisioner can only reference self/count/each (never
# var.*), so the non-secret values stay in triggers and the key is read from the
# environment at destroy time instead: it's the same TF_VAR_octopus_api_key you
# export to run Terraform, so it's already present in the shell. The key never
# enters triggers, plan output, or state via this resource.

resource "null_resource" "cleanup_octopus_agent" {
  count = var.install_octopus_agent ? 1 : 0

  triggers = {
    agent_name  = local.agent_name
    space_id    = var.octopus_space_id
    octopus_url = var.octopus_server_url
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # $TF_VAR_octopus_api_key is read from the environment, not from state.
      # $-prefixed names without braces are literal to Terraform and resolved by
      # the shell; $${...self...} values are interpolated by Terraform.
      if [ -z "$TF_VAR_octopus_api_key" ]; then
        echo "TF_VAR_octopus_api_key is not set in the environment — skipping agent deregistration."
        echo "Either re-run destroy with 'export TF_VAR_octopus_api_key=API-...' or remove the"
        echo "deployment target '${self.triggers.agent_name}' manually in Octopus."
        exit 0
      fi

      echo "Attempting to deregister agent '${self.triggers.agent_name}' from Octopus Deploy..."

      MACHINE_ID=$(curl -s -H "X-Octopus-ApiKey: $TF_VAR_octopus_api_key" \
        "${self.triggers.octopus_url}/api/${self.triggers.space_id}/machines/all" | \
        jq -r '.[] | select(.Name=="${self.triggers.agent_name}") | .Id' | head -n 1)

      if [ -n "$MACHINE_ID" ] && [ "$MACHINE_ID" != "null" ]; then
        echo "Found deployment target ID: $MACHINE_ID"
        curl -X DELETE -H "X-Octopus-ApiKey: $TF_VAR_octopus_api_key" \
          "${self.triggers.octopus_url}/api/${self.triggers.space_id}/machines/$MACHINE_ID"
        echo "Deployment target deregistered"
      else
        echo "Deployment target not found (may already be deleted)"
      fi
    EOT
    on_failure = continue
  }

  depends_on = [helm_release.octopus_agent]
}
