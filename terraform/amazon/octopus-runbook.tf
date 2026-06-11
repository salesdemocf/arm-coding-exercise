# ---------------------------------------------------------------------------
# Verification Runbook — "Verify kubearchinspect results"
#
# Runs the post-deploy checks IN the cluster via Octopus, so you don't need a
# local kubectl or kubeconfig. Trigger it from the project's Operations →
# Runbooks, or with `octopus runbook run` (see the README).
#
# WHERE IT RUNS — the deployment target (agent), not the worker:
#   The step targets the Kubernetes AGENT (same tags as the deploy step). The
#   agent already runs in-cluster with kubectl pre-authenticated and read access
#   to kube-system (it deploys the chart there), so this needs ZERO extra RBAC.
#   A plain worker would need a Role/RoleBinding in kube-system AND a script
#   image that ships kubectl — and on Octopus Cloud the default worker pool is
#   Windows (no Bash). The in-cluster Linux agent avoids all of that.
#   To use the worker instead: set worker_pool_id = local.worker_pool_id, drop
#   the TargetRoles, grant the octopus-worker SA read RBAC on kube-system, and
#   run the step in a kubectl-capable execution container.
# ---------------------------------------------------------------------------

resource "octopusdeploy_runbook" "verify" {
  project_id  = octopusdeploy_project.kubearchinspect.id
  name        = "Verify kubearchinspect results"
  description = "Shows the kubearchinspect Job status and the arm64 compatibility report from its pod logs, run in-cluster on the Octopus agent."

  # Retention left at the Octopus default. The older
  # retention_policy { quantity_to_keep = N } form is deprecated ("will soon
  # require strategy"); omitting the block silences that and stays valid across
  # provider versions. Add a strategy-based retention_policy block later if you
  # need explicit run retention.
}

resource "octopusdeploy_process" "verify" {
  project_id = octopusdeploy_project.kubearchinspect.id
  runbook_id = octopusdeploy_runbook.verify.id
}

resource "octopusdeploy_process_step" "verify_report" {
  process_id = octopusdeploy_process.verify.id
  name       = "Show kubearchinspect job and arm64 report"
  type       = "Octopus.Script"

  # Run on the in-cluster Kubernetes agent (matched by its target tags).
  properties = {
    "Octopus.Action.TargetRoles" = join(",", var.octopus_agent_tags)
  }

  execution_properties = {
    "Octopus.Action.RunOnServer"         = "False"
    "Octopus.Action.Script.ScriptSource" = "Inline"
    "Octopus.Action.Script.Syntax"       = "Bash"

    # $${...} are shell variables (Terraform leaves them literal); plain $(...)
    # is shell command substitution.
    "Octopus.Action.Script.ScriptBody" = <<-EOT
      NS=kube-system

      echo "kubearchinspect Jobs in $${NS}:"
      kubectl get jobs -n "$${NS}" -l app.kubernetes.io/name=kubearchinspect || true

      echo
      POD=$(kubectl get pods -n "$${NS}" -l app.kubernetes.io/name=kubearchinspect \
        --sort-by=.metadata.creationTimestamp \
        -o jsonpath='{.items[-1:].metadata.name}' 2>/dev/null)

      if [ -n "$${POD}" ]; then
        echo "arm64 compatibility report ($${POD}):"
        kubectl logs -n "$${NS}" "$${POD}"
      else
        echo "No kubearchinspect pod found. The Job auto-deletes ttlSecondsAfterFinished"
        echo "(default 600s) after it finishes — run this runbook shortly after a deploy."
      fi
    EOT
  }

  depends_on = [octopusdeploy_runbook.verify]
}

output "kubearchinspect_verify_runbook_id" {
  description = "ID of the 'Verify kubearchinspect results' runbook"
  value       = octopusdeploy_runbook.verify.id
}
