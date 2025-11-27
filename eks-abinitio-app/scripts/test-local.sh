#!/bin/bash
#
# Test the batch service locally
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Local Testing - Ab Initio Batch Service${NC}"
echo -e "${GREEN}========================================${NC}"

# Check Python
echo -e "\n${YELLOW}[1/5] Checking Python installation...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}✗ Python3 not found${NC}"
    exit 1
fi
PYTHON_VERSION=$(python3 --version)
echo -e "${GREEN}✓ ${PYTHON_VERSION}${NC}"

# Create virtual environment
echo -e "\n${YELLOW}[2/5] Setting up virtual environment...${NC}"
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo -e "${GREEN}✓ Virtual environment created${NC}"
else
    echo -e "${GREEN}✓ Virtual environment already exists${NC}"
fi

# Activate virtual environment and install dependencies
echo -e "\n${YELLOW}[3/5] Installing dependencies...${NC}"
source venv/bin/activate
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt
echo -e "${GREEN}✓ Dependencies installed${NC}"

# Set environment variables for local testing
export ABINITIO_API_BASE="${ABINITIO_API_BASE:-https://abinitio-api-bi-dev}"
export ABINITIO_OPERATOR_NAMESPACE="${ABINITIO_OPERATOR_NAMESPACE:-abinitio-operator}"
export RUNTIME_YAML_PATH="config/runtime.yaml"

echo -e "\n${YELLOW}[4/5] Configuration:${NC}"
echo -e "  API Base: ${ABINITIO_API_BASE}"
echo -e "  Operator Namespace: ${ABINITIO_OPERATOR_NAMESPACE}"
echo -e "  Runtime YAML: ${RUNTIME_YAML_PATH}"

# Check kubeconfig
echo -e "\n${YELLOW}[5/5] Checking Kubernetes connection...${NC}"
if kubectl cluster-info &> /dev/null; then
    echo -e "${GREEN}✓ Connected to Kubernetes cluster${NC}"
    kubectl config current-context
else
    echo -e "${YELLOW}⚠ Not connected to Kubernetes cluster${NC}"
    echo -e "${YELLOW}  The script will fail when trying to submit to K8s API${NC}"
    echo -e "${YELLOW}  Run ./scripts/setup-kubeconfig-okta.sh first${NC}"
fi

# Run the script
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Running batch service...${NC}"
echo -e "${GREEN}========================================${NC}\n"

python3 src/abinitio_batch_service.py

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Local test completed!${NC}"
echo -e "${GREEN}========================================${NC}"
