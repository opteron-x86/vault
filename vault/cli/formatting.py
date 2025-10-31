from typing import Optional

from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.text import Text
from rich.tree import Tree

from vault.core.lab import CloudProvider, DeploymentStatus, Lab, LabMetadata

console = Console()


def print_banner(branch: Optional[str] = None, is_dirty: bool = False) -> None:
    banner = """
  ██╗   ██╗ █████╗ ██╗   ██╗██╗  ████████╗    ██████╗ ███████╗
  ██║   ██║██╔══██╗██║   ██║██║  ╚══██╔══╝    ╚════██╗██╔════╝
  ██║   ██║███████║██║   ██║██║     ██║        █████╔╝███████╗
  ╚██╗ ██╔╝██╔══██║██║   ██║██║     ██║        ╚═══██╗╚════██║
   ╚████╔╝ ██║  ██║╚██████╔╝███████╗██║       ██████╔╝███████║
    ╚═══╝  ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝       ╚═════╝ ╚══════╝
    """
    
    banner_width = 68
    
    console.print(banner, style="cyan bold")
    console.print(
        "Virtual Attack Utility Lab Terminal".rjust(banner_width),
        style="cyan"
    )
    console.print("─" * banner_width, style="dim")
    console.print("  Organization: [bold]DG35 - Cyber Threat Emulation[/bold]", style="dim")
    console.print("  Contact:      caleb.n.cline.ctr@mail.mil", style="dim")
    
    if branch:
        branch_display = f"[blue]{branch}[/blue]"
        if is_dirty:
            branch_display += " [yellow]*[/yellow]"
        console.print(f"  Git Branch:   {branch_display}", style="dim")
    
    console.print("─" * banner_width, style="dim")
    console.print("\n  Type [bold]help[/bold] for commands or [bold]exit[/bold] to quit\n", style="dim")


def print_labs_table(
    labs: list[Lab],
    show_status: bool = False,
    deployed_labs: Optional[set[str]] = None
) -> None:
    if deployed_labs is None:
        deployed_labs = set()
    
    tree = Tree("📚 [bold green]Available Labs[/bold green]")
    
    current_provider = None
    provider_node = None
    
    for idx, lab in enumerate(labs, 1):
        if current_provider != lab.provider:
            current_provider = lab.provider
            provider_icon = {
                CloudProvider.AWS: "☁️",
                CloudProvider.AZURE: "🔷",
                CloudProvider.GCP: "🔵"
            }.get(lab.provider, "❓")
            
            provider_node = tree.add(
                f"{provider_icon} [bold magenta]{lab.provider.value.upper()}[/bold magenta]"
            )
        
        status_indicator = ""
        if show_status and lab.relative_path in deployed_labs:
            status_indicator = " [green][DEPLOYED][/green]"
        '''
        difficulty_bar = lab.difficulty.bar(width=10)
        difficulty_text = f"[{lab.difficulty.color}]{difficulty_bar}[/{lab.difficulty.color}] {lab.difficulty.label}"
        '''
        lab_text = (
            f"[yellow]\\[{idx}][/yellow] "
            f"[bold]{lab.name}[/bold]{status_indicator} "
        #   f"{difficulty_text}"
        )
        '''
        if lab.description:
            lab_node = provider_node.add(lab_text)
            lab_node.add(f"[dim]{lab.description[:80]}...[/dim]" if len(lab.description) > 80 else f"[dim]{lab.description}[/dim]")
        else:
        '''
        provider_node.add(lab_text)
    
    console.print(tree)


def print_lab_info(lab: Lab, metadata: Optional[LabMetadata] = None, status: Optional[DeploymentStatus] = None) -> None:
    console.print()
    
    header_text = f"Lab: {lab.relative_path}"
    panel = Panel(
        header_text,
        style="cyan bold",
        border_style="cyan"
    )
    console.print(panel)
    
    info_table = Table(show_header=False, box=None, padding=(0, 2))
    info_table.add_column(style="cyan", no_wrap=True)
    info_table.add_column(style="white")
    
    info_table.add_row("Provider:", lab.provider.value.upper())
    
    if lab.difficulty.rating > 0:
        difficulty_display = f"[{lab.difficulty.color}]{lab.difficulty.bar()} {lab.difficulty}[/{lab.difficulty.color}]"
        info_table.add_row("Difficulty:", difficulty_display)
    
    if lab.estimated_time:
        info_table.add_row("Est. Time:", lab.estimated_time)
    
    if status and metadata:
        status_color = {
            DeploymentStatus.NOT_DEPLOYED: "yellow",
            DeploymentStatus.DEPLOYED: "green",
            DeploymentStatus.PARTIAL: "yellow",
            DeploymentStatus.ERROR: "red"
        }
        
        status_text = status.value.replace("_", " ").title()
        info_table.add_row("Status:", f"[{status_color[status]}]{status_text}[/{status_color[status]}]")
        
        if status == DeploymentStatus.DEPLOYED:
            info_table.add_row("Resources:", str(metadata.resources_count))
            info_table.add_row("Deployed by:", metadata.deployed_by)
            info_table.add_row("Deployed at:", metadata.timestamp.strftime("%Y-%m-%d %H:%M:%S UTC"))
            info_table.add_row("Region:", metadata.region)
    
    console.print(info_table)
    
    if lab.description:
        console.print(f"\n[bold]Description:[/bold]\n{lab.description}\n")
    
    if lab.learning_objectives:
        console.print("[bold]Learning Objectives:[/bold]")
        for obj in lab.learning_objectives:
            console.print(f"  • {obj}")
    
    console.print()

def print_deployment_result(result, lab_name: str) -> None:
    if result.success:
        console.print(f"\n[green]✓[/green] Lab [bold]{lab_name}[/bold] deployed successfully\n")
        
        if result.outputs:
            console.print("[bold cyan]Lab Access Information:[/bold cyan]")
            
            outputs_table = Table(show_header=False, box=None, padding=(0, 2))
            outputs_table.add_column(style="cyan", no_wrap=True)
            outputs_table.add_column(style="white")
            
            for key, output in result.outputs.items():
                if output.sensitive:
                    value = "[dim]<sensitive>[/dim]"
                else:
                    value = str(output.value)
                outputs_table.add_row(f"{key}:", value)
            
            console.print(outputs_table)
            console.print()
    else:
        console.print(f"\n[red]✗[/red] Deployment failed: {result.error_message}\n", style="red")


def print_active_deployments(deployments: list[tuple[str, LabMetadata]]) -> None:
    if not deployments:
        console.print("\n[dim]No active deployments[/dim]\n")
        return
    
    console.print("\n[bold green]Active Deployments:[/bold green]\n")
    
    table = Table(show_header=True)
    table.add_column("Lab", style="bold")
    table.add_column("Provider", style="magenta")
    table.add_column("Resources", justify="right", style="cyan")
    table.add_column("Deployed", style="dim")
    
    for lab_path, metadata in deployments:
        table.add_row(
            lab_path,
            metadata.csp.upper(),
            str(metadata.resources_count),
            metadata.timestamp.strftime("%Y-%m-%d %H:%M")
        )
    
    console.print(table)
    console.print()


def print_status(
    lab: Lab,
    status: DeploymentStatus,
    metadata: Optional[LabMetadata],
    resources: list[str]
) -> None:
    console.print(f"\n[bold cyan]Lab Status: [/bold cyan][bold]{lab.relative_path}[/bold]")
    console.print(f"[magenta]Provider: [/magenta]{lab.provider.value.upper()}\n")
    
    status_color = {
        DeploymentStatus.NOT_DEPLOYED: "yellow",
        DeploymentStatus.DEPLOYED: "green",
        DeploymentStatus.PARTIAL: "yellow",
        DeploymentStatus.ERROR: "red"
    }
    
    status_text = status.value.replace("_", " ").title()
    console.print(
        f"[cyan]Status:[/cyan] [{status_color[status]}]{status_text}[/{status_color[status]}]"
    )
    
    if metadata:
        console.print(f"[cyan]Resources:[/cyan] {metadata.resources_count}")
        console.print(f"[cyan]Deployed by:[/cyan] {metadata.deployed_by}")
        console.print(f"[cyan]Deployed at:[/cyan] {metadata.timestamp.strftime('%Y-%m-%d %H:%M:%S UTC')}")
        console.print(f"[cyan]Region:[/cyan] {metadata.region}")
    
    if resources:
        console.print(f"\n[bold]Key Resources:[/bold]")
        for resource in resources[:10]:
            console.print(f"  • {resource}")
        if len(resources) > 10:
            console.print(f"  [dim]... and {len(resources) - 10} more[/dim]")
    
    console.print()


def print_outputs(outputs: dict, show_sensitive: bool = False) -> None:
    if not outputs:
        console.print("\n[dim]No outputs available[/dim]\n")
        return
    
    console.print("\n[bold cyan]Lab Outputs:[/bold cyan]\n")
    
    table = Table(show_header=True)
    table.add_column("Name", style="cyan")
    table.add_column("Value", style="white")
    
    for key, output in outputs.items():
        if output.sensitive and not show_sensitive:
            value = "[dim]<sensitive>[/dim]"
        else:
            value = str(output.value)
        
        table.add_row(key, value)
    
    console.print(table)
    
    if not show_sensitive and any(o.sensitive for o in outputs.values()):
        console.print("\n[dim]Use 'outputs --sensitive' to reveal sensitive values[/dim]")
    
    console.print()


def log_info(message: str) -> None:
    console.print(f"[blue][*][/blue] {message}")


def log_success(message: str) -> None:
    console.print(f"[green][+][/green] {message}")


def log_warning(message: str) -> None:
    console.print(f"[yellow][!][/yellow] {message}")


def log_error(message: str) -> None:
    console.print(f"[red][-][/red] {message}")