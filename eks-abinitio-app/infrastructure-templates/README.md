# Infrastructure Templates

This directory contains templates for the Infrastructure/Config repository.

## Repository Structure

```
Application Repo (this repo)         Infrastructure Repo (separate)
├── src/                             ├── k8s/abinitio-batch-service/
│   ├── abinitio_api_client.py      │   ├── values-dev.yaml
│   └── abinitio_batch_service.py   │   ├── deployment.yaml (or Job)
├── Dockerfile                       │   ├── configmap.yaml
└── requirements.txt                 │   ├── secrets.yaml
                                     │   └── rbac.yaml
                                     └── argocd/
                                         └── abinitio-batch-service.yaml
```

## Files to Copy to Infrastructure Repo

### 1. `values-dev.yaml`

Copy to: `<infrastructure-repo>/k8s/abinitio-batch-service/values-dev.yaml`

This file contains:
- Database names and connection details
- S3 bucket names
- IAM role ARNs
- Private project paths
- Image references (docker-appimage-bi-snp-ss-prod-us-east-1:cmi_prem:202510061127)
- Secrets references
- Resource limits

**Update these values:**
- `image.repository` - Your ECR repository
- `image.tag` - Your image tag
- `database.*` - Your database configuration
- `s3.bucket` - Your S3 bucket name
- `iam.serviceAccount.annotations` - Your IAM role ARN
- `paths.*` - Your Ab Initio project paths

### 2. `argocd-application.yaml`

Copy to: `<infrastructure-repo>/argocd/abinitio-batch-service.yaml`

This file defines the ArgoCD Application that deploys your batch service.

**Update these values:**
- `spec.source.repoURL` - Your infrastructure repository URL
- `spec.source.path` - Path to your k8s manifests
- `spec.destination.server` - Your EKS cluster server

## Integration Steps

### Step 1: Prepare Infrastructure Repo

```bash
# In your infrastructure repository
cd <infrastructure-repo>

# Create directory structure
mkdir -p k8s/abinitio-batch-service
mkdir -p argocd

# Copy templates
cp <app-repo>/infrastructure-templates/values-dev.yaml k8s/abinitio-batch-service/
cp <app-repo>/infrastructure-templates/argocd-application.yaml argocd/abinitio-batch-service.yaml
```

### Step 2: Create Kubernetes Manifests in Infrastructure Repo

Create these files in `k8s/abinitio-batch-service/`:

**configmap.yaml:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: abinitio-app-config
  namespace: bi-abi-apps-dev
data:
  ABINITIO_API_BASE: {{ .Values.api.baseUrl }}
  OPERATION: "submit"
  DB_HOST: {{ .Values.database.host }}
  DB_PORT: {{ .Values.database.port | quote }}
  DB_NAME: {{ .Values.database.name }}
  S3_BUCKET: {{ .Values.s3.bucket }}
  S3_PREFIX: {{ .Values.s3.prefix }}
```

**job.yaml:**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: abinitio-batch-job
  namespace: {{ .Values.app.namespace }}
spec:
  backoffLimit: {{ .Values.job.backoffLimit }}
  ttlSecondsAfterFinished: {{ .Values.job.ttlSecondsAfterFinished }}
  template:
    spec:
      serviceAccountName: {{ .Values.iam.serviceAccount.name }}
      containers:
      - name: batch-service
        image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
        envFrom:
        - configMapRef:
            name: abinitio-app-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ .Values.database.secrets.passwordSecretName }}
              key: {{ .Values.database.secrets.passwordSecretKey }}
        resources: {{- toYaml .Values.job.resources | nindent 10 }}
```

### Step 3: Configure Secrets

Create secrets in your infrastructure repo (use external-secrets operator or sealed-secrets):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: bi-abi-apps-dev
type: Opaque
data:
  password: <base64-encoded-password>
```

### Step 4: Deploy with ArgoCD

```bash
# Apply ArgoCD application
kubectl apply -f argocd/abinitio-batch-service.yaml

# Watch deployment
argocd app get abinitio-batch-service
argocd app sync abinitio-batch-service
```

## Environment-Specific Configuration

Create multiple values files for different environments:

- `values-dev.yaml` - Development environment
- `values-staging.yaml` - Staging environment
- `values-prod.yaml` - Production environment

Each file references environment-specific:
- Image tags
- Database names
- S3 buckets
- IAM roles
- Resource limits

## Secrets Management

**Option 1: External Secrets Operator**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: abinitio-db-credentials
spec:
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: db-credentials
  data:
  - secretKey: password
    remoteRef:
      key: /abinitio/dev/db-password
```

**Option 2: Sealed Secrets**
```bash
kubectl create secret generic db-credentials \
  --from-literal=password='your-password' \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-db-credentials.yaml
```

## Testing

```bash
# Test with dry-run
argocd app create abinitio-batch-service \
  --file argocd/abinitio-batch-service.yaml \
  --dry-run

# Sync application
argocd app sync abinitio-batch-service

# Check status
argocd app get abinitio-batch-service
kubectl get job -n bi-abi-apps-dev
kubectl logs -n bi-abi-apps-dev -l job-name=abinitio-batch-job
```

## Updating Configuration

When you need to update configuration:

1. Update `values-dev.yaml` in infrastructure repo
2. Commit and push changes
3. ArgoCD will auto-sync (if automated sync is enabled)
4. Or manually sync: `argocd app sync abinitio-batch-service`

## Rollback

```bash
# List app history
argocd app history abinitio-batch-service

# Rollback to previous version
argocd app rollback abinitio-batch-service <revision-number>
```
