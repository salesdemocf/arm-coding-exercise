# Plain service accounts — no AWS IRSA annotations needed. The agent/worker only
# talk outbound to Octopus; they don't call AWS APIs themselves.

resource "kubernetes_namespace" "octopus_agent" {
  count = var.install_octopus_agent ? 1 : 0

  metadata {
    name   = var.octopus_agent_namespace
    labels = { name = var.octopus_agent_namespace }
  }
}

resource "kubernetes_service_account" "octopus_agent" {
  count = var.install_octopus_agent ? 1 : 0

  metadata {
    name      = "octopus-agent"
    namespace = kubernetes_namespace.octopus_agent[0].metadata[0].name
  }
}

resource "kubernetes_namespace" "octopus_workers" {
  count = var.install_octopus_worker ? 1 : 0

  metadata {
    name   = var.octopus_worker_namespace
    labels = { name = var.octopus_worker_namespace }
  }
}

resource "kubernetes_service_account" "octopus_worker" {
  count = var.install_octopus_worker ? 1 : 0

  metadata {
    name      = "octopus-worker"
    namespace = kubernetes_namespace.octopus_workers[0].metadata[0].name
  }
}
