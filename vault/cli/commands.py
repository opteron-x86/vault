import os
import subprocess
from pathlib import Path
from typing import Optional

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