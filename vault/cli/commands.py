import os
import subprocess
from pathlib import Path
from typing import Optional, Any

from rich.prompt import Confirm

from vault.cli.formatting import (
    console,
    log_error,
    log_info,
    log_success,
    log_warning,
    print_active_deployments,
    print_deployment_result,
    print_lab_info,
    print_labs_table,
    print_outputs,
    print_status,
)
from vault.core.lab import Lab
from vault.core.state import StateManager
from vault.core.terraform import TerraformError, TerraformWrapper
from vault.providers.base import ProviderFactory
from vault.utils.installer import CSPInstaller
from vault.utils.search import LabDiscovery
from vault.utils.git import GitRepo

class CommandHandler:
    def __init__(
        self,
        labs_dir: Path,
        state_dir: Path,
        config_dir: Path
    ):
        self.labs_dir = labs_dir
        self.state_dir = state_dir
        self.config_dir = config_dir
        
        self.discovery = LabDiscovery(labs_dir)
        self.state_manager = StateManager(state_dir)
        self.terraform = TerraformWrapper(state_dir)
        self.installer = CSPInstaller()
        self.git = GitRepo(labs_dir.parent)
        
        self.current_lab: Optional[Lab] = None
    
    def cmd_list(self, query: Optional[str] = None) -> None:
        if query:
            results = self.discovery.search_labs(query)
            labs = [r.lab for r in results]
            
            if not labs:
                log_warning(f"No labs found matching '{query}'")
                return
            
            log_info(f"Found {len(labs)} lab(s) matching '{query}'")
        else:
            labs = self.discovery.discover_labs()
        
        deployed = {
            lab_path for lab_path, _ in self.state_manager.get_active_deployments()
        }
        
        print_labs_table(labs, show_status=True, deployed_labs=deployed)
    
    def cmd_use(self, lab_identifier: str) -> bool:
        lab = None
        
        if lab_identifier.isdigit():
            lab = self.discovery.get_lab_by_index(int(lab_identifier) - 1)
        else:
            lab = self.discovery.get_lab_by_path(lab_identifier)
        
        if not lab:
            log_error(f"Lab not found: {lab_identifier}")
            return False
        
        self.current_lab = lab
        log_success(f"Selected lab: {lab.relative_path}")
        return True
    
    def cmd_info(self, lab_identifier: Optional[str] = None) -> None:
        lab = self._resolve_lab(lab_identifier)
        if not lab:
            return
        
        status = self.state_manager.get_deployment_status(lab)
        metadata = self.state_manager.load_metadata(lab)
        print_lab_info(lab, metadata, status)
        
        if lab.has_readme:
            if Confirm.ask("View full README?", default=False):
                self._display_readme(lab)
    
    def cmd_deploy(self, lab_identifier: Optional[str] = None) -> bool:
        lab = self._resolve_lab(lab_identifier)
        if not lab:
            return False
        
        provider = ProviderFactory.get_provider(lab.provider, self.config_dir)
        
        if not provider.check_prerequisites():
            log_error("Prerequisites check failed")
            return False
        
        var_files = provider.get_var_files(lab)
        if not var_files:
            log_error(f"No configuration file found for {lab.provider.value}")
            return False
        
        for var_file in var_files:
            if not var_file.exists():
                log_error(f"Configuration file not found: {var_file}")
                log_info(f"Create {var_file} with required values")
                return False
        
        log_info(f"Initializing {lab.provider.value.upper()} lab: {lab.relative_path}")
        
        try:
            self.terraform.init(lab, var_files)
            log_success("Lab initialized")
        except TerraformError as e:
            log_error(f"Initialization failed: {e}")
            return False
        
        console.print("\n[bold cyan]Deployment Plan:[/bold cyan]\n")
        try:
            plan_output = self.terraform.plan(lab, var_files)
            console.print(plan_output)
        except TerraformError as e:
            log_error(f"Plan failed: {e}")
            return False
        
        if not Confirm.ask("\n[green]Proceed with deployment?[/green]", default=False):
            log_info("Deployment cancelled")
            return False
        
        log_info(f"Deploying lab: {lab.relative_path}")
        
        result = self.terraform.apply(lab, var_files, auto_approve=True)
        
        if result.success:
            region = provider.get_region()
            self.state_manager.save_metadata(
                lab,
                "deployed",
                os.getenv("USER", "unknown"),
                region
            )
        
        print_deployment_result(result, lab.relative_path)
        return result.success
    
    def cmd_destroy(self, lab_identifier: Optional[str] = None) -> bool:
        lab = self._resolve_lab(lab_identifier)
        if not lab:
            return False
        
        if not self.state_manager.is_deployed(lab):
            log_warning(f"Lab not deployed: {lab.relative_path}")
            return False
        
        provider = ProviderFactory.get_provider(lab.provider, self.config_dir)
        var_files = provider.get_var_files(lab)
        
        console.print(
            f"\n[red bold]WARNING:[/red bold] [red]This will destroy all resources for: {lab.relative_path}[/red]\n"
        )
        
        if not Confirm.ask(f"Type lab name to confirm ({lab.name})", default=""):
            confirmation = console.input("[yellow]Confirmation: [/yellow]")
            if confirmation != lab.name:
                log_info("Destruction cancelled")
                return False
        
        log_info(f"Destroying lab: {lab.relative_path}")
        
        try:
            success = self.terraform.destroy(lab, var_files, auto_approve=True)
            
            if success:
                region = provider.get_region()
                self.state_manager.save_metadata(
                    lab,
                    "destroyed",
                    os.getenv("USER", "unknown"),
                    region
                )
                
                log_success("Lab destroyed successfully")
                
                if self.current_lab == lab:
                    self.current_lab = None
            else:
                log_error("Destruction failed")
            
            return success
        except TerraformError as e:
            log_error(f"Destruction failed: {e}")
            return False
    
    def cmd_outputs(
        self,
        lab_identifier: Optional[str] = None,
        show_sensitive: bool = False
    ) -> None:
        lab = self._resolve_lab(lab_identifier)
        if not lab:
            return
        
        if not self.state_manager.is_deployed(lab):
            log_error("Lab is not deployed")
            return
        
        try:
            outputs = self.terraform.get_outputs(lab)
            print_outputs(outputs, show_sensitive)
        except TerraformError as e:
            log_error(f"Failed to retrieve outputs: {e}")
    
    def cmd_status(self, lab_identifier: Optional[str] = None) -> None:
        lab = self._resolve_lab(lab_identifier)
        if not lab:
            return
        
        status = self.state_manager.get_deployment_status(lab)
        metadata = self.state_manager.load_metadata(lab)
        
        resources = []
        if self.state_manager.is_deployed(lab):
            try:
                resources = self.terraform.state_list(lab)
                key_resources = [
                    r for r in resources
                    if any(k in r.lower() for k in [
                        "instance", "bucket", "role", "user", 
                        "storage", "vault", "application", "principal"
                    ])
                ]
                resources = key_resources if key_resources else resources
            except TerraformError:
                pass
        
        print_status(lab, status, metadata, resources)
    
    def cmd_active(self) -> None:
        deployments = self.state_manager.get_active_deployments()
        print_active_deployments(deployments)
    
    def cmd_back(self) -> None:
        if self.current_lab:
            log_info(f"Deselected lab: {self.current_lab.relative_path}")
            self.current_lab = None
        else:
            log_warning("No lab currently selected")

    def cmd_check(self) -> None:
        """Check which CSP CLI tools are installed"""
        from rich.table import Table
        
        tools = [
            ("aws", "AWS CLI", "Amazon Web Services"),
            ("az", "Azure CLI", "Microsoft Azure"),
            ("gcloud", "gcloud", "Google Cloud Platform"),
            ("terraform", "Terraform", "Infrastructure as Code"),
        ]
        
        console.print("\n[bold cyan]CSP Tools Status:[/bold cyan]\n")
        
        table = Table(show_header=True)
        table.add_column("Tool", style="cyan", no_wrap=True)
        table.add_column("Status", style="white")
        table.add_column("Version", style="dim")
        
        for cmd, name, description in tools:
            installed, version = self.installer.check_installed(cmd)
            
            if installed:
                status = "[green]✓ Installed[/green]"
                version_str = version or "Unknown"
            else:
                status = "[red]✗ Not installed[/red]"
                version_str = "-"
            
            table.add_row(name, status, version_str)
        
        console.print(table)
        console.print("\n[dim]Use 'install <tool>' to install missing tools[/dim]")
        console.print("[dim]Example: install aws[/dim]\n")

    def cmd_setup(self, provider_name: Optional[str] = None) -> bool:
        """Interactive setup wizard for creating common-<csp>.tfvars files"""
        from rich.prompt import Prompt
        import requests
        
        providers_to_setup = []
        
        if provider_name:
            provider_name = provider_name.lower()
            if provider_name not in ["aws", "azure", "gcp", "all"]:
                log_error(f"Invalid provider: {provider_name}")
                log_info("Valid options: aws, azure, gcp, all")
                return False
            
            if provider_name == "all":
                providers_to_setup = ["aws", "azure", "gcp"]
            else:
                providers_to_setup = [provider_name]
        else:
            console.print("\n[bold cyan]VAULT Configuration Setup[/bold cyan]\n")
            console.print("This wizard will help you create configuration files for cloud providers.\n")
            
            choices = Prompt.ask(
                "Which provider(s) would you like to configure?",
                choices=["aws", "azure", "gcp", "all"],
                default="all"
            )
            
            if choices == "all":
                providers_to_setup = ["aws", "azure", "gcp"]
            else:
                providers_to_setup = [choices]
        
        self.config_dir.mkdir(exist_ok=True)
        
        for provider_str in providers_to_setup:
            if not self._setup_provider_config(provider_str):
                log_warning(f"Skipped {provider_str.upper()} configuration")
            console.print()
        
        log_success("Configuration setup complete!")
        log_info("You can now deploy labs using 'vault deploy <lab>'")
        return True

    def _setup_provider_config(self, provider_str: str) -> bool:
        """Setup configuration for a specific provider"""
        from rich.prompt import Prompt, Confirm
        import requests
        
        console.print(f"\n[bold cyan]Configuring {provider_str.upper()}[/bold cyan]")
        console.print("─" * 50)
        
        from vault.core.lab import CloudProvider
        provider_enum = CloudProvider[provider_str.upper()]
        provider = ProviderFactory.get_provider(provider_enum, self.config_dir)
        
        config_file = self.config_dir / provider.get_config_filename()
        
        if config_file.exists():
            console.print(f"\n[yellow]Configuration file already exists:[/yellow] {config_file}")
            if not Confirm.ask("Overwrite existing configuration?", default=False):
                return False
        
        if provider_str == "aws":
            return self._setup_aws_config(config_file)
        elif provider_str == "azure":
            return self._setup_azure_config(config_file)
        elif provider_str == "gcp":
            return self._setup_gcp_config(config_file)
        
        return False

    def _setup_aws_config(self, config_file: Path) -> bool:
        """Setup AWS configuration"""
        from rich.prompt import Prompt, Confirm
        import requests
        
        console.print("\n[dim]AWS Configuration requires:[/dim]")
        console.print("  • AWS Region")
        console.print("  • Allowed source IPs (for security groups)")
        console.print("  • (Optional) SSH key name\n")
        
        region = Prompt.ask(
            "AWS Region",
            default="us-gov-east-1"
        )
        
        public_ip = None
        if Confirm.ask("Auto-detect your public IP?", default=True):
            try:
                response = requests.get("https://api.ipify.org", timeout=5)
                if response.status_code == 200:
                    public_ip = response.text.strip()
                    console.print(f"[green]Detected IP:[/green] {public_ip}")
            except Exception as e:
                log_warning(f"Could not detect IP: {e}")
        
        if not public_ip:
            public_ip = Prompt.ask(
                "Your public IP address",
                default="0.0.0.0"
            )
        
        allowed_ips = f'["{public_ip}/32"]'
        
        if Confirm.ask("Add additional IP addresses?", default=False):
            additional = Prompt.ask("Enter additional IPs (comma-separated)")
            extra_ips = [f'"{ip.strip()}/32"' for ip in additional.split(",")]
            allowed_ips = f'["{public_ip}/32", {", ".join(extra_ips)}]'
        
        ssh_key = ""
        if Confirm.ask("Do you have an AWS SSH key pair configured?", default=False):
            key_name = Prompt.ask("SSH key name")
            ssh_key = f'\nssh_key_name = "{key_name}"'
        
        config_content = f'''# AWS Configuration for VAULT Labs
    # Auto-generated by vault setup

    aws_region = "{region}"
    allowed_source_ips = {allowed_ips}{ssh_key}
    '''
        
        config_file.write_text(config_content)
        log_success(f"Created: {config_file}")
        return True

    def _setup_azure_config(self, config_file: Path) -> bool:
        """Setup Azure configuration"""
        from rich.prompt import Prompt
        
        console.print("\n[dim]Azure Configuration requires:[/dim]")
        console.print("  • Azure Region\n")
        
        region = Prompt.ask(
            "Azure Region",
            default="usgovvirginia"
        )
        
        config_content = f'''# Azure Configuration for VAULT Labs
    # Auto-generated by vault setup

    azure_region = "{region}"
    '''
        
        config_file.write_text(config_content)
        log_success(f"Created: {config_file}")
        return True

    def _setup_gcp_config(self, config_file: Path) -> bool:
        """Setup GCP configuration"""
        from rich.prompt import Prompt, Confirm
        import subprocess
        
        console.print("\n[dim]GCP Configuration requires:[/dim]")
        console.print("  • GCP Project ID")
        console.print("  • GCP Region\n")
        
        project_id = None
        if Confirm.ask("Auto-detect GCP project from gcloud config?", default=True):
            try:
                result = subprocess.run(
                    ["gcloud", "config", "get-value", "project"],
                    capture_output=True,
                    text=True,
                    check=False
                )
                if result.returncode == 0 and result.stdout.strip():
                    project_id = result.stdout.strip()
                    console.print(f"[green]Detected project:[/green] {project_id}")
            except Exception as e:
                log_warning(f"Could not detect project: {e}")
        
        if not project_id:
            project_id = Prompt.ask("GCP Project ID")
        
        region = Prompt.ask(
            "GCP Region",
            default="us-east4"
        )
        
        config_content = f'''# GCP Configuration for VAULT Labs
    # Auto-generated by vault setup

    gcp_project = "{project_id}"
    gcp_region = "{region}"
    '''
        
        config_file.write_text(config_content)
        log_success(f"Created: {config_file}")
        return True
    
    def cmd_install(self, tool: str) -> bool:
        """Show installation instructions for a CSP tool"""
        valid_tools = ["aws", "az", "gcloud", "terraform"]
        
        if tool not in valid_tools:
            log_error(f"Unknown tool: {tool}")
            log_info(f"Valid tools: {', '.join(valid_tools)}")
            return False
        
        installed, version = self.installer.check_installed(tool)
        if installed:
            log_success(f"{tool} is already installed: {version}")
            return True
        
        instructions = self.installer.get_install_instructions(tool)
        if not instructions:
            log_error(f"No installation instructions available for: {tool}")
            return False
        
        console.print(f"\n[bold cyan]{instructions.description}[/bold cyan]\n")
        
        if instructions.requires_sudo:
            log_warning("These commands require sudo/administrator privileges")
        
        for i, cmd in enumerate(instructions.commands, 1):
            if cmd.startswith("Visit:"):
                console.print(f"[yellow]{cmd}[/yellow]")
            else:
                console.print(f"[dim]{i}.[/dim] [green]{cmd}[/green]")
        
        console.print()
        
        if not any(cmd.startswith("Visit:") for cmd in instructions.commands):
            if Confirm.ask("Execute these commands now?", default=False):
                log_info(f"Installing {tool}...")
                success = self.installer.install_tool(tool)
                if success:
                    log_success(f"{tool} installed successfully")
                    return True
                else:
                    log_error(f"Installation failed. Please run commands manually.")
                    return False
        
        return False

    def cmd_attack(self, lab_id: str | None = None, auto_destroy: bool = False, 
                verbose: bool = False, save_log: bool = False) -> bool:
        """Run automated attack chain against deployed lab"""
        lab = self._resolve_lab(lab_id)
        if not lab:
            return False
        
        metadata = self.state_manager.load_metadata(lab)
        if not metadata:
            log_error("Lab not deployed. Deploy first with: deploy")
            return False
        
        state_dir = self.state_manager.get_state_path(lab)
        outputs = self._get_terraform_outputs(state_dir)
        
        if not outputs:
            log_warning("No outputs available from lab")
        
        from vault.attacks import AttackChainLoader
        attack_class = AttackChainLoader.load(lab.provider.value, lab.name)
        
        if not attack_class:
            log_error(f"No attack chain available for {lab.provider.value}/{lab.name}")
            available = AttackChainLoader.list_available()
            if available:
                log_info(f"Available attack chains: {', '.join(available)}")
            return False
        
        console.print(f"\n[bold cyan]Starting automated attack chain for {lab.name}...[/bold cyan]")
        if verbose:
            console.print("[dim]Verbose mode enabled[/dim]")
        console.print()
        
        try:
            log_file = None
            if save_log:
                from datetime import datetime
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                log_file = f"attack_{lab.name}_{timestamp}.json"
            
            attack = attack_class(outputs, verbose=verbose, log_file=log_file)
            results = attack.run()
            
            self._display_attack_results(results, verbose=verbose)
            
            if auto_destroy and any(r.success for r in results):
                console.print("\n[yellow]Auto-destroying lab...[/yellow]")
                return self.cmd_destroy()
            
            return True
                
        except Exception as e:
            log_error(f"Attack failed: {str(e)}")
            import traceback
            traceback.print_exc()
            return False

    def _display_attack_results(self, results: list, verbose: bool = False) -> None:
        """Display attack chain results"""
        from rich.table import Table
        import re
        
        table = Table(title="Attack Chain Results", show_header=True)
        table.add_column("Phase", style="cyan", no_wrap=True)
        table.add_column("Status", style="bold", width=8)
        table.add_column("Message", overflow="fold")
        
        for result in results:
            status = "[green]✓[/green]" if result.success else "[red]✗[/red]"
            table.add_row(result.phase, status, result.message)
        
        console.print(table)
        
        # Show exfiltrated data with flags
        for result in results:
            if result.phase == "Data Exfiltration" and result.success and result.data:
                console.print("\n[bold cyan]Exfiltrated Data:[/bold cyan]")
                files = result.data.get('files', [])
                for file_info in files:
                    console.print(f"\n[yellow]File:[/yellow] {file_info['key']}")
                    console.print(f"[dim]Size: {file_info['size']} bytes[/dim]")
                    if file_info.get('has_flag'):
                        console.print(f"[bold green]FLAG: {file_info['flag']}[/bold green]")
        
        # Show verbose logs if enabled
        if verbose:
            console.print("\n[bold cyan]Detailed Execution Log:[/bold cyan]")
            for result in results:
                if result.verbose_log:
                    console.print(f"\n[bold]{result.phase}:[/bold]")
                    for log_entry in result.verbose_log:
                        console.print(f"[dim]{log_entry}[/dim]")
        
        success_count = sum(1 for r in results if r.success)
        total = len(results)
        
        if success_count == total:
            console.print(f"\n[bold green]✓ Attack chain complete: {success_count}/{total} phases successful[/bold green]")
        else:
            console.print(f"\n[bold yellow]⚠ Attack chain incomplete: {success_count}/{total} phases successful[/bold yellow]")

    def _get_terraform_outputs(self, state_dir) -> dict[str, Any]:
        """Extract outputs from terraform state"""
        import json
        import subprocess
        from typing import Any
        
        try:
            result = subprocess.run(
                ['terraform', 'output', '-json'],
                cwd=state_dir,
                capture_output=True,
                text=True,
                check=True
            )
            outputs_raw = json.loads(result.stdout)
            return {k: v['value'] for k, v in outputs_raw.items()}
        except subprocess.CalledProcessError:
            log_warning("Failed to retrieve terraform outputs")
            return {}
        except Exception as e:
            log_warning(f"Error parsing outputs: {e}")
            return {}
        
    def complete_attack(self, text: str, line: str, begidx: int, endidx: int) -> list[str]:
        """Tab completion for attack command"""
        from vault.attacks import AttackChainLoader
        available = AttackChainLoader.list_available()
        return [lab for lab in available if lab.startswith(text)]
    
    def cmd_git(self) -> None:
        """Show git repository status"""
        from rich.table import Table
        
        if not self.git.is_repo():
            log_warning("Not in a git repository")
            return
        
        status = self.git.get_status()
        if not status:
            log_error("Failed to get git status")
            return
        
        console.print("\n[bold cyan]Git Repository Status:[/bold cyan]\n")
        
        table = Table(show_header=False, box=None, padding=(0, 2))
        table.add_column(style="cyan", no_wrap=True)
        table.add_column(style="white")
        
        branch_display = status.branch
        if status.is_dirty:
            branch_display = f"{status.branch} [yellow]*[/yellow]"
        table.add_row("Branch:", branch_display)
        
        if status.ahead > 0:
            table.add_row("Ahead:", f"[green]{status.ahead} commit(s)[/green]")
        if status.behind > 0:
            table.add_row("Behind:", f"[red]{status.behind} commit(s)[/red]")
        
        if status.staged > 0:
            table.add_row("Staged:", f"[green]{status.staged} file(s)[/green]")
        if status.modified > 0:
            table.add_row("Modified:", f"[yellow]{status.modified} file(s)[/yellow]")
        if status.untracked > 0:
            table.add_row("Untracked:", f"[dim]{status.untracked} file(s)[/dim]")
        
        if not status.is_dirty and status.ahead == 0 and status.behind == 0:
            table.add_row("Status:", "[green]Clean[/green]")
        
        console.print(table)
        
        remote = self.git.get_remote_url()
        if remote:
            console.print(f"\n[cyan]Remote:[/cyan] {remote}")
        
        last_commit = self.git.get_last_commit()
        if last_commit:
            console.print(f"[cyan]Last commit:[/cyan] {last_commit}")
        
        console.print()

    def cmd_search(self, query: str) -> None:
        results = self.discovery.search_labs(query)
        
        if not results:
            log_warning(f"No labs found matching '{query}'")
            return
        
        log_info(f"Found {len(results)} lab(s) matching '{query}'")
        
        labs = [r.lab for r in results]
        deployed = {
            lab_path for lab_path, _ in self.state_manager.get_active_deployments()
        }
        
        print_labs_table(labs, show_status=True, deployed_labs=deployed)
    
    def cmd_validate(self, lab_identifier: Optional[str] = None) -> None:
        lab = self._resolve_lab(lab_identifier)
        if not lab:
            return
        
        log_info(f"Validating lab: {lab.relative_path}")
        
        try:
            valid, message = self.terraform.validate(lab)
            if valid:
                log_success("Validation successful")
                console.print(message)
            else:
                log_error("Validation failed")
                console.print(message, style="red")
        except TerraformError as e:
            log_error(f"Validation failed: {e}")

    def cmd_init(self, lab_identifier: Optional[str] = None) -> bool:
        lab = self._resolve_lab(lab_identifier)
        if not lab:
            return False
        
        provider = ProviderFactory.get_provider(lab.provider, self.config_dir)
        
        if not provider.check_prerequisites():
            log_error("Prerequisites check failed")
            return False
        
        var_files = provider.get_var_files(lab)
        
        log_info(f"Initializing lab: {lab.relative_path}")
        
        try:
            self.terraform.init(lab, var_files)
            log_success("Lab initialized successfully")
            log_info("Terraform providers downloaded and backend configured")
            return True
        except TerraformError as e:
            log_error(f"Initialization failed: {e}")
            return False

    def cmd_plan(self, lab_identifier: Optional[str] = None, destroy: bool = False) -> None:
        lab = self._resolve_lab(lab_identifier)
        if not lab:
            return
        
        provider = ProviderFactory.get_provider(lab.provider, self.config_dir)
        var_files = provider.get_var_files(lab)
        
        if not var_files:
            log_error(f"No configuration file found for {lab.provider.value}")
            return
        
        log_info(f"Generating {'destroy ' if destroy else ''}plan for: {lab.relative_path}")
        
        try:
            self.terraform.init(lab, var_files)
        except TerraformError as e:
            log_error(f"Initialization failed: {e}")
            return
        
        try:
            plan_output = self.terraform.plan(lab, var_files, destroy=destroy)
            console.print()
            console.print(plan_output)
        except TerraformError as e:
            log_error(f"Plan failed: {e}")
            
    def _resolve_lab(self, lab_identifier: Optional[str]) -> Optional[Lab]:
        if lab_identifier:
            if lab_identifier.isdigit():
                lab = self.discovery.get_lab_by_index(int(lab_identifier) - 1)
            else:
                lab = self.discovery.get_lab_by_path(lab_identifier)
            
            if not lab:
                log_error(f"Lab not found: {lab_identifier}")
            return lab
        
        if self.current_lab:
            return self.current_lab
        
        log_error("No lab selected. Use: <command> <lab> or 'use <lab>' first")
        return None
    
    def _display_readme(self, lab: Lab) -> None:
        if not lab.has_readme:
            log_warning("No README found")
            return
        
        from rich.markdown import Markdown
        
        try:
            content = lab.readme_path.read_text()
            md = Markdown(content)
            
            with console.pager():
                console.print(md)
        except Exception as e:
            log_error(f"Failed to display README: {e}")
    
    @staticmethod
    def _has_bat() -> bool:
        try:
            subprocess.run(
                ["bat", "--version"],
                capture_output=True,
                check=False
            )
            return True
        except FileNotFoundError:
            return False
    
    @staticmethod
    def _has_glow() -> bool:
        try:
            subprocess.run(
                ["glow", "--version"],
                capture_output=True,
                check=False
            )
            return True
        except FileNotFoundError:
            return False