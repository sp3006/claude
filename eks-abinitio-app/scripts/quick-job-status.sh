#!/bin/bash
#
# Quick one-liner job status check
#

NAMESPACE="${NAMESPACE:-bi-abi-apps-dev}"

if [ -n "$1" ]; then
    # Specific job
    echo "Job: $1"
    kubectl get job $1 -n $NAMESPACE 2>/dev/null || echo "Job not found"
    echo ""
    echo "Pods:"
    kubectl get pods -n $NAMESPACE -l job-name=$1 2>/dev/null || echo "No pods found"
else
    # All jobs
    echo "All Jobs in $NAMESPACE:"
    kubectl get jobs -n $NAMESPACE
fi
