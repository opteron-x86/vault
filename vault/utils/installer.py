import platform
import subprocess
from dataclasses import dataclass
from enum import Enum
from typing import Optional


class OS(str, Enum):
    LINUX = "linux"
    MACOS = "darwin"
    WINDOWS = "windows"
    UNKNOWN = "unknown"


class PackageManager(str, Enum):
    APT = "apt"
    YUM = "yum"
    BREW = "brew"
    CURL = "curl"
    UNKNOWN = "unknown"


@dataclass
class InstallCommand:
    description: str
    commands: list[str]
    requires_sudo: bool = False


class CSPInstaller:
    def __init__(self):
        self.os = self._detect_os()
        self.pkg_manager = self._detect_package_manager()
    
    def _detect_os(self) -> OS:
        system = platform.system().lower()
        if "linux" in system:
            return OS.LINUX
        elif "darwin" in system:
            return OS.MACOS
        elif "windows" in system:
            return OS.WINDOWS
        return OS.UNKNOWN
    
    def _detect_package_manager(self) -> PackageManager:
        if self.os == OS.MACOS:
            if self._command_exists("brew"):
                return PackageManager.BREW
        elif self.os == OS.LINUX:
            if self._command_exists("apt-get"):
                return PackageManager.APT
            elif self._command_exists("yum"):
                return PackageManager.YUM
        return PackageManager.CURL
    
    def _command_exists(self, command: str) -> bool:
        try:
            subprocess.run(
                ["which", command] if self.os != OS.WINDOWS else ["where", command],
                capture_output=True,
                check=False
            )
            return True
        except Exception:
            return False
    
    def check_installed(self, tool: str) -> tuple[bool, Optional[str]]:
        version_commands = {
            "aws": ["aws", "--version"],
            "az": ["az", "version"],
            "gcloud": ["gcloud", "version"],
            "terraform": ["terraform", "version"],
        }
        
        cmd = version_commands.get(tool)
        if not cmd:
            return False, None
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False
            )
            if result.returncode == 0:
                version_line = result.stdout.strip().split('\n')[0]
                return True, version_line
        except FileNotFoundError:
            pass
        
        return False, None
    
    def get_install_instructions(self, tool: str) -> Optional[InstallCommand]:
        if tool == "aws":
            return self._get_aws_install()
        elif tool == "az":
            return self._get_azure_install()
        elif tool == "gcloud":
            return self._get_gcloud_install()
        elif tool == "terraform":
            return self._get_terraform_install()
        return None
    
    def _get_aws_install(self) -> InstallCommand:
        if self.os == OS.MACOS:
            if self.pkg_manager == PackageManager.BREW:
                return InstallCommand(
                    description="Install AWS CLI via Homebrew",
                    commands=["brew install awscli"]
                )
        elif self.os == OS.LINUX:
            return InstallCommand(
                description="Install AWS CLI via curl",
                commands=[
                    "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'",
                    "unzip awscliv2.zip",
                    "sudo ./aws/install",
                    "rm -rf aws awscliv2.zip"
                ],
                requires_sudo=True
            )
        
        return InstallCommand(
            description="Install AWS CLI via pip",
            commands=["pip install awscli"]
        )
    
    def _get_azure_install(self) -> InstallCommand:
        if self.os == OS.MACOS:
            if self.pkg_manager == PackageManager.BREW:
                return InstallCommand(
                    description="Install Azure CLI via Homebrew",
                    commands=["brew install azure-cli"]
                )
        elif self.os == OS.LINUX:
            if self.pkg_manager == PackageManager.APT:
                return InstallCommand(
                    description="Install Azure CLI via apt",
                    commands=[
                        "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
                    ],
                    requires_sudo=True
                )
            elif self.pkg_manager == PackageManager.YUM:
                return InstallCommand(
                    description="Install Azure CLI via yum",
                    commands=[
                        "sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc",
                        "sudo sh -c 'echo -e \"[azure-cli]\\nname=Azure CLI\\nbaseurl=https://packages.microsoft.com/yumrepos/azure-cli\\nenabled=1\\ngpgcheck=1\\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\" > /etc/yum.repos.d/azure-cli.repo'",
                        "sudo yum install azure-cli"
                    ],
                    requires_sudo=True
                )
        
        return InstallCommand(
            description="Install Azure CLI via pip",
            commands=["pip install azure-cli"]
        )
    
    def _get_gcloud_install(self) -> InstallCommand:
        if self.os == OS.MACOS:
            if self.pkg_manager == PackageManager.BREW:
                return InstallCommand(
                    description="Install gcloud via Homebrew",
                    commands=["brew install google-cloud-sdk"]
                )
        elif self.os == OS.LINUX:
            return InstallCommand(
                description="Install gcloud SDK",
                commands=[
                    "curl https://sdk.cloud.google.com | bash",
                    "exec -l $SHELL",
                    "gcloud init"
                ]
            )
        
        return InstallCommand(
            description="Install gcloud SDK",
            commands=["Visit: https://cloud.google.com/sdk/docs/install"]
        )
    
    def _get_terraform_install(self) -> InstallCommand:
        if self.os == OS.MACOS:
            if self.pkg_manager == PackageManager.BREW:
                return InstallCommand(
                    description="Install Terraform via Homebrew",
                    commands=["brew tap hashicorp/tap", "brew install hashicorp/tap/terraform"]
                )
        elif self.os == OS.LINUX:
            return InstallCommand(
                description="Install Terraform",
                commands=[
                    "wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg",
                    "echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" | sudo tee /etc/apt/sources.list.d/hashicorp.list",
                    "sudo apt update && sudo apt install terraform"
                ],
                requires_sudo=True
            )
        
        return InstallCommand(
            description="Download Terraform binary",
            commands=["Visit: https://www.terraform.io/downloads"]
        )
    
    def install_tool(self, tool: str) -> bool:
        instructions = self.get_install_instructions(tool)
        if not instructions:
            return False
        
        for cmd in instructions.commands:
            if cmd.startswith("Visit:"):
                return False
            
            try:
                subprocess.run(
                    cmd,
                    shell=True,
                    check=True
                )
            except subprocess.CalledProcessError:
                return False
        
        return True