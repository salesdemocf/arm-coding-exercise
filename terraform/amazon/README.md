# EKS ARM — Octopus Agent, Worker & kubearchinspect Project

Terraform to register an EKS Auto Mode (Graviton/arm64) cluster with Octopus
Deploy: it creates the Octopus project for `kubearchinspect`, three environments,
and installs the Octopus Kubernetes Agent (deployment target) and a worker, both
backed by EBS storage.

## What this creates

**Octopus Deploy**
- 1 project group (`Platform Tooling`) + 1 project (`kubearchinspect`)
- 3 environments: Development, Staging, Production
- 1 static worker pool (`EKS ARM Workers`)

**On the cluster**
- A gp3 `StorageClass` (`ebs-gp3`) for the agent/worker shared filesystem
- Octopus Kubernetes Agent as a deployment target (EBS-backed)
- Octopus Kubernetes Agent in worker mode (EBS-backed)

## EBS storage — the important bit

The ARM cluster built in `terraform/amazon` is **EKS Auto Mode**, where the EBS
CSI controller is built in. You therefore do **not** install an EBS driver — you
only create a `StorageClass` that uses the Auto Mode provisioner
`ebs.csi.eks.amazonaws.com`. That is exactly what `ebs-storage.tf` does when
`cluster_is_auto_mode = true` (the default).

If you point this at a **standard** (non-Auto-Mode) EKS cluster, set
`cluster_is_auto_mode = false` and either:
- set `install_ebs_csi_driver = true` (installs the `aws-ebs-csi-driver` Helm
  chart — but you must give its controller ServiceAccount IAM access via IRSA;
  see the note in `ebs-storage.tf`), or
- install the `aws-ebs-csi-driver` **EKS managed add-on** in your cluster
  Terraform (recommended — it wires up the IAM for you).

> EBS volumes are ReadWriteOnce (single-node attach). Unlike the chart's default
> in-cluster NFS server (ReadWriteMany), the agent and its script pods must stay
> on one node/AZ. Keep the agent at a single replica when using EBS.

## Prerequisites

- The EKS cluster is up and your kubeconfig has a context for it
  (`aws eks update-kubeconfig --name <cluster> --region <region> --alias <cluster>`).
- An Octopus instance, space ID, and API key.
- `curl` and `jq` available locally (used only for destroy-time deregistration).

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # edit values
export TF_VAR_octopus_api_key="API-xxxx"

terraform init
terraform plan
terraform apply
```

## Notes

- The Octopus agent image supports arm64, so it runs fine on Graviton nodes. It
  is not pinned to arm64 here, so it may also schedule on the amd64
  `general-purpose` Auto Mode pool. To force it onto the ARM pool, add a
  `nodeSelector` of `kubernetes.io/arch: arm64` via the chart values.
- The project uses the built-in **Default Lifecycle**, which auto-includes the
  three environments. Swap `lifecycle_id` in `octopus-project.tf` if you want a
  custom Dev → Staging → Production lifecycle.
- Chart version is pinned via `octopus_agent_chart_version` (default `2.36.0`).
  Bump as needed.
