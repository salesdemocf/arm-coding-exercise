# kubearchinspect Helm Chart

Deploys [Arm's kubearchinspect](https://github.com/ArmDeveloperEcosystem/kubearchinspect)
as a Kubernetes Job to verify that all container images running in your cluster
have `arm64` architecture support. Designed for use with AWS EKS Graviton node pools.

## Prerequisites

- Helm 3.x
- kubectl access to your EKS cluster
- AWS ECR repository for the image (Arm does not publish an official container image)

## Step 1: Build and Push the Image to ECR

```bash
VERSION=0.7.0
ACCOUNT=336151728602
REGION=us-east-1
REPO=${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/kubearchinspect

# Create ECR repo (one-time)
aws ecr create-repository \
  --repository-name kubearchinspect \
  --region ${REGION}

# Authenticate Docker to ECR
aws ecr get-login-password --region ${REGION} \
  | docker login --username AWS --password-stdin \
  ${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com

# Build for arm64 and push
docker buildx build \
  --platform linux/arm64 \
  --build-arg VERSION=${VERSION} \
  -t ${REPO}:${VERSION} \
  -t ${REPO}:latest \
  --push .
```

## Step 2: Install the Helm Chart

```bash
helm install kubearchinspect . \
  --namespace kube-system \
  --set image.repository=336151728602.dkr.ecr.us-east-1.amazonaws.com/kubearchinspect \
  --set image.tag=0.7.0
```

### Per-environment installs (Dev / Staging / Production)

```bash
# Development
helm install kubearchinspect . \
  -f values.yaml \
  -f values-dev.yaml \
  --namespace kube-system \
  --kube-context dvb-eks-arm-dev

# Staging
helm install kubearchinspect . \
  -f values.yaml \
  -f values-staging.yaml \
  --namespace kube-system \
  --kube-context dvb-eks-arm-staging

# Production
helm install kubearchinspect . \
  -f values.yaml \
  -f values-prod.yaml \
  --namespace kube-system \
  --kube-context dvb-eks-arm-prod
```

## Step 3: View Results

```bash
# Watch job completion
kubectl get job kubearchinspect -n kube-system -w

# View scan output
kubectl logs -n kube-system \
  -l app.kubernetes.io/name=kubearchinspect -f
```

### Example output

```
Legend:
-------
✅ - arm64 node compatible
🆙 - arm64 node compatible (after update)
❌ - not arm64 node compatible
🚫 - error occurred

✅ 336151728602.dkr.ecr.us-east-1.amazonaws.com/petclinic:1.0.0
✅ registry.k8s.io/kube-proxy:v1.29.0
✅ quay.io/prometheus/node-exporter:v1.7.0
❌ some-amd64-only-image:latest
```

## Configuration Reference

| Parameter | Description | Default |
|---|---|---|
| `image.repository` | ECR image repository **(required)** | `""` |
| `image.tag` | Image tag | `0.7.0` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `job.ttlSecondsAfterFinished` | Auto-cleanup delay after job completes | `600` |
| `job.backoffLimit` | Retry attempts on failure | `2` |
| `job.activeDeadlineSeconds` | Job timeout in seconds | `300` |
| `inspect.namespace` | Namespace to scan (empty = all) | `""` |
| `inspect.checkNewerVersions` | Check newer image versions for arm64 support | `true` |
| `inspect.logLevel` | Log verbosity: `info` or `debug` | `info` |
| `rbac.scope` | `cluster` or `namespace` RBAC scope | `cluster` |
| `pod.nodeSelector` | Node selector for the Job pod | `kubernetes.io/arch: arm64` |
| `pod.resources` | CPU/memory requests and limits | See values.yaml |

## Octopus Deploy Integration

This chart is designed to be deployed as a **verification step** in an Octopus Deploy
project alongside your primary application Helm chart. Recommended pipeline order:

1. **Deploy ARM Node Pool** (Terraform / kubectl)
2. **Run kubearchinspect** (this chart) — gate on exit code
3. **Deploy Application** (petclinic or podinfo Helm chart)
