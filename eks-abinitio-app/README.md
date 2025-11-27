# Ab Initio EKS Batch Service with Okta OIDC

Production-ready batch service for submitting and managing Ab Initio jobs on EKS with Okta OIDC authentication.

## Architecture

### Repository Structure

```
Application Repo (this repo)              Infrastructure Repo (separate)
├── src/                                  ├── k8s/abinitio-batch-service/
│   ├── abinitio_api_client.py           │   ├── values-dev.yaml
│   └── abinitio_batch_service.py        │   ├── deployment.yaml
├── config/                               │   ├── configmap.yaml
│   ├── job_spec.yaml (sample)           │   ├── secrets.yaml
│   └── runtime.yaml (sample)            │   └── rbac.yaml
├── k8s/                                  └── argocd/
│   ├── abinitio-batch-job.yaml               └── abinitio-batch-service.yaml
│   ├── configmap.yaml
│   ├── rbac.yaml
│   └── job-templates/
├── infrastructure-templates/
│   ├── values-dev.yaml
│   ├── argocd-application.yaml
│   └── README.md
├── Dockerfile
└── requirements.txt
```

### Component Flow

```
Local Laptop → Okta OIDC Auth → EKS Cluster
                                    ↓
                            Namespace: bi-abi-apps-dev
                                    ↓
                            Kubernetes Job (Python Batch Service)
                                    ↓
┌──────────────────────────────────────────────────────────────┐
│  API Operations:                                             │
│  1. Health Check:  GET    /health                           │
│  2. Submit Job:    POST   /abinitio/jobs                    │
│  3. Cancel Job:    DELETE /abinitio/jobs/{name}             │
│  4. Job Status:    GET    /abinitio/jobs/{name}             │
└──────────────────────────────────────────────────────────────┘
                                    ↓
                        Ab Initio API: abinitio-api-bi-abi-apps-dev.cluster
                                    ↓
                            abinitio-operator namespace
                                    ↓
                        Ab Initio Co-Operating System + Teradata
```

### Technology Stack

- **Python 3.11** - Application runtime
- **Docker** - Containerization
- **Amazon EKS** - Kubernetes orchestration
- **ArgoCD** - GitOps deployment
- **Okta OIDC** - Authentication
- **AWS IRSA** - IAM Roles for Service Accounts
- **Teradata** - Database backend
- **S3** - Data storage

## Supported Operations

### 1. Health Check
Check if Ab Initio API is healthy and accessible.

**API Endpoint:** `GET https://abinitio-api-bi-abi-apps-dev.cluster/health`

**Usage:**
```bash
kubectl apply -f k8s/job-templates/health-check-job.yaml
kubectl logs -f job/abinitio-health-check -n bi-abi-apps-dev
```

### 2. Submit Job
Submit a new Ab Initio job for processing.

**API Endpoint:** `POST https://abinitio-api-bi-abi-apps-dev.cluster/abinitio/jobs`

**Usage:**
```bash
# Update job_spec.yaml with your job details
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/abinitio-batch-job.yaml
kubectl logs -f -l operation=submit -n bi-abi-apps-dev
```

### 3. Cancel Job
Cancel a running Ab Initio job.

**API Endpoint:** `DELETE https://abinitio-api-bi-abi-apps-dev.cluster/abinitio/jobs/{name}`

**Usage:**
```bash
# Edit cancel-job.yaml and set JOB_NAME
kubectl apply -f k8s/job-templates/cancel-job.yaml
kubectl logs -f job/abinitio-cancel-job -n bi-abi-apps-dev
```

### 4. Get Job Status
Get the status of a running or completed job, with optional polling.

**API Endpoint:** `GET https://abinitio-api-bi-abi-apps-dev.cluster/abinitio/jobs/{name}`

**Usage:**
```bash
# Edit status-job.yaml and set JOB_NAME, POLL=true for continuous monitoring
kubectl apply -f k8s/job-templates/status-job.yaml
kubectl logs -f job/abinitio-status-job -n bi-abi-apps-dev
```

## Prerequisites

- **Python 3.11+**
- **Docker**
- **AWS CLI** configured with appropriate credentials
- **kubectl** installed and configured
- **Access to EKS cluster** with Okta OIDC
- **Permissions** to `bi-abi-apps-dev` and `abinitio-operator` namespaces
- **ECR repository** for storing Docker images

## Quick Start

### Step 1: Setup kubectl with Okta OIDC

```bash
cd eks-abinitio-app

# Configure environment
export EKS_CLUSTER_NAME="your-eks-cluster-name"
export AWS_REGION="us-east-1"

# Setup authentication
./scripts/setup-kubeconfig-okta.sh

# Verify connection
kubectl get namespaces
kubectl get pods -n bi-abi-apps-dev
```

### Step 2: Test Locally

```bash
# Run local tests
./scripts/test-local.sh

# Expected output: Health check passes, API calls succeed
```

### Step 3: Build and Push Docker Image

```bash
# Configure AWS account
export AWS_ACCOUNT_ID="123456789012"
export AWS_REGION="us-east-1"

# Build and push to ECR
./scripts/build-and-push.sh
```

### Step 4: Update Kubernetes Manifests

```bash
# Get your ECR image URI
IMAGE_URI="123456789012.dkr.ecr.us-east-1.amazonaws.com/abinitio-batch-service:latest"

# Update job manifest
sed -i '' "s|<YOUR_ECR_REGISTRY>/abinitio-batch-service:latest|${IMAGE_URI}|g" k8s/abinitio-batch-job.yaml
sed -i '' "s|<YOUR_ECR_REGISTRY>/abinitio-batch-service:latest|${IMAGE_URI}|g" k8s/job-templates/*.yaml

# Update IAM role ARN in rbac.yaml
sed -i '' "s|ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" k8s/rbac.yaml
```

### Step 5: Deploy to EKS

```bash
# Deploy RBAC, ConfigMaps, and Job
./scripts/deploy-to-eks.sh

# Monitor job execution
kubectl logs -f -l app=abinitio-batch-service -n bi-abi-apps-dev
```

## Detailed Setup Guide

### Environment Variables

The application uses these environment variables (configured in ConfigMap):

| Variable | Description | Default |
|----------|-------------|---------|
| `ABINITIO_API_BASE` | Ab Initio API base URL | `https://abinitio-api-bi-abi-apps-dev.cluster` |
| `OPERATION` | Operation to perform | `submit` |
| `JOB_SPEC_PATH` | Path to job specification YAML | `/app/config/job_spec.yaml` |
| `JOB_NAME` | Job name for cancel/status operations | `` |
| `POLL` | Enable status polling | `false` |
| `POLL_INTERVAL` | Seconds between status checks | `10` |
| `MAX_POLL_ATTEMPTS` | Max polling attempts | `60` |
| `DB_HOST` | Database host | From ConfigMap |
| `DB_PORT` | Database port | From ConfigMap |
| `DB_NAME` | Database name | From ConfigMap |
| `DB_PASSWORD` | Database password | From Secret |
| `S3_BUCKET` | S3 bucket name | From ConfigMap |
| `IAM_ROLE_ARN` | IAM role for AWS access | From ServiceAccount |

### Testing Each Operation

#### Health Check

```bash
# Apply health check job
kubectl apply -f k8s/job-templates/health-check-job.yaml

# View logs
kubectl logs -f job/abinitio-health-check -n bi-abi-apps-dev

# Expected output:
# ======================================================================
# OPERATION: Health Check
# ======================================================================
# [API] Health Check: GET https://abinitio-api-bi-abi-apps-dev.cluster/health
# ✓ Health check passed: 200
# ✓ OPERATION COMPLETED SUCCESSFULLY
```

#### Submit Job

```bash
# Update job specification in configmap.yaml
vim k8s/configmap.yaml

# Apply ConfigMap and Job
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/abinitio-batch-job.yaml

# Monitor logs
kubectl logs -f -l operation=submit -n bi-abi-apps-dev

# Expected output:
# ======================================================================
# OPERATION: Submit Job
# ======================================================================
# [1/2] Performing health check...
# ✓ Health check passed: 200
# [2/2] Submitting job...
# [API] Submit Job: POST https://abinitio-api-bi-abi-apps-dev.cluster/abinitio/jobs
# ✓ Job submitted successfully
#   Job ID: job-12345
#   Status: RUNNING
```

#### Cancel Job

```bash
# Edit cancel job manifest with job name
export JOB_NAME="sample-abinitio-job"
sed -i '' "s|<JOB_NAME_TO_CANCEL>|${JOB_NAME}|g" k8s/job-templates/cancel-job.yaml

# Apply cancel job
kubectl apply -f k8s/job-templates/cancel-job.yaml

# View logs
kubectl logs -f job/abinitio-cancel-job -n bi-abi-apps-dev
```

#### Get Job Status (with Polling)

```bash
# Edit status job manifest with job name
export JOB_NAME="sample-abinitio-job"
sed -i '' "s|<JOB_NAME_TO_CHECK>|${JOB_NAME}|g" k8s/job-templates/status-job.yaml

# Apply status job with polling enabled
kubectl apply -f k8s/job-templates/status-job.yaml

# View logs (will poll every 10 seconds)
kubectl logs -f job/abinitio-status-job -n bi-abi-apps-dev

# Expected output:
# ======================================================================
# OPERATION: Get Job Status
# ======================================================================
# Polling enabled: Will check status every 10s (max 60 attempts)
# [Attempt 1/60]
# [API] Get Job Status: GET https://abinitio-api-bi-abi-apps-dev.cluster/abinitio/jobs/sample-abinitio-job
# ✓ Job status retrieved
#   Job: sample-abinitio-job
#   Status: RUNNING
#   Progress: 45%
# Waiting 10s before next check...
```

## Integration with Infrastructure Repository

This application repo contains only application code. Configuration is managed separately in the Infrastructure repository.

### Copy Templates to Infrastructure Repo

```bash
# In infrastructure repository
cd <infrastructure-repo>

# Create directory structure
mkdir -p k8s/abinitio-batch-service argocd

# Copy templates from application repo
cp <app-repo>/infrastructure-templates/values-dev.yaml k8s/abinitio-batch-service/
cp <app-repo>/infrastructure-templates/argocd-application.yaml argocd/abinitio-batch-service.yaml
```

### Update values-dev.yaml

Edit the following in `values-dev.yaml`:

```yaml
image:
  repository: docker-appimage-bi-snp-ss-prod-us-east-1
  tag: cmi_prem:202510061127  # Your deployed image tag

database:
  host: "teradata-db.cluster.local"
  name: "abinitio_dev_db"
  secrets:
    passwordSecretName: "db-credentials"

s3:
  bucket: "abinitio-dev-bucket"

iam:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/abinitio-batch-service-role"

paths:
  projectRoot: "/opt/abinitio/projects"
  graphsDir: "/opt/abinitio/projects/graphs"
```

### Deploy with ArgoCD

```bash
# Apply ArgoCD application
kubectl apply -f argocd/abinitio-batch-service.yaml

# Sync application
argocd app sync abinitio-batch-service

# Watch deployment
argocd app get abinitio-batch-service --refresh
```

## Monitoring and Troubleshooting

### View Job Status

```bash
# List all jobs
kubectl get jobs -n bi-abi-apps-dev

# Get job details
kubectl describe job abinitio-submit-job -n bi-abi-apps-dev

# View logs
kubectl logs -f -l app=abinitio-batch-service -n bi-abi-apps-dev
```

### Check Pod Status

```bash
# List pods
kubectl get pods -n bi-abi-apps-dev -l app=abinitio-batch-service

# Describe pod
POD_NAME=$(kubectl get pods -n bi-abi-apps-dev -l operation=submit -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod $POD_NAME -n bi-abi-apps-dev

# Get pod logs
kubectl logs $POD_NAME -n bi-abi-apps-dev --follow
```

### Common Issues

**Issue: ImagePullBackOff**
```bash
# Check image exists in ECR
aws ecr describe-images --repository-name abinitio-batch-service --region us-east-1

# Verify image URI in job manifest
kubectl get job abinitio-submit-job -n bi-abi-apps-dev -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**Issue: API Health Check Fails**
```bash
# Test API endpoint manually
curl -v https://abinitio-api-bi-abi-apps-dev.cluster/health

# Check DNS resolution
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- nslookup abinitio-api-bi-abi-apps-dev.cluster
```

**Issue: Permission Denied**
```bash
# Check ServiceAccount
kubectl get sa abinitio-batch-sa -n bi-abi-apps-dev -o yaml

# Check IAM role annotation
kubectl get sa abinitio-batch-sa -n bi-abi-apps-dev -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'

# Check RBAC
kubectl describe role abinitio-batch-role -n bi-abi-apps-dev
kubectl describe rolebinding abinitio-batch-binding -n bi-abi-apps-dev
```

## Development Workflow

### Local Development

```bash
# Make code changes
vim src/abinitio_batch_service.py

# Test locally
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
export ABINITIO_API_BASE="https://abinitio-api-bi-abi-apps-dev.cluster"
export OPERATION="health"
python3 src/abinitio_batch_service.py
```

### Build and Deploy

```bash
# Build new image
docker build -t abinitio-batch-service:$(git rev-parse --short HEAD) .

# Push to ECR
./scripts/build-and-push.sh

# Update infrastructure repo with new tag
# Commit and push - ArgoCD will auto-sync
```

## Security Best Practices

1. **Never commit secrets** to repository
2. **Use AWS Secrets Manager or Kubernetes Secrets** for sensitive data
3. **Enable IRSA** (IAM Roles for Service Accounts) for AWS access
4. **Use least privilege** RBAC permissions
5. **Enable network policies** to restrict traffic
6. **Scan Docker images** for vulnerabilities
7. **Rotate credentials** regularly

## Cleanup

```bash
# Delete jobs
kubectl delete job --all -n bi-abi-apps-dev

# Delete ConfigMaps
kubectl delete configmap abinitio-app-config abinitio-job-spec -n bi-abi-apps-dev

# Delete RBAC resources
kubectl delete -f k8s/rbac.yaml

# Delete ArgoCD application
argocd app delete abinitio-batch-service
```

## Next Steps

- [ ] Set up monitoring with Prometheus and Grafana
- [ ] Add alerting for job failures
- [ ] Implement retry logic with exponential backoff
- [ ] Create CronJob for scheduled executions
- [ ] Add integration tests
- [ ] Set up CI/CD pipeline

## Support

For issues or questions:
- Check the [infrastructure-templates/README.md](infrastructure-templates/README.md) for integration details
- Review logs: `kubectl logs -f -l app=abinitio-batch-service -n bi-abi-apps-dev`
- Contact: DevOps team or Ab Initio administrators
