#!/bin/bash
#
# Build Docker image and push to Nexus Repository
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration - UPDATE THESE VALUES
NEXUS_REGISTRY="${NEXUS_REGISTRY:-nexus.your-domain.com:8082}"
NEXUS_REPOSITORY="${NEXUS_REPOSITORY:-docker-hosted}"
IMAGE_NAME="${IMAGE_NAME:-abinitio-batch-service}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Nexus credentials (use environment variables or prompt)
NEXUS_USERNAME="${NEXUS_USERNAME:-}"
NEXUS_PASSWORD="${NEXUS_PASSWORD:-}"

FULL_IMAGE_NAME="${NEXUS_REGISTRY}/${NEXUS_REPOSITORY}/${IMAGE_NAME}:${IMAGE_TAG}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build and Push Docker Image to Nexus${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Registry: ${NEXUS_REGISTRY}"
echo -e "Repository: ${NEXUS_REPOSITORY}"
echo -e "Image: ${FULL_IMAGE_NAME}"
echo -e "${GREEN}========================================${NC}"

# Check prerequisites
echo -e "\n${YELLOW}[1/4] Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not found. Please install Docker.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker found${NC}"

# Get Nexus credentials if not set
if [ -z "$NEXUS_USERNAME" ]; then
    read -p "Enter Nexus username: " NEXUS_USERNAME
fi

if [ -z "$NEXUS_PASSWORD" ]; then
    read -sp "Enter Nexus password: " NEXUS_PASSWORD
    echo
fi

# Login to Nexus Docker registry
echo -e "\n${YELLOW}[2/4] Logging in to Nexus Docker registry...${NC}"
echo "$NEXUS_PASSWORD" | docker login --username "$NEXUS_USERNAME" --password-stdin ${NEXUS_REGISTRY}

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Logged in to Nexus${NC}"
else
    echo -e "${RED}✗ Failed to login to Nexus${NC}"
    exit 1
fi

# Build Docker image
echo -e "\n${YELLOW}[3/4] Building Docker image...${NC}"
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${FULL_IMAGE_NAME}
echo -e "${GREEN}✓ Docker image built${NC}"

# Push to Nexus
echo -e "\n${YELLOW}[4/4] Pushing image to Nexus...${NC}"
docker push ${FULL_IMAGE_NAME}
echo -e "${GREEN}✓ Image pushed to Nexus${NC}"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Build and push completed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nImage URI: ${FULL_IMAGE_NAME}"
echo -e "\nNext steps:"
echo -e "  1. Update IAC repo's values-dev.yaml with image URI"
echo -e "  2. Or update k8s/abinitio-batch-job.yaml for local testing"
echo -e "  3. Deploy: ./scripts/deploy-to-eks.sh"
