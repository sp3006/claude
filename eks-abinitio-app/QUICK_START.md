# Quick Start Guide

## TL;DR - Run Everything

```bash
# 1. Setup kubeconfig with Okta OIDC
export EKS_CLUSTER_NAME="your-cluster-name"
export AWS_REGION="us-east-1"
./scripts/setup-kubeconfig-okta.sh

# 2. Test locally
./scripts/test-local.sh

# 3. Build and push to ECR
export AWS_ACCOUNT_ID="123456789012"
./scripts/build-and-push.sh

# 4. Update Job manifest with image URI
IMAGE_URI="123456789012.dkr.ecr.us-east-1.amazonaws.com/abinitio-batch-service:latest"
sed -i '' "s|<YOUR_ECR_REGISTRY>/abinitio-batch-service:latest|${IMAGE_URI}|g" k8s/abinitio-batch-job.yaml

# 5. Deploy to EKS
./scripts/deploy-to-eks.sh

# 6. Monitor
kubectl logs -n bi-abi-apps-dev -l job=abinitio-batch-job --follow
```

## Essential Commands

### Authentication
```bash
# Setup kubectl
./scripts/setup-kubeconfig-okta.sh

# Verify connection
kubectl get pods -n bi-abi-apps-dev
kubectl get pods -n abinitio-operator
```

### Local Testing
```bash
# Quick local test
./scripts/test-local.sh

# Manual test
source venv/bin/activate
python3 src/abinitio_batch_service.py
```

### Build & Deploy
```bash
# Build and push
./scripts/build-and-push.sh

# Deploy
./scripts/deploy-to-eks.sh
```

### Monitoring
```bash
# Job status
kubectl get jobs -n bi-abi-apps-dev

# Pod status
kubectl get pods -n bi-abi-apps-dev -l job=abinitio-batch-job

# View logs
kubectl logs -n bi-abi-apps-dev -l job=abinitio-batch-job --follow

# Check CooperatingSystem resource
kubectl get cooperatingsystem -n abinitio-operator
```

### Cleanup
```bash
# Delete job
kubectl delete job abinitio-batch-job -n bi-abi-apps-dev

# Delete resource in operator namespace
kubectl delete cooperatingsystem sample-cooperating-system -n abinitio-operator
```

## Testing Checklist

- [ ] Kubeconfig setup successful
- [ ] Can connect to EKS cluster
- [ ] Local test passes
- [ ] Health check endpoint reachable
- [ ] Docker image builds successfully
- [ ] Image pushed to ECR
- [ ] Job manifest updated with correct image
- [ ] Job deployed to EKS
- [ ] Job completes successfully
- [ ] CooperatingSystem resource created in abinitio-operator namespace

## Common Issues

| Issue | Solution |
|-------|----------|
| Cannot connect to cluster | Run `./scripts/setup-kubeconfig-okta.sh` |
| ImagePullBackOff | Check image URI in Job manifest |
| Permission denied | Verify RBAC resources applied |
| Health check fails | Test `curl https://abinitio-api-bi-dev/health` |
| Job stuck pending | Check `kubectl describe pod $POD_NAME -n bi-abi-apps-dev` |

See README.md for full documentation.
