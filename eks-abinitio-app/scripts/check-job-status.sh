#!/bin/bash
#
# Simple script to check EKS job status
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="${NAMESPACE:-bi-abi-apps-dev}"
JOB_NAME="${1:-}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}EKS Job Status Checker${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Namespace: ${NAMESPACE}"
echo -e "${GREEN}========================================${NC}\n"

# Function to get job status
get_job_status() {
    local job=$1
    local status=$(kubectl get job $job -n $NAMESPACE -o jsonpath='{.status.conditions[0].type}' 2>/dev/null)
    local succeeded=$(kubectl get job $job -n $NAMESPACE -o jsonpath='{.status.succeeded}' 2>/dev/null)
    local failed=$(kubectl get job $job -n $NAMESPACE -o jsonpath='{.status.failed}' 2>/dev/null)
    local active=$(kubectl get job $job -n $NAMESPACE -o jsonpath='{.status.active}' 2>/dev/null)

    if [ "$status" == "Complete" ] || [ "$succeeded" == "1" ]; then
        echo -e "${GREEN}✓ COMPLETED${NC}"
    elif [ "$failed" -gt 0 ] 2>/dev/null; then
        echo -e "${RED}✗ FAILED${NC}"
    elif [ "$active" -gt 0 ] 2>/dev/null; then
        echo -e "${YELLOW}⟳ RUNNING${NC}"
    else
        echo -e "${BLUE}⊙ PENDING${NC}"
    fi
}

# If specific job name provided
if [ -n "$JOB_NAME" ]; then
    echo -e "${BLUE}Job: ${JOB_NAME}${NC}\n"

    # Check if job exists
    if ! kubectl get job $JOB_NAME -n $NAMESPACE &>/dev/null; then
        echo -e "${RED}✗ Job '${JOB_NAME}' not found in namespace '${NAMESPACE}'${NC}"
        exit 1
    fi

    # Get job details
    echo -e "${YELLOW}Job Details:${NC}"
    kubectl get job $JOB_NAME -n $NAMESPACE

    echo -e "\n${YELLOW}Job Status:${NC}"
    kubectl describe job $JOB_NAME -n $NAMESPACE | grep -A 5 "Status:"

    # Get pod status
    echo -e "\n${YELLOW}Pod Status:${NC}"
    kubectl get pods -n $NAMESPACE -l job-name=$JOB_NAME

    # Get pod logs if exists
    POD_NAME=$(kubectl get pods -n $NAMESPACE -l job-name=$JOB_NAME -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [ -n "$POD_NAME" ]; then
        echo -e "\n${YELLOW}Recent Logs (last 20 lines):${NC}"
        kubectl logs $POD_NAME -n $NAMESPACE --tail=20 2>/dev/null || echo "No logs available yet"

        echo -e "\n${BLUE}To view full logs, run:${NC}"
        echo -e "  kubectl logs -f $POD_NAME -n $NAMESPACE"
    fi

else
    # List all jobs
    echo -e "${YELLOW}All Jobs in namespace '${NAMESPACE}':${NC}\n"

    # Check if any jobs exist
    JOB_COUNT=$(kubectl get jobs -n $NAMESPACE --no-headers 2>/dev/null | wc -l | tr -d ' ')

    if [ "$JOB_COUNT" -eq 0 ]; then
        echo -e "${YELLOW}No jobs found in namespace '${NAMESPACE}'${NC}"
        exit 0
    fi

    # Print table header
    printf "%-40s %-15s %-10s %-10s %-10s\n" "JOB NAME" "STATUS" "SUCCEEDED" "FAILED" "ACTIVE"
    echo "-----------------------------------------------------------------------------------------------------------"

    # List all jobs with status
    kubectl get jobs -n $NAMESPACE --no-headers | while read job completions duration age; do
        status=$(get_job_status $job)
        succeeded=$(kubectl get job $job -n $NAMESPACE -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "0")
        failed=$(kubectl get job $job -n $NAMESPACE -o jsonpath='{.status.failed}' 2>/dev/null || echo "0")
        active=$(kubectl get job $job -n $NAMESPACE -o jsonpath='{.status.active}' 2>/dev/null || echo "0")

        printf "%-40s %-25s %-10s %-10s %-10s\n" "$job" "$status" "$succeeded" "$failed" "$active"
    done

    echo -e "\n${BLUE}To check specific job, run:${NC}"
    echo -e "  ./scripts/check-job-status.sh <job-name>"
    echo -e "\n${BLUE}To view logs for a specific job:${NC}"
    echo -e "  kubectl logs -f -l job-name=<job-name> -n $NAMESPACE"
fi

echo -e "\n${GREEN}========================================${NC}"
