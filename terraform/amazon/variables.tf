# ── AWS / cluster ─────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "dvb-eks-arm"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.32"
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to reach the EKS API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags applied to all AWS resources"
  type        = map(string)
  default     = {}
}

# ── VPC (auto-created unless you bring your own) ───────────────────────────────

variable "create_vpc" {
  description = "Create a VPC + subnets. Set false and supply vpc_id/subnet_ids to bring your own."
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR for the created VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_az_count" {
  description = "Number of AZs (and public/private subnet pairs) to create"
  type        = number
  default     = 3
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway for all private subnets (cheaper) instead of one per AZ"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "Existing VPC ID. Only used when create_vpc = false."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Existing subnet IDs (private recommended). Only used when create_vpc = false."
  type        = list(string)
  default     = []
}

# ── ARM Graviton NodePool ──────────────────────────────────────────────────────

variable "arm_nodepool_name" {
  type    = string
  default = "arm-graviton"
}

variable "arm_instance_categories" {
  type    = list(string)
  default = ["c", "m", "r"]
}

variable "arm_instance_generation_min" {
  type    = string
  default = "4"
}

variable "arm_capacity_type" {
  type    = string
  default = "on-demand"

  validation {
    condition     = contains(["on-demand", "spot"], var.arm_capacity_type)
    error_message = "arm_capacity_type must be either 'on-demand' or 'spot'."
  }
}

variable "arm_nodepool_cpu_limit" {
  type    = string
  default = "1000"
}

variable "arm_nodepool_memory_limit" {
  type    = string
  default = "1000Gi"
}

variable "arm_node_expire_after" {
  type    = string
  default = "336h"
}

# ── ECR ─────────────────────────────────────────────────────────────────────

variable "ecr_repository_name" {
  description = "ECR repository name; also used as the Octopus package/service id"
  type        = string
  default     = "kubearchinspect"
}

variable "ecr_image_tag_mutability" {
  type    = string
  default = "MUTABLE"
}

variable "ecr_scan_on_push" {
  type    = bool
  default = true
}

variable "ecr_force_delete" {
  description = "Allow Terraform to delete the ECR repo even if it still holds images (handy for demo teardown)"
  type        = bool
  default     = true
}

variable "create_ecr_push_user" {
  description = "Create a scoped IAM user + access key for CI to push to ECR. Disable to use GitHub OIDC instead."
  type        = bool
  default     = true
}

# ── GitHub ────────────────────────────────────────────────────────────────────

variable "github_owner" {
  description = "GitHub org/user that owns the forked repository"
  type        = string
}

variable "github_token" {
  description = "Fine-grained PAT scoped to the forked repository (Actions, Secrets, Variables: read/write)"
  type        = string
  sensitive   = true
}

variable "github_repository" {
  description = "Name of the forked repository to wire Actions vars/secrets into"
  type        = string
}

# ── Octopus connection ────────────────────────────────────────────────────────

variable "octopus_server_url" {
  type = string
}

variable "octopus_polling_url" {
  description = "Polling comms address for the agent/worker"
  type        = string
}

variable "octopus_grpc_url" {
  description = "gRPC URL for the Kubernetes monitor (only needed if enabled)"
  type        = string
  default     = ""
}

variable "octopus_api_key" {
  type      = string
  sensitive = true
}

variable "octopus_space_id" {
  description = "Octopus space ID, e.g. Spaces-1"
  type        = string
}

variable "octopus_space_name" {
  description = "Octopus space display name"
  type        = string
  default     = "Default"
}

# ── EBS storage ───────────────────────────────────────────────────────────────

variable "cluster_is_auto_mode" {
  description = "true = Auto Mode (StorageClass only, no driver). false = standard EKS."
  type        = bool
  default     = true
}

variable "ebs_storage_class_name" {
  type    = string
  default = "ebs-gp3"
}

variable "ebs_set_default_storage_class" {
  type    = bool
  default = true
}

variable "install_ebs_csi_driver" {
  description = "Install aws-ebs-csi-driver. MUST stay false on Auto Mode."
  type        = bool
  default     = false
}

variable "ebs_csi_driver_chart_version" {
  type    = string
  default = "2.35.1"
}

# ── Octopus project (kubearchinspect) ──────────────────────────────────────────

variable "kubearchinspect_project_group_name" {
  type    = string
  default = "Platform Tooling"
}

variable "kubearchinspect_project_name" {
  type    = string
  default = "kubearchinspect"
}

# ── Octopus environments ────────────────────────────────────────────────────────

variable "environments" {
  type    = list(string)
  default = ["Development", "Staging", "Production"]
}

# ── Octopus Kubernetes Agent (deployment target) ────────────────────────────────

variable "install_octopus_agent" {
  type    = bool
  default = true
}

variable "octopus_agent_chart_version" {
  type    = string
  default = "2.36.0"
}

variable "octopus_agent_namespace" {
  type    = string
  default = "octopus-agent"
}

variable "octopus_agent_tags" {
  type    = list(string)
  default = ["kubernetes", "eks-arm"]
}

variable "octopus_agent_default_namespace" {
  type    = string
  default = "default"
}

variable "octopus_agent_storage_size" {
  type    = string
  default = "10Gi"
}

variable "octopus_agent_k8s_monitor_enabled" {
  type    = bool
  default = false
}

# ── Octopus Worker ──────────────────────────────────────────────────────────────

variable "install_octopus_worker" {
  type    = bool
  default = true
}

variable "create_worker_pool" {
  type    = bool
  default = true
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
  type    = string
  default = "10Gi"
}
