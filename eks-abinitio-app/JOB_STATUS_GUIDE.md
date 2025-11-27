# EKS Job Status Checking Guide

Quick reference for checking job status in EKS.

## Scripts Available

### 1. Full Job Status Check (`check-job-status.sh`)
Detailed status checker with colored output, logs, and pod information.

### 2. Quick Job Status (`quick-job-status.sh`)
Simple one-liner for fast checks.

## Usage

### Check All Jobs

```bash
# Detailed view
./scripts/check-job-status.sh

# Quick view
./scripts/quick-job-status.sh
```

**Example Output:**
```
========================================
EKS Job Status Checker
========================================
Namespace: bi-abi-apps-dev
========================================

All Jobs in namespace 'bi-abi-apps-dev':

JOB NAME                                 STATUS          SUCCEEDED  FAILED     ACTIVE
-----------------------------------------------------------------------------------------------------------
abinitio-submit-job                      ✓ COMPLETED     1          0          0
abinitio-health-check                    ✓ COMPLETED     1          0          0
abinitio-status-job                      ⟳ RUNNING       0          0          1
```

### Check Specific Job

```bash
# Detailed view with logs
./scripts/check-job-status.sh abinitio-submit-job

# Quick view
./scripts/quick-job-status.sh abinitio-submit-job
```

**Example Output:**
```
Job: abinitio-submit-job

Job Details:
NAME                    COMPLETIONS   DURATION   AGE
abinitio-submit-job     1/1           45s        2m

Job Status:
Status:
  Completion Time:  2025-01-27T10:30:45Z
  Conditions:
    Status:            True
    Type:              Complete
  Succeeded:           1

Pod Status:
NAME                          READY   STATUS      RESTARTS   AGE
abinitio-submit-job-abc123    0/1     Completed   0          2m

Recent Logs (last 20 lines):
======================================================================
Ab Initio Batch Service
======================================================================
[1/2] Performing health check...
✓ Health check passed: 200
[2/2] Submitting job...
✓ Job submitted successfully
======================================================================
✓ OPERATION COMPLETED SUCCESSFULLY
======================================================================
```

### Check Job in Different Namespace

```bash
# Set namespace
export NAMESPACE="abinitio-operator"
./scripts/check-job-status.sh

# Or inline
NAMESPACE="abinitio-operator" ./scripts/check-job-status.sh
```

## Direct kubectl Commands

### List All Jobs
```bash
kubectl get jobs -n bi-abi-apps-dev
```

### Get Job Details
```bash
kubectl describe job abinitio-submit-job -n bi-abi-apps-dev
```

### View Pod Status for Job
```bash
kubectl get pods -n bi-abi-apps-dev -l job-name=abinitio-submit-job
```

### View Job Logs
```bash
# Follow logs in real-time
kubectl logs -f -l job-name=abinitio-submit-job -n bi-abi-apps-dev

# Get logs from specific pod
POD_NAME=$(kubectl get pods -n bi-abi-apps-dev -l job-name=abinitio-submit-job -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD_NAME -n bi-abi-apps-dev

# Last 100 lines
kubectl logs -l job-name=abinitio-submit-job -n bi-abi-apps-dev --tail=100
```

### Delete Completed Job
```bash
kubectl delete job abinitio-submit-job -n bi-abi-apps-dev
```

### Delete All Completed Jobs
```bash
kubectl delete jobs -n bi-abi-apps-dev --field-selector status.successful=1
```

## Job Status Types

| Status | Description |
|--------|-------------|
| ✓ COMPLETED | Job finished successfully |
| ✗ FAILED | Job failed (check logs) |
| ⟳ RUNNING | Job is currently running |
| ⊙ PENDING | Job is waiting to start |

## Common Issues

### Job Stuck in Pending
```bash
# Check pod events
kubectl get pods -n bi-abi-apps-dev -l job-name=<job-name>
kubectl describe pod <pod-name> -n bi-abi-apps-dev
```

### Job Failed
```bash
# View logs for failed job
kubectl logs -l job-name=<job-name> -n bi-abi-apps-dev --previous

# Get failure reason
kubectl describe job <job-name> -n bi-abi-apps-dev | grep -A 10 "Events:"
```

### No Logs Available
```bash
# Check if pod exists
kubectl get pods -n bi-abi-apps-dev -l job-name=<job-name>

# Check pod status
kubectl describe pod <pod-name> -n bi-abi-apps-dev
```

## Monitoring Jobs

### Watch Jobs in Real-Time
```bash
watch kubectl get jobs -n bi-abi-apps-dev
```

### Monitor Specific Job
```bash
# Watch job status
watch kubectl get job abinitio-submit-job -n bi-abi-apps-dev

# Follow logs
kubectl logs -f -l job-name=abinitio-submit-job -n bi-abi-apps-dev
```

### Get Job Metrics
```bash
# Get job start time
kubectl get job abinitio-submit-job -n bi-abi-apps-dev -o jsonpath='{.status.startTime}'

# Get job completion time
kubectl get job abinitio-submit-job -n bi-abi-apps-dev -o jsonpath='{.status.completionTime}'

# Calculate duration
kubectl get job abinitio-submit-job -n bi-abi-apps-dev -o json | jq -r '.status | "Duration: \((.completionTime | fromdateiso8601) - (.startTime | fromdateiso8601)) seconds"'
```

## Aliases (Add to ~/.bashrc or ~/.zshrc)

```bash
# Quick job status
alias jobstatus='kubectl get jobs -n bi-abi-apps-dev'

# Job logs
alias joblogs='kubectl logs -f -n bi-abi-apps-dev -l job-name='

# Delete completed jobs
alias jobclean='kubectl delete jobs -n bi-abi-apps-dev --field-selector status.successful=1'

# Watch jobs
alias jobwatch='watch kubectl get jobs -n bi-abi-apps-dev'
```

## Quick Reference

```bash
# Check all jobs
./scripts/check-job-status.sh

# Check specific job
./scripts/check-job-status.sh abinitio-submit-job

# Quick check
./scripts/quick-job-status.sh

# View logs
kubectl logs -f -l job-name=abinitio-submit-job -n bi-abi-apps-dev

# Delete job
kubectl delete job abinitio-submit-job -n bi-abi-apps-dev
```
