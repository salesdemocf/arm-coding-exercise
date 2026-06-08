# ── Cluster / kubeconfig ──────────────────────────────────────────────────────

variable "cluster_name" {
  description = "EKS cluster name (used to name the agent/worker)"
  type        = string
  default     = "dvb-eks-arm"
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig (e.g. ~/.kube/config after `aws eks update-kubeconfig`)"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubeconfig context to use. Leave empty to use the current-context. Matches the --alias passed to update-kubeconfig in the cluster Terraform."
  type        = string
  default     = ""
}

# ── EBS storage ───────────────────────────────────────────────────────────────

variable "cluster_is_auto_mode" {
  description = <<-EOT
    true  -> EKS Auto Mode cluster. The EBS CSI controller is built in; we ONLY
             create a StorageClass using the ebs.csi.eks.amazonaws.com provisioner.
    false -> Standard EKS. We install the aws-ebs-csi-driver Helm chart (see the
             IAM note in ebs-storage.tf) and use the ebs.csi.aws.com provisioner.
  EOT
  type        = bool
  default     = true
}

variable "ebs_storage_class_name" {
  description = "Name of the gp3 StorageClass created for the Octopus agent/worker PVCs"
  type        = string
  default     = "ebs-gp3"
}

variable "ebs_set_default_storage_class" {
  description = "Mark the gp3 StorageClass as the cluster default (Auto Mode ships no default StorageClass)"
  type        = bool
  default     = true
}

variable "install_ebs_csi_driver" {
  description = "Install aws-ebs-csi-driver Helm chart. MUST stay false on Auto Mode clusters (driver is built in). Only set true for standard EKS."
  type        = bool
  default     = false
}

variable "ebs_csi_driver_chart_version" {
  description = "aws-ebs-csi-driver Helm chart version (only used when install_ebs_csi_driver = true)"
  type        = string
  default     = "2.35.1"
}

# ── Octopus connection ────────────────────────────────────────────────────────

variable "octopus_server_url" {
  description = "https://your-instance.octopus.app"
  type        = string
}

variable "octopus_polling_url" {
  description = "Polling comms address, e.g. https://your-instance.octopus.app or the dedicated polling endpoint for Octopus Cloud"
  type        = string
}

variable "octopus_grpc_url" {
  description = "gRPC URL used by the Kubernetes monitor, e.g. grpcs://your-instance.octopus.app:443 (only needed if k8s monitoring is enabled)"
  type        = string
  default     = ""
}

variable "octopus_api_key" {
  description = "API-XXXXXXXX"
  type        = string
  sensitive   = true
}

variable "octopus_space_id" {
  description = "Octopus space ID, e.g. Spaces-1"
  type        = string
}

variable "octopus_space_name" {
  description = "Octopus space display name (the agent chart wants the name)"
  type        = string
  default     = "Default"
}

# ── Octopus project (kubearchinspect) ─────────────────────────────────────────

variable "kubearchinspect_project_group_name" {
  description = "Project group to hold the kubearchinspect project"
  type        = string
  default     = "Platform Tooling"
}

variable "kubearchinspect_project_name" {
  description = "Name of the Octopus project for kubearchinspect"
  type        = string
  default     = "kubearchinspect"
}

# ── Octopus environments ──────────────────────────────────────────────────────

variable "environments" {
  description = "Environments to create and register the deployment target into"
  type        = list(string)
  default     = ["Development", "Staging", "Production"]
}

# ── Octopus Kubernetes Agent (deployment target) ──────────────────────────────

variable "install_octopus_agent" {
  description = "Install the Octopus Kubernetes Agent as a deployment target"
  type        = bool
  default     = true
}

variable "octopus_agent_chart_version" {
  description = "octopusdeploy/kubernetes-agent Helm chart version (v2.x)"
  type        = string
  default     = "2.36.0"
}

variable "octopus_agent_namespace" {
  type    = string
  default = "octopus-agent"
}

variable "octopus_agent_tags" {
  description = "Target tags assigned to the deployment target (at least one required)"
  type        = list(string)
  default     = ["kubernetes", "eks-arm"]
}

variable "octopus_agent_default_namespace" {
  description = "Default namespace the agent deploys workloads into"
  type        = string
  default     = "default"
}

variable "octopus_agent_storage_size" {
  description = "Size of the EBS-backed PVC for the agent's shared filesystem"
  type        = string
  default     = "10Gi"
}

variable "octopus_agent_k8s_monitor_enabled" {
  description = "Enable Kubernetes monitoring via the agent (requires octopus_grpc_url)"
  type        = bool
  default     = false
}

# ── Octopus Worker ─────────────────────────────────────────────────────────────

variable "install_octopus_worker" {
  description = "Install the Octopus Kubernetes Agent in worker mode"
  type        = bool
  default     = true
}

variable "create_worker_pool" {
  description = "Create a dedicated static worker pool for this cluster"
  type        = bool
  default     = true
}

variable "octopus_worker_pool_name" {
  type    = string
  default = "EKS ARM Workers"
}

variable "octopus_worker_namespace" {
  type    = string
  default = "octopus-workers"
}

variable "octopus_worker_count" {
  type    = number
  default = 2
}

variable "octopus_worker_storage_size" {
  description = "Size of the EBS-backed PVC for the worker's shared filesystem"
  type        = string
  default     = "10Gi"
}
