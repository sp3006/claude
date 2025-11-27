#!/usr/bin/env python3
"""
Ab Initio Batch Service - Submit CooperatingSystem Runtime YAML to K8s API
"""

import os
import sys
import requests
import yaml
from kubernetes import client, config
from kubernetes.client.rest import ApiException

# Configuration from environment variables
ABINITIO_API_BASE = os.getenv('ABINITIO_API_BASE', 'https://abinitio-api-bi-dev')
ABINITIO_OPERATOR_NAMESPACE = os.getenv('ABINITIO_OPERATOR_NAMESPACE', 'abinitio-operator')
RUNTIME_YAML_PATH = os.getenv('RUNTIME_YAML_PATH', '/app/config/runtime.yaml')


def check_health():
    """Check Ab Initio API health endpoint"""
    try:
        print(f"Checking health endpoint: {ABINITIO_API_BASE}/health")
        response = requests.get(
            f"{ABINITIO_API_BASE}/health",
            timeout=10,
            verify=True
        )
        response.raise_for_status()
        print(f"✓ Health check passed: Status {response.status_code}")
        print(f"  Response: {response.text[:200]}")
        return True
    except requests.exceptions.RequestException as e:
        print(f"✗ Health check failed: {e}")
        return False


def load_runtime_yaml(yaml_path):
    """Load cooperating system runtime YAML file"""
    try:
        print(f"Loading runtime YAML from: {yaml_path}")
        with open(yaml_path, 'r') as f:
            runtime_spec = yaml.safe_load(f)
        print(f"✓ Successfully loaded YAML")
        print(f"  Kind: {runtime_spec.get('kind')}")
        print(f"  Name: {runtime_spec.get('metadata', {}).get('name')}")
        return runtime_spec
    except FileNotFoundError:
        print(f"✗ YAML file not found: {yaml_path}")
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"✗ Invalid YAML format: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"✗ Failed to load YAML: {e}")
        sys.exit(1)


def submit_to_k8s(runtime_spec, namespace):
    """Submit runtime YAML to K8s API via abinitio operator namespace"""
    try:
        # Load kubernetes config
        try:
            config.load_incluster_config()
            print("✓ Using in-cluster Kubernetes config")
        except config.ConfigException:
            config.load_kube_config()
            print("✓ Using local kubeconfig file")

        # Create API client
        api = client.CustomObjectsApi()

        # Extract resource details from runtime spec
        api_version = runtime_spec.get('apiVersion', '')
        if '/' in api_version:
            group, version = api_version.split('/', 1)
        else:
            group = ''
            version = api_version

        kind = runtime_spec.get('kind', '')
        plural = kind.lower() + 's'
        name = runtime_spec.get('metadata', {}).get('name', 'unknown')

        print(f"\nSubmitting to Kubernetes API:")
        print(f"  API Version: {api_version}")
        print(f"  Kind: {kind}")
        print(f"  Name: {name}")
        print(f"  Namespace: {namespace}")

        # Create or update the custom resource
        try:
            response = api.create_namespaced_custom_object(
                group=group,
                version=version,
                namespace=namespace,
                plural=plural,
                body=runtime_spec
            )
            print(f"✓ Successfully created resource in K8s")
        except ApiException as e:
            if e.status == 409:
                print(f"Resource already exists, updating...")
                response = api.patch_namespaced_custom_object(
                    group=group,
                    version=version,
                    namespace=namespace,
                    plural=plural,
                    name=name,
                    body=runtime_spec
                )
                print(f"✓ Successfully updated resource in K8s")
            else:
                raise

        return response

    except ApiException as e:
        print(f"✗ Kubernetes API error: {e.status} - {e.reason}")
        print(f"  Details: {e.body}")
        sys.exit(1)
    except Exception as e:
        print(f"✗ Unexpected error: {type(e).__name__}: {e}")
        sys.exit(1)


def main():
    """Main execution flow"""
    print("=" * 70)
    print("Ab Initio Batch Service - CooperatingSystem Runtime Submission")
    print("=" * 70)
    print(f"Configuration:")
    print(f"  API Base: {ABINITIO_API_BASE}")
    print(f"  Operator Namespace: {ABINITIO_OPERATOR_NAMESPACE}")
    print(f"  Runtime YAML: {RUNTIME_YAML_PATH}")
    print("=" * 70)

    # Step 1: Health check
    print("\n[STEP 1/3] Checking Ab Initio API health...")
    if not check_health():
        print("\n✗ Health check failed. Aborting.")
        sys.exit(1)

    # Step 2: Load runtime YAML
    print(f"\n[STEP 2/3] Loading CooperatingSystem runtime YAML...")
    runtime_spec = load_runtime_yaml(RUNTIME_YAML_PATH)

    # Step 3: Submit to K8s API
    print(f"\n[STEP 3/3] Submitting to Kubernetes API...")
    result = submit_to_k8s(runtime_spec, ABINITIO_OPERATOR_NAMESPACE)

    print("\n" + "=" * 70)
    print("✓ BATCH SERVICE COMPLETED SUCCESSFULLY")
    print("=" * 70)


if __name__ == "__main__":
    main()
