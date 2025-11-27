# Ab Initio EKS Batch Service with Okta OIDC

This application submits CooperatingSystem runtime YAML to Kubernetes API via the Ab Initio operator, running as a batch job on EKS with Okta OIDC authentication.

## Architecture

```
Local Laptop → Okta OIDC Auth → EKS Cluster → Namespace: bi-abi-apps-dev
                                    ↓
                            Kubernetes Job (Python Batch Service)
                                    ↓
                            1. Check Health: GET https://abinitio-api-bi-dev/health
                            2. Submit CooperatingSystem YAML → abinitio-operator namespace
                                    ↓
                            Ab Initio Operator → Kubernetes API
```

## Prerequisites

- Python 3.11+
- Docker
- AWS CLI configured
- kubectl installed
- Access to EKS cluster with Okta OIDC
- Permissions to bi-abi-apps-dev and abinitio-operator namespaces

## Project Structure

```
eks-abinitio-app/
├── src/
│   └── abinitio_batch_service.py   # Main Python batch service
├── k8s/
│   ├── abinitio-batch-job.yaml     # Kubernetes Job manifest
│   ├── rbac.yaml                    # ServiceAccount, Role, RoleBinding
│   └── configmap.yaml               # Runtime YAML ConfigMap
├── config/
│   └── runtime.yaml                 # Sample CooperatingSystem runtime YAML
├── scripts/
│   ├── setup-kubeconfig-okta.sh    # Setup kubectl with Okta OIDC
│   ├── test-local.sh                # Test locally before deploying
│   ├── build-and-push.sh            # Build and push Docker image to ECR
│   └── deploy-to-eks.sh             # Deploy Job to EKS
├── requirements.txt                 # Python dependencies
├── Dockerfile                       # Container image definition
└── README.md                        # This file
```

## Step-by-Step Execution Guide

### STEP 1: Configure Environment Variables

Edit the scripts and update these values:

```bash
# In scripts/setup-kubeconfig-okta.sh
export EKS_CLUSTER_NAME="your-eks-cluster-name"
export AWS_REGION="us-east-1"
export OKTA_IDP_ARN="arn:aws:iam::ACCOUNT_ID:oidc-provider/YOUR_OKTA_ISSUER"
export OKTA_CLIENT_ID="your-okta-client-id"
export OKTA_ISSUER_URL="https://your-domain.okta.com"

# In scripts/build-and-push.sh
export AWS_ACCOUNT_ID="123456789012"
export AWS_REGION="us-east-1"
export ECR_REPOSITORY="abinitio-batch-service"
```

**Test Command:**
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Expected output: Your AWS account details
```

### STEP 2: Setup Kubectl with Okta OIDC Authentication

Run the setup script to configure kubectl to authenticate to EKS using Okta OIDC:

```bash
cd eks-abinitio-app
./scripts/setup-kubeconfig-okta.sh
```

**Test Commands:**
```bash
# Verify connection to EKS
kubectl cluster-info

# Check you can access the namespaces
kubectl get namespace bi-abi-apps-dev
kubectl get namespace abinitio-operator

# List pods in your namespace
kubectl get pods -n bi-abi-apps-dev
kubectl get pods -n abinitio-operator
```

**Expected Output:**
```
✓ Successfully connected to EKS cluster
Current context: arn:aws:eks:us-east-1:123456789012:cluster/your-cluster-name
```

### STEP 3: Test Python Code Locally

Test the batch service on your local laptop before containerizing:

```bash
./scripts/test-local.sh
```

**What this does:**
1. Creates Python virtual environment
2. Installs dependencies from requirements.txt
3. Runs the Python script using local kubeconfig
4. Tests API health check
5. Attempts to submit YAML to K8s API

**Test Commands:**
```bash
# Manual test - activate venv first
source venv/bin/activate

# Test health check only (modify script to comment out K8s submission)
python3 src/abinitio_batch_service.py

# Check if runtime YAML is valid
python3 -c "import yaml; yaml.safe_load(open('config/runtime.yaml'))"
```

**Expected Output:**
```
======================================================================
Ab Initio Batch Service - CooperatingSystem Runtime Submission
======================================================================
Configuration:
  API Base: https://abinitio-api-bi-dev
  Operator Namespace: abinitio-operator
  Runtime YAML: config/runtime.yaml
======================================================================

[STEP 1/3] Checking Ab Initio API health...
Checking health endpoint: https://abinitio-api-bi-dev/health
✓ Health check passed: Status 200

[STEP 2/3] Loading CooperatingSystem runtime YAML...
Loading runtime YAML from: config/runtime.yaml
✓ Successfully loaded YAML
  Kind: CooperatingSystem
  Name: sample-cooperating-system

[STEP 3/3] Submitting to Kubernetes API...
✓ Using local kubeconfig file
Submitting to Kubernetes API:
  API Version: abinitio.io/v1
  Kind: CooperatingSystem
  Name: sample-cooperating-system
  Namespace: abinitio-operator
✓ Successfully created resource in K8s

======================================================================
✓ BATCH SERVICE COMPLETED SUCCESSFULLY
======================================================================
```

### STEP 4: Customize Runtime YAML

Edit the CooperatingSystem runtime configuration:

```bash
# Edit the runtime YAML
vim config/runtime.yaml

# Or update the ConfigMap directly
vim k8s/configmap.yaml
```

**Test Command:**
```bash
# Validate YAML syntax
python3 -c "import yaml; print(yaml.safe_load(open('config/runtime.yaml')))"

# Apply ConfigMap to test
kubectl apply -f k8s/configmap.yaml --dry-run=client
```

### STEP 5: Build and Push Docker Image to ECR

Build the Docker image and push to Amazon ECR:

```bash
./scripts/build-and-push.sh
```

**Manual Test Commands:**
```bash
# Test build locally first
docker build -t abinitio-batch-service:test .

# Run container locally to test
docker run --rm \
  -e ABINITIO_API_BASE=https://abinitio-api-bi-dev \
  -e ABINITIO_OPERATOR_NAMESPACE=abinitio-operator \
  -v ~/.kube:/root/.kube:ro \
  -v $(pwd)/config:/app/config:ro \
  abinitio-batch-service:test

# Check image size
docker images | grep abinitio-batch-service

# Inspect image layers
docker history abinitio-batch-service:test
```

**Expected Output:**
```
========================================
Build and Push Docker Image to ECR
========================================
[1/5] Checking prerequisites...
✓ Docker found
✓ AWS CLI found

[2/5] Logging in to Amazon ECR...
✓ Logged in to ECR

[3/5] Ensuring ECR repository exists...
✓ ECR repository already exists

[4/5] Building Docker image...
✓ Docker image built

[5/5] Pushing image to ECR...
✓ Image pushed to ECR

========================================
Build and push completed!
========================================
Image URI: 123456789012.dkr.ecr.us-east-1.amazonaws.com/abinitio-batch-service:latest
```

### STEP 6: Update Job Manifest with Image URI

Update the Kubernetes Job with your ECR image URI:

```bash
# Get your image URI
IMAGE_URI="123456789012.dkr.ecr.us-east-1.amazonaws.com/abinitio-batch-service:latest"

# Update the Job manifest
sed -i '' "s|<YOUR_ECR_REGISTRY>/abinitio-batch-service:latest|${IMAGE_URI}|g" k8s/abinitio-batch-job.yaml
```

**Test Command:**
```bash
# Verify the manifest is valid
kubectl apply -f k8s/abinitio-batch-job.yaml --dry-run=client

# Check all manifests
kubectl apply -f k8s/ --dry-run=client
```

### STEP 7: Deploy to EKS

Deploy the batch job to EKS cluster:

```bash
./scripts/deploy-to-eks.sh
```

**Expected Output:**
```
========================================
Deploy Ab Initio Batch Job to EKS
========================================

[1/6] Verifying kubectl connection...
✓ Connected to cluster

[2/6] Verifying namespace exists...
✓ Namespace bi-abi-apps-dev exists

[3/6] Applying RBAC resources...
✓ RBAC resources applied

[4/6] Applying ConfigMap...
✓ ConfigMap applied

[5/6] Cleaning up existing job...
✓ No existing job to delete

[6/6] Deploying batch job...
✓ Batch job deployed

========================================
Deployment completed!
========================================
```

### STEP 8: Monitor and Verify Job Execution

**Monitor the Job:**
```bash
# Watch job status
kubectl get jobs -n bi-abi-apps-dev -w

# Get job details
kubectl describe job abinitio-batch-job -n bi-abi-apps-dev

# Check job completion
kubectl get job abinitio-batch-job -n bi-abi-apps-dev -o jsonpath='{.status.succeeded}'
```

**View Pod Status:**
```bash
# List pods for the job
kubectl get pods -n bi-abi-apps-dev -l job=abinitio-batch-job

# Get pod name
POD_NAME=$(kubectl get pods -n bi-abi-apps-dev -l job=abinitio-batch-job -o jsonpath='{.items[0].metadata.name}')

# Describe pod
kubectl describe pod $POD_NAME -n bi-abi-apps-dev
```

**View Logs:**
```bash
# Follow logs in real-time
kubectl logs -n bi-abi-apps-dev -l job=abinitio-batch-job --follow

# Or get logs from specific pod
kubectl logs -n bi-abi-apps-dev $POD_NAME

# Get logs from previous run (if pod restarted)
kubectl logs -n bi-abi-apps-dev $POD_NAME --previous
```

**Expected Log Output:**
```
======================================================================
Ab Initio Batch Service - CooperatingSystem Runtime Submission
======================================================================
Configuration:
  API Base: https://abinitio-api-bi-dev
  Operator Namespace: abinitio-operator
  Runtime YAML: /app/config/runtime.yaml
======================================================================

[STEP 1/3] Checking Ab Initio API health...
✓ Health check passed: Status 200

[STEP 2/3] Loading CooperatingSystem runtime YAML...
✓ Successfully loaded YAML

[STEP 3/3] Submitting to Kubernetes API...
✓ Successfully created resource in K8s

======================================================================
✓ BATCH SERVICE COMPLETED SUCCESSFULLY
======================================================================
```

### STEP 9: Verify Resource in Ab Initio Operator Namespace

Check that the CooperatingSystem resource was created in the abinitio-operator namespace:

```bash
# List CooperatingSystem resources
kubectl get cooperatingsystems -n abinitio-operator

# Get specific resource
kubectl get cooperatingsystem sample-cooperating-system -n abinitio-operator -o yaml

# Describe the resource
kubectl describe cooperatingsystem sample-cooperating-system -n abinitio-operator

# Check operator logs
kubectl logs -n abinitio-operator -l app=abinitio-operator --tail=50
```

**Test Commands:**
```bash
# Check if resource exists
kubectl get cooperatingsystem sample-cooperating-system -n abinitio-operator -o jsonpath='{.metadata.name}'

# Get resource status
kubectl get cooperatingsystem sample-cooperating-system -n abinitio-operator -o jsonpath='{.status}'
```

## Troubleshooting

### Issue: Cannot connect to EKS cluster

```bash
# Re-run kubeconfig setup
./scripts/setup-kubeconfig-okta.sh

# Verify AWS credentials
aws sts get-caller-identity

# Check kubectl config
kubectl config current-context
kubectl config get-contexts
```

### Issue: Health check fails

```bash
# Test API endpoint manually
curl -v https://abinitio-api-bi-dev/health

# Check if you can resolve DNS
nslookup abinitio-api-bi-dev

# Test from within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl https://abinitio-api-bi-dev/health
```

### Issue: Permission denied when submitting to abinitio-operator namespace

```bash
# Check RBAC resources
kubectl get sa abinitio-batch-sa -n bi-abi-apps-dev
kubectl get role abinitio-operator-writer -n abinitio-operator
kubectl get rolebinding abinitio-batch-operator-access -n abinitio-operator

# Describe role to see permissions
kubectl describe role abinitio-operator-writer -n abinitio-operator

# Check if ServiceAccount has proper bindings
kubectl describe rolebinding abinitio-batch-operator-access -n abinitio-operator
```

### Issue: Job fails with ImagePullBackOff

```bash
# Check if image exists in ECR
aws ecr describe-images --repository-name abinitio-batch-service --region us-east-1

# Verify image URI in Job manifest
kubectl get job abinitio-batch-job -n bi-abi-apps-dev -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check ECR permissions
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
```

### Issue: Pod stuck in pending state

```bash
# Check pod events
kubectl describe pod $POD_NAME -n bi-abi-apps-dev

# Check node resources
kubectl top nodes

# Check if there are any resource quotas
kubectl get resourcequota -n bi-abi-apps-dev
```

### View Job History

```bash
# List all jobs
kubectl get jobs -n bi-abi-apps-dev

# List all pods including completed
kubectl get pods -n bi-abi-apps-dev --show-all

# Delete completed job
kubectl delete job abinitio-batch-job -n bi-abi-apps-dev
```

## Cleanup

```bash
# Delete the job
kubectl delete job abinitio-batch-job -n bi-abi-apps-dev

# Delete ConfigMap
kubectl delete configmap abinitio-runtime-config -n bi-abi-apps-dev

# Delete RBAC resources
kubectl delete -f k8s/rbac.yaml

# Delete CooperatingSystem resource
kubectl delete cooperatingsystem sample-cooperating-system -n abinitio-operator

# Remove local virtual environment
rm -rf venv
```

## Development Workflow

### Quick Test Cycle

1. Make code changes to `src/abinitio_batch_service.py`
2. Test locally: `./scripts/test-local.sh`
3. Build and push: `./scripts/build-and-push.sh`
4. Deploy: `./scripts/deploy-to-eks.sh`
5. Monitor: `kubectl logs -n bi-abi-apps-dev -l job=abinitio-batch-job --follow`

### Update Runtime YAML

1. Edit `k8s/configmap.yaml`
2. Apply: `kubectl apply -f k8s/configmap.yaml`
3. Redeploy job: `./scripts/deploy-to-eks.sh`

## Security Notes

- Never commit credentials or secrets to the repository
- Use AWS Secrets Manager or Kubernetes Secrets for sensitive data
- Ensure Okta OIDC tokens have appropriate expiration
- Review RBAC permissions regularly
- Use least privilege principle for ServiceAccount permissions

## Next Steps

- Add monitoring and alerting for job failures
- Implement retry logic with exponential backoff
- Add Prometheus metrics for observability
- Set up automated testing in CI/CD pipeline
- Configure job scheduling with CronJob if needed
