import subprocess
from abc import ABC, abstractmethod
from pathlib import Path

from vault.core.lab import CloudProvider, Lab


class BaseProvider(ABC):
    def __init__(self, config_dir: Path):
        self.config_dir = config_dir
    
    @abstractmethod
    def check_prerequisites(self) -> bool:
        pass
    
    @abstractmethod
    def get_var_files(self, lab: Lab) -> list[Path]:
        pass
    
    @abstractmethod
    def get_region(self) -> str:
        pass
    
    @abstractmethod
    def get_config_template(self) -> str:
        pass
    
    def ensure_config_exists(self) -> Path:
        config_file = self.config_dir / self.get_config_filename()
        
        if not config_file.exists():
            self.config_dir.mkdir(parents=True, exist_ok=True)
            config_file.write_text(self.get_config_template())
        
        return config_file
    
    @abstractmethod
    def get_config_filename(self) -> str:
        pass


class AWSProvider(BaseProvider):
    def check_prerequisites(self) -> bool:
        try:
            result = subprocess.run(
                ["aws", "--version"],
                capture_output=True,
                check=False
            )
            return result.returncode == 0
        except FileNotFoundError:
            from vault.cli.formatting import log_error, log_info
            log_error("AWS CLI not found")
            log_info("Run 'vault check' to see installation status")
            log_info("Run 'vault install aws' for installation instructions")
            return False
    
    def get_var_files(self, lab: Lab) -> list[Path]:
        var_files = []
        
        common_config = self.config_dir / "common-aws.tfvars"
        if common_config.exists():
            var_files.append(common_config)
        
        lab_config = lab.terraform_dir / "terraform.tfvars"
        if lab_config.exists():
            var_files.append(lab_config)
        elif (lab.terraform_dir / "terraform.tfvars.example").exists():
            var_files.append(lab.terraform_dir / "terraform.tfvars.example")
        
        return var_files
    
    def get_region(self) -> str:
        config_file = self.config_dir / "common-aws.tfvars"
        if config_file.exists():
            content = config_file.read_text()
            for line in content.splitlines():
                if "aws_region" in line and "=" in line:
                    return line.split("=")[1].strip(' "')
        return "us-east-1"
    
    def get_config_template(self) -> str:
        return '''aws_region = "us-east-1"
allowed_source_ips = ["YOUR_IP/32"]
'''
    
    def get_config_filename(self) -> str:
        return "common-aws.tfvars"


class AzureProvider(BaseProvider):
    def check_prerequisites(self) -> bool:
        try:
            result = subprocess.run(
                ["az", "--version"],
                capture_output=True,
                check=False
            )
            return result.returncode == 0
        except FileNotFoundError:
            from vault.cli.formatting import log_error, log_info
            log_error("Azure CLI not found")
            log_info("Run 'vault check' to see installation status")
            log_info("Run 'vault install az' for installation instructions")
            return False
    
    def get_var_files(self, lab: Lab) -> list[Path]:
        var_files = []
        
        common_config = self.config_dir / "common-azure.tfvars"
        if common_config.exists():
            var_files.append(common_config)
        
        lab_config = lab.terraform_dir / "terraform.tfvars"
        if lab_config.exists():
            var_files.append(lab_config)
        
        return var_files
    
    def get_region(self) -> str:
        config_file = self.config_dir / "common-azure.tfvars"
        if config_file.exists():
            content = config_file.read_text()
            for line in content.splitlines():
                if "azure_region" in line and "=" in line:
                    return line.split("=")[1].strip(' "')
        return "usgovvirginia"
    
    def get_config_template(self) -> str:
        return '''azure_region = "usgovvirginia"
'''
    
    def get_config_filename(self) -> str:
        return "common-azure.tfvars"


class GCPProvider(BaseProvider):
    def check_prerequisites(self) -> bool:
        try:
            result = subprocess.run(
                ["gcloud", "--version"],
                capture_output=True,
                check=False
            )
            return result.returncode == 0
        except FileNotFoundError:
            from vault.cli.formatting import log_error, log_info
            log_error("gcloud CLI not found")
            log_info("Run 'vault check' to see installation status")
            log_info("Run 'vault install gcloud' for installation instructions")
            return False
    
    def get_var_files(self, lab: Lab) -> list[Path]:
        var_files = []
        
        common_config = self.config_dir / "common-gcp.tfvars"
        if common_config.exists():
            var_files.append(common_config)
        
        lab_config = lab.terraform_dir / "terraform.tfvars"
        if lab_config.exists():
            var_files.append(lab_config)
        
        return var_files
    
    def get_region(self) -> str:
        config_file = self.config_dir / "common-gcp.tfvars"
        if config_file.exists():
            content = config_file.read_text()
            for line in content.splitlines():
                if "gcp_region" in line and "=" in line:
                    return line.split("=")[1].strip(' "')
        return "us-east4"
    
    def get_config_template(self) -> str:
        return '''gcp_project = "YOUR_PROJECT_ID"
gcp_region = "us-east4"
'''
    
    def get_config_filename(self) -> str:
        return "common-gcp.tfvars"


class ProviderFactory:
    _providers: dict[CloudProvider, type[BaseProvider]] = {
        CloudProvider.AWS: AWSProvider,
        CloudProvider.AZURE: AzureProvider,
        CloudProvider.GCP: GCPProvider,
    }
    
    @classmethod
    def get_provider(
        cls,
        provider_type: CloudProvider,
        config_dir: Path
    ) -> BaseProvider:
        provider_class = cls._providers.get(provider_type)
        
        if not provider_class:
            raise ValueError(f"Unsupported provider: {provider_type}")
        
        return provider_class(config_dir)