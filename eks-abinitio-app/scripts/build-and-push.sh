#!/bin/bash
#
# Build Docker image and push to ECR
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration - UPDATE THESE VALUES
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-123456789012}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPOSITORY="${ECR_REPOSITORY:-abinitio-batch-service}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
FULL_IMAGE_NAME="${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build and Push Docker Image to ECR${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Image: ${FULL_IMAGE_NAME}"
echo -e "${GREEN}========================================${NC}"

# Check prerequisites
echo -e "\n${YELLOW}[1/5] Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not found. Please install Docker.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker found${NC}"

if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI not found. Please install AWS CLI.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI found${NC}"

# Login to ECR
echo -e "\n${YELLOW}[2/5] Logging in to Amazon ECR...${NC}"
aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin ${ECR_REGISTRY}
echo -e "${GREEN}✓ Logged in to ECR${NC}"

# Create ECR repository if it doesn't exist
echo -e "\n${YELLOW}[3/5] Ensuring ECR repository exists...${NC}"
if ! aws ecr describe-repositories --repository-names ${ECR_REPOSITORY} --region ${AWS_REGION} &> /dev/null; then
    echo "Creating ECR repository: ${ECR_REPOSITORY}"
    aws ecr create-repository \
        --repository-name ${ECR_REPOSITORY} \
        --region ${AWS_REGION} \
        --image-scanning-configuration scanOnPush=true
    echo -e "${GREEN}✓ ECR repository created${NC}"
else
    echo -e "${GREEN}✓ ECR repository already exists${NC}"
fi

# Build Docker image
echo -e "\n${YELLOW}[4/5] Building Docker image...${NC}"
docker build -t ${ECR_REPOSITORY}:${IMAGE_TAG} .
docker tag ${ECR_REPOSITORY}:${IMAGE_TAG} ${FULL_IMAGE_NAME}
echo -e "${GREEN}✓ Docker image built${NC}"

# Push to ECR
echo -e "\n${YELLOW}[5/5] Pushing image to ECR...${NC}"
docker push ${FULL_IMAGE_NAME}
echo -e "${GREEN}✓ Image pushed to ECR${NC}"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Build and push completed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nImage URI: ${FULL_IMAGE_NAME}"
echo -e "\nNext steps:"
echo -e "  1. Update k8s/abinitio-batch-job.yaml with image URI"
echo -e "  2. Deploy to EKS: ./scripts/deploy-to-eks.sh"
