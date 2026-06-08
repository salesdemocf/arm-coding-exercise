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

resource "null_resource" "cleanup_octopus_agent" {
  count = var.install_octopus_agent ? 1 : 0

  triggers = {
    agent_name  = local.agent_name
    space_id    = var.octopus_space_id
    octopus_url = var.octopus_server_url
    api_key     = var.octopus_api_key
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Attempting to deregister agent '${self.triggers.agent_name}' from Octopus Deploy..."

      MACHINE_ID=$(curl -s -H "X-Octopus-ApiKey: ${self.triggers.api_key}" \
        "${self.triggers.octopus_url}/api/${self.triggers.space_id}/machines/all" | \
        jq -r '.[] | select(.Name=="${self.triggers.agent_name}") | .Id' | head -n 1)

      if [ -n "$MACHINE_ID" ] && [ "$MACHINE_ID" != "null" ]; then
        echo "Found deployment target ID: $MACHINE_ID"
        curl -X DELETE -H "X-Octopus-ApiKey: ${self.triggers.api_key}" \
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
