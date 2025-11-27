#!/usr/bin/env python3
"""
Ab Initio API Client - REST API wrapper for Ab Initio operations
"""

import requests
import json
from typing import Dict, Any, Optional
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


class AbInitioAPIClient:
    """Client for interacting with Ab Initio REST API"""

    def __init__(self, base_url: str, timeout: int = 30, verify_ssl: bool = True):
        """
        Initialize the API client

        Args:
            base_url: Base URL for the API (e.g., https://abinitio-api-bi-abi-apps-dev.cluster)
            timeout: Request timeout in seconds
            verify_ssl: Whether to verify SSL certificates
        """
        self.base_url = base_url.rstrip('/')
        self.timeout = timeout
        self.verify_ssl = verify_ssl
        self.session = self._create_session()

    def _create_session(self) -> requests.Session:
        """Create a requests session with retry logic"""
        session = requests.Session()

        # Configure retry strategy
        retry_strategy = Retry(
            total=3,
            backoff_factor=1,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["HEAD", "GET", "OPTIONS", "POST", "DELETE"]
        )

        adapter = HTTPAdapter(max_retries=retry_strategy)
        session.mount("http://", adapter)
        session.mount("https://", adapter)

        return session

    def health_check(self) -> Dict[str, Any]:
        """
        Check API health status

        Returns:
            Dict containing health status response

        Example:
            GET https://abinitio-api-bi-abi-apps-dev.cluster/health
        """
        url = f"{self.base_url}/health"
        print(f"[API] Health Check: GET {url}")

        try:
            response = self.session.get(
                url,
                timeout=self.timeout,
                verify=self.verify_ssl
            )
            response.raise_for_status()

            print(f"✓ Health check passed: {response.status_code}")
            return {
                "status": "healthy",
                "status_code": response.status_code,
                "response": response.json() if response.text else {}
            }

        except requests.exceptions.RequestException as e:
            print(f"✗ Health check failed: {e}")
            return {
                "status": "unhealthy",
                "error": str(e)
            }

    def submit_job(self, job_spec: Dict[str, Any]) -> Dict[str, Any]:
        """
        Submit a new Ab Initio job

        Args:
            job_spec: Job specification dictionary

        Returns:
            Dict containing job submission response

        Example:
            POST https://abinitio-api-bi-abi-apps-dev.cluster/abinitio/jobs
            Body: {
                "name": "job-name",
                "graph": "path/to/graph.mp",
                "parameters": {...}
            }
        """
        url = f"{self.base_url}/abinitio/jobs"
        print(f"[API] Submit Job: POST {url}")
        print(f"  Job Name: {job_spec.get('name', 'N/A')}")

        try:
            response = self.session.post(
                url,
                json=job_spec,
                timeout=self.timeout,
                verify=self.verify_ssl,
                headers={"Content-Type": "application/json"}
            )
            response.raise_for_status()

            result = response.json() if response.text else {}
            print(f"✓ Job submitted successfully")
            print(f"  Job ID: {result.get('job_id', 'N/A')}")
            print(f"  Status: {result.get('status', 'N/A')}")

            return {
                "success": True,
                "status_code": response.status_code,
                "data": result
            }

        except requests.exceptions.RequestException as e:
            print(f"✗ Job submission failed: {e}")
            return {
                "success": False,
                "error": str(e),
                "status_code": getattr(e.response, 'status_code', None) if hasattr(e, 'response') else None
            }

    def cancel_job(self, job_name: str) -> Dict[str, Any]:
        """
        Cancel a running Ab Initio job

        Args:
            job_name: Name of the job to cancel

        Returns:
            Dict containing cancellation response

        Example:
            DELETE https://abinitio-api-bi-abi-apps-dev.cluster/abinitio/jobs/{name}
        """
        url = f"{self.base_url}/abinitio/jobs/{job_name}"
        print(f"[API] Cancel Job: DELETE {url}")

        try:
            response = self.session.delete(
                url,
                timeout=self.timeout,
                verify=self.verify_ssl
            )
            response.raise_for_status()

            result = response.json() if response.text else {}
            print(f"✓ Job cancelled successfully")
            print(f"  Job: {job_name}")
            print(f"  Status: {result.get('status', 'N/A')}")

            return {
                "success": True,
                "status_code": response.status_code,
                "data": result
            }

        except requests.exceptions.RequestException as e:
            print(f"✗ Job cancellation failed: {e}")
            return {
                "success": False,
                "error": str(e),
                "status_code": getattr(e.response, 'status_code', None) if hasattr(e, 'response') else None
            }

    def get_job_status(self, job_name: str) -> Dict[str, Any]:
        """
        Get status of an Ab Initio job

        Args:
            job_name: Name of the job

        Returns:
            Dict containing job status

        Example:
            GET https://abinitio-api-bi-abi-apps-dev.cluster/abinitio/jobs/{name}
        """
        url = f"{self.base_url}/abinitio/jobs/{job_name}"
        print(f"[API] Get Job Status: GET {url}")

        try:
            response = self.session.get(
                url,
                timeout=self.timeout,
                verify=self.verify_ssl
            )
            response.raise_for_status()

            result = response.json() if response.text else {}
            print(f"✓ Job status retrieved")
            print(f"  Job: {job_name}")
            print(f"  Status: {result.get('status', 'N/A')}")
            print(f"  Progress: {result.get('progress', 'N/A')}")

            return {
                "success": True,
                "status_code": response.status_code,
                "data": result
            }

        except requests.exceptions.RequestException as e:
            print(f"✗ Failed to get job status: {e}")
            return {
                "success": False,
                "error": str(e),
                "status_code": getattr(e.response, 'status_code', None) if hasattr(e, 'response') else None
            }

    def close(self):
        """Close the session"""
        self.session.close()
