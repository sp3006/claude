#!/bin/bash
#
# Setup kubeconfig for EKS with Okta OIDC Authentication
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration - UPDATE THESE VALUES
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-your-eks-cluster-name}"
AWS_REGION="${AWS_REGION:-us-east-1}"
OKTA_IDP_ARN="${OKTA_IDP_ARN:-arn:aws:iam::ACCOUNT_ID:oidc-provider/YOUR_OKTA_ISSUER}"
OKTA_CLIENT_ID="${OKTA_CLIENT_ID:-your-okta-client-id}"
OKTA_ISSUER_URL="${OKTA_ISSUER_URL:-https://your-domain.okta.com}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}EKS Kubeconfig Setup with Okta OIDC${NC}"
echo -e "${GREEN}========================================${NC}"

# Check prerequisites
echo -e "\n${YELLOW}[1/5] Checking prerequisites...${NC}"

if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI not found. Please install: https://aws.amazon.com/cli/${NC}"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI found${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not found. Please install: https://kubernetes.io/docs/tasks/tools/${NC}"
    exit 1
fi
echo -e "${GREEN}✓ kubectl found${NC}"

# Update kubeconfig for EKS cluster
echo -e "\n${YELLOW}[2/5] Updating kubeconfig for EKS cluster...${NC}"
aws eks update-kubeconfig \
    --region ${AWS_REGION} \
    --name ${EKS_CLUSTER_NAME}

echo -e "${GREEN}✓ Kubeconfig updated${NC}"

# Configure OIDC authentication
echo -e "\n${YELLOW}[3/5] Configuring Okta OIDC authentication...${NC}"

kubectl config set-credentials okta-user \
    --exec-api-version=client.authentication.k8s.io/v1beta1 \
    --exec-command=aws \
    --exec-arg=eks \
    --exec-arg=get-token \
    --exec-arg=--cluster-name \
    --exec-arg=${EKS_CLUSTER_NAME} \
    --exec-arg=--region \
    --exec-arg=${AWS_REGION}

echo -e "${GREEN}✓ OIDC credentials configured${NC}"

# Set the context to use OIDC credentials
echo -e "\n${YELLOW}[4/5] Setting context to use OIDC authentication...${NC}"

CONTEXT_NAME="arn:aws:eks:${AWS_REGION}:$(aws sts get-caller-identity --query Account --output text):cluster/${EKS_CLUSTER_NAME}"
kubectl config set-context ${CONTEXT_NAME} --user=okta-user

echo -e "${GREEN}✓ Context configured${NC}"

# Test connection
echo -e "\n${YELLOW}[5/5] Testing connection to EKS cluster...${NC}"

if kubectl get nodes &> /dev/null; then
    echo -e "${GREEN}✓ Successfully connected to EKS cluster${NC}"
    echo -e "\n${GREEN}Current context:${NC}"
    kubectl config current-context
    echo -e "\n${GREEN}Available namespaces:${NC}"
    kubectl get namespaces | grep -E "(NAME|bi-abi-apps-dev|abinitio-operator)" || kubectl get namespaces
else
    echo -e "${RED}✗ Failed to connect to EKS cluster${NC}"
    echo -e "${YELLOW}Please check your Okta authentication and AWS credentials${NC}"
    exit 1
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Setup completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nYou can now run kubectl commands:"
echo -e "  kubectl get pods -n bi-abi-apps-dev"
echo -e "  kubectl get pods -n abinitio-operator"
