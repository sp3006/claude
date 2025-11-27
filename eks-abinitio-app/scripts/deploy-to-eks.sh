#!/bin/bash
#
# Deploy Ab Initio Batch Job to EKS
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

NAMESPACE="bi-abi-apps-dev"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deploy Ab Initio Batch Job to EKS${NC}"
echo -e "${GREEN}========================================${NC}"

# Check kubectl connection
echo -e "\n${YELLOW}[1/6] Verifying kubectl connection...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    echo -e "${YELLOW}Please run: ./scripts/setup-kubeconfig-okta.sh${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Connected to cluster${NC}"

# Verify namespace exists
echo -e "\n${YELLOW}[2/6] Verifying namespace exists...${NC}"
if ! kubectl get namespace ${NAMESPACE} &> /dev/null; then
    echo -e "${RED}✗ Namespace ${NAMESPACE} does not exist${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Namespace ${NAMESPACE} exists${NC}"

# Apply RBAC resources
echo -e "\n${YELLOW}[3/6] Applying RBAC resources...${NC}"
kubectl apply -f k8s/rbac.yaml
echo -e "${GREEN}✓ RBAC resources applied${NC}"

# Apply ConfigMap
echo -e "\n${YELLOW}[4/6] Applying ConfigMap...${NC}"
kubectl apply -f k8s/configmap.yaml
echo -e "${GREEN}✓ ConfigMap applied${NC}"

# Delete existing job if present
echo -e "\n${YELLOW}[5/6] Cleaning up existing job...${NC}"
if kubectl get job abinitio-batch-job -n ${NAMESPACE} &> /dev/null; then
    kubectl delete job abinitio-batch-job -n ${NAMESPACE}
    echo -e "${GREEN}✓ Existing job deleted${NC}"
else
    echo -e "${GREEN}✓ No existing job to delete${NC}"
fi

# Apply Job
echo -e "\n${YELLOW}[6/6] Deploying batch job...${NC}"
kubectl apply -f k8s/abinitio-batch-job.yaml
echo -e "${GREEN}✓ Batch job deployed${NC}"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment completed!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\nMonitor the job:"
echo -e "  kubectl get jobs -n ${NAMESPACE}"
echo -e "  kubectl get pods -n ${NAMESPACE} -l job=abinitio-batch-job"
echo -e "\nView logs:"
echo -e "  kubectl logs -n ${NAMESPACE} -l job=abinitio-batch-job --follow"
echo -e "\nCheck job status:"
echo -e "  kubectl describe job abinitio-batch-job -n ${NAMESPACE}"
