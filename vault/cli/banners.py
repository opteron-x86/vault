
import random
from typing import Optional
from importlib.metadata import version, PackageNotFoundError

from rich.console import Console
from rich.text import Text

console = Console()


def get_version() -> str:
    try:
        return version("vault")
    except PackageNotFoundError:
        return "dev"

BANNERS = [
    """
       _    ______  ____  ____   ______
      | |  / / __ |/ / / / / /  /_  __/
      | | / / /_/ / / / / / /    / /   
      | |/ / __  / / /_/ / /____/ /    
      |___/_/ /_/_/|____/______/_/  _____ ______
                                   |__  // ____/
                                    /_ </___ |  
                                  ___/ /___/ /  
                                 /____/_____/   
    """,
    """
    ██╗   ██╗ █████╗ ██╗   ██╗██╗  ████████╗    ██████╗ ███████╗
    ██║   ██║██╔══██╗██║   ██║██║  ╚══██╔══╝    ╚════██╗██╔════╝
    ██║   ██║███████║██║   ██║██║     ██║        █████╔╝███████╗
    ╚██╗ ██╔╝██╔══██║██║   ██║██║     ██║        ╚═══██╗╚════██║
     ╚████╔╝ ██║  ██║╚██████╔╝███████╗██║       ██████╔╝███████║
      ╚═══╝  ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝       ╚═════╝ ╚══════╝
    """,
    """
    ┬  ┬┌─┐┬ ┬┬ ┌┬┐   ┌─┐┌─┐
    └┐┌┘├─┤│ ││  │     ─┤└─┐
     └┘ ┴ ┴└─┘┴─┘┴    └─┘└─┘
    """,
    """
    ╦  ╦╔═╗╦ ╦╦  ╔╦╗  ╔═╗╔═╗
    ╚╗╔╝╠═╣║ ║║   ║    ═╣╚═╗
     ╚╝ ╩ ╩╚═╝╩═╝ ╩   ╚═╝╚═╝
    """,
]

TAGLINES = [
    "Virtual Attack Utility Lab Terminal",
    "Adversary Emulation Infrastructure",
    "Cloud Security Testing Platform",
    "Threat Simulation Environment",
    "Offensive Security Lab System",
]

TIPS = [
    "Use 'search' to find labs by keyword",
    "Run 'check' to verify cloud credentials",
    "Use 'active' to see deployed infrastructure",
    "Press TAB for command completion",
    "Run 'validate' before deploying labs",
    "Use 'list' to show all labs",
    "Run 'info' to view a lab's README",
    "Set CSP configs in config/ directory",
]

COLOR_SCHEMES = [
    ("cyan", "bright_cyan"),
    ("blue", "bright_blue"),
    ("magenta", "bright_magenta"),
    ("green", "bright_green"),
    ("red", "bright_red"),
]


def print_vault_banner(
    branch: Optional[str] = None,
    is_dirty: bool = False,
    total_labs: int = 0,
    deployed_labs: int = 0
) -> None:
    banner = random.choice(BANNERS)
    tagline = random.choice(TAGLINES)
    tip = random.choice(TIPS)
    primary, accent = random.choice(COLOR_SCHEMES)
    version_str = get_version()
    
    banner_text = Text(banner, style=f"{primary} bold")
    console.print(banner_text)
    console.print(f"       {tagline}", style=accent)
    console.print()
    
    console.print(f"       =[ CTE VAULT-35 v{version_str}", style="white")
    console.print(f"+ -- --=[ {total_labs} labs | {deployed_labs} deployed", style="white")
    
    if branch:
        branch_text = f"+ -- --=[ git: {branch}"
        if is_dirty:
            branch_text += " (modified)"
        console.print(branch_text, style="yellow" if is_dirty else "white")
    
    console.print()
    console.print("[dim]Organization:[/dim] DG35 - Cyber Threat Emulation")
    console.print("[dim]Contact:[/dim]      caleb.n.cline.ctr@mail.mil")
    console.print("[dim]Source Code:[/dim] https://web.git.mil/USG/DOD/DISA/cyber-executive/disa-cssp/disa-cols-na/cyber-threat-emulation/-/tree/master")
    console.print()
    console.print(f"[{accent}][*][/{accent}] [dim]{tip}[/dim]")
    console.print()