#!/usr/bin/env python3
"""
Ab Initio Batch Service - Main orchestrator for Ab Initio operations
Supports: Health Check, Submit Job, Cancel Job, Get Job Status
"""

import os
import sys
import yaml
import json
import time
from typing import Dict, Any
from abinitio_api_client import AbInitioAPIClient


# Configuration from environment variables
ABINITIO_API_BASE = os.getenv('ABINITIO_API_BASE', 'https://abinitio-api-bi-abi-apps-dev.cluster')
JOB_SPEC_PATH = os.getenv('JOB_SPEC_PATH', '/app/config/job_spec.yaml')
OPERATION = os.getenv('OPERATION', 'submit')  # submit, cancel, status, health
JOB_NAME = os.getenv('JOB_NAME', '')  # Required for cancel and status operations
POLL_INTERVAL = int(os.getenv('POLL_INTERVAL', '10'))  # Seconds between status checks
MAX_POLL_ATTEMPTS = int(os.getenv('MAX_POLL_ATTEMPTS', '60'))  # Max polling attempts


def load_job_spec(yaml_path: str) -> Dict[str, Any]:
    """Load job specification from YAML file"""
    try:
        print(f"Loading job specification from: {yaml_path}")
        with open(yaml_path, 'r') as f:
            job_spec = yaml.safe_load(f)
        print(f"✓ Successfully loaded job spec")
        print(f"  Job Name: {job_spec.get('name', 'N/A')}")
        print(f"  Graph: {job_spec.get('graph', 'N/A')}")
        return job_spec
    except FileNotFoundError:
        print(f"✗ Job spec file not found: {yaml_path}")
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"✗ Invalid YAML format: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"✗ Failed to load job spec: {e}")
        sys.exit(1)


def operation_health_check(client: AbInitioAPIClient) -> bool:
    """Execute health check operation"""
    print("\n" + "=" * 70)
    print("OPERATION: Health Check")
    print("=" * 70)

    result = client.health_check()

    if result.get('status') == 'healthy':
        print("\n✓ Health check passed")
        return True
    else:
        print(f"\n✗ Health check failed: {result.get('error', 'Unknown error')}")
        return False


def operation_submit_job(client: AbInitioAPIClient, job_spec: Dict[str, Any]) -> bool:
    """Execute job submission operation"""
    print("\n" + "=" * 70)
    print("OPERATION: Submit Job")
    print("=" * 70)

    # First, health check
    print("\n[1/2] Performing health check...")
    health = client.health_check()
    if health.get('status') != 'healthy':
        print("✗ Health check failed. Aborting job submission.")
        return False

    # Submit the job
    print("\n[2/2] Submitting job...")
    result = client.submit_job(job_spec)

    if result.get('success'):
        print("\n✓ Job submitted successfully")
        job_data = result.get('data', {})
        print(f"  Job ID: {job_data.get('job_id', 'N/A')}")
        print(f"  Status: {job_data.get('status', 'N/A')}")
        return True
    else:
        print(f"\n✗ Job submission failed: {result.get('error', 'Unknown error')}")
        return False


def operation_cancel_job(client: AbInitioAPIClient, job_name: str) -> bool:
    """Execute job cancellation operation"""
    print("\n" + "=" * 70)
    print("OPERATION: Cancel Job")
    print("=" * 70)

    if not job_name:
        print("✗ Job name is required for cancel operation")
        print("  Set JOB_NAME environment variable")
        return False

    result = client.cancel_job(job_name)

    if result.get('success'):
        print(f"\n✓ Job '{job_name}' cancelled successfully")
        return True
    else:
        print(f"\n✗ Failed to cancel job '{job_name}': {result.get('error', 'Unknown error')}")
        return False


def operation_get_status(client: AbInitioAPIClient, job_name: str, poll: bool = False) -> bool:
    """Execute get job status operation"""
    print("\n" + "=" * 70)
    print("OPERATION: Get Job Status")
    print("=" * 70)

    if not job_name:
        print("✗ Job name is required for status operation")
        print("  Set JOB_NAME environment variable")
        return False

    if poll:
        print(f"Polling enabled: Will check status every {POLL_INTERVAL}s (max {MAX_POLL_ATTEMPTS} attempts)")

    attempt = 0
    while True:
        attempt += 1
        print(f"\n[Attempt {attempt}/{MAX_POLL_ATTEMPTS if poll else 1}]")

        result = client.get_job_status(job_name)

        if not result.get('success'):
            print(f"\n✗ Failed to get job status: {result.get('error', 'Unknown error')}")
            return False

        job_data = result.get('data', {})
        status = job_data.get('status', 'UNKNOWN')
        progress = job_data.get('progress', 'N/A')

        print(f"\nJob Status:")
        print(f"  Name: {job_name}")
        print(f"  Status: {status}")
        print(f"  Progress: {progress}")

        # Check if job is in terminal state
        if status in ['COMPLETED', 'FAILED', 'CANCELLED']:
            print(f"\n✓ Job reached terminal state: {status}")
            return status == 'COMPLETED'

        # If not polling or max attempts reached, exit
        if not poll or attempt >= MAX_POLL_ATTEMPTS:
            break

        # Wait before next poll
        print(f"\nWaiting {POLL_INTERVAL}s before next check...")
        time.sleep(POLL_INTERVAL)

    if poll and attempt >= MAX_POLL_ATTEMPTS:
        print(f"\n⚠ Max polling attempts reached. Job is still in '{status}' state.")

    return True


def main():
    """Main execution flow"""
    print("=" * 70)
    print("Ab Initio Batch Service")
    print("=" * 70)
    print(f"Configuration:")
    print(f"  API Base: {ABINITIO_API_BASE}")
    print(f"  Operation: {OPERATION}")
    print(f"  Job Name: {JOB_NAME or 'N/A'}")
    print("=" * 70)

    # Initialize API client
    client = AbInitioAPIClient(
        base_url=ABINITIO_API_BASE,
        timeout=30,
        verify_ssl=True
    )

    success = False

    try:
        # Execute operation based on OPERATION env var
        if OPERATION == 'health':
            success = operation_health_check(client)

        elif OPERATION == 'submit':
            job_spec = load_job_spec(JOB_SPEC_PATH)
            success = operation_submit_job(client, job_spec)

        elif OPERATION == 'cancel':
            success = operation_cancel_job(client, JOB_NAME)

        elif OPERATION == 'status':
            poll = os.getenv('POLL', 'false').lower() == 'true'
            success = operation_get_status(client, JOB_NAME, poll=poll)

        else:
            print(f"\n✗ Unknown operation: {OPERATION}")
            print(f"  Supported operations: health, submit, cancel, status")
            sys.exit(1)

    finally:
        client.close()

    # Final status
    print("\n" + "=" * 70)
    if success:
        print("✓ OPERATION COMPLETED SUCCESSFULLY")
    else:
        print("✗ OPERATION FAILED")
    print("=" * 70)

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
