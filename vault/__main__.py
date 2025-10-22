import sys
from pathlib import Path

import click

from vault.cli.commands import CommandHandler
from vault.cli.formatting import console, log_error
from vault.cli.shell import InteractiveShell


def get_project_paths() -> tuple[Path, Path, Path, Path]:
    project_root = Path.cwd()
    
    labs_dir = project_root / "labs"
    state_dir = project_root / ".state"
    config_dir = project_root / "config"
    history_file = state_dir / ".vault_history"
    
    state_dir.mkdir(exist_ok=True)
    config_dir.mkdir(exist_ok=True)
    
    return labs_dir, state_dir, config_dir, history_file


@click.group(invoke_without_command=True)
@click.pass_context
def cli(ctx):
    """Vulnerability Analysis Universal Lab Terminal"""
    if ctx.invoked_subcommand is None:
        labs_dir, state_dir, config_dir, history_file = get_project_paths()
        
        if not labs_dir.exists():
            log_error(f"Labs directory not found: {labs_dir}")
            log_error("Please run vault from the project root directory")
            sys.exit(1)
        
        try:
            shell = InteractiveShell(labs_dir, state_dir, config_dir, history_file)
            shell.run()
        except Exception as e:
            log_error(f"Fatal error: {e}")
            sys.exit(1)


@cli.command()
@click.argument("query", required=False)
def list(query):
    """List available labs"""
    labs_dir, state_dir, config_dir, _ = get_project_paths()
    handler = CommandHandler(labs_dir, state_dir, config_dir)
    handler.cmd_list(query)


@cli.command()
@click.argument("lab")
def init(lab):
    """Initialize a lab (download providers, configure backend)"""
    labs_dir, state_dir, config_dir, _ = get_project_paths()
    handler = CommandHandler(labs_dir, state_dir, config_dir)
    
    if not handler.cmd_use(lab):
        sys.exit(1)
    
    if not handler.cmd_init():
        sys.exit(1)


@cli.command()
@click.argument("lab")
@click.option("--destroy", is_flag=True, help="Show destroy plan")
def plan(lab, destroy):
    """Show terraform plan without deploying"""
    labs_dir, state_dir, config_dir, _ = get_project_paths()
    handler = CommandHandler(labs_dir, state_dir, config_dir)
    
    if not handler.cmd_use(lab):
        sys.exit(1)
    
    handler.cmd_plan(destroy=destroy)


@cli.command()
@click.argument("lab")
def deploy(lab):
    """Deploy a lab"""
    labs_dir, state_dir, config_dir, _ = get_project_paths()
    handler = CommandHandler(labs_dir, state_dir, config_dir)
    
    if not handler.cmd_use(lab):
        sys.exit(1)
    
    if not handler.cmd_deploy():
        sys.exit(1)


@cli.command()
@click.argument("lab")
def destroy(lab):
    """Destroy a lab"""
    labs_dir, state_dir, config_dir, _ = get_project_paths()
    handler = CommandHandler(labs_dir, state_dir, config_dir)
    
    if not handler.cmd_use(lab):
        sys.exit(1)
    
    if not handler.cmd_destroy():
        sys.exit(1)


@cli.command()
@click.argument("lab", required=False)
@click.option("--sensitive", is_flag=True, help="Show sensitive outputs")
def outputs(lab, sensitive):
    """Show lab outputs"""
    labs_dir, state_dir, config_dir, _ = get_project_paths()
    handler = CommandHandler(labs_dir, state_dir, config_dir)
    
    if lab and not handler.cmd_use(lab):
        sys.exit(1)
    
    handler.cmd_outputs(show_sensitive=sensitive)


@cli.command()
@click.argument("lab", required=False)
def status(lab):
    """Show lab status"""
    labs_dir, state_dir, config_dir, _ = get_project_paths()
    handler = CommandHandler(labs_dir, state_dir, config_dir)
    
    if lab:
        if not handler.cmd_use(lab):
            sys.exit(1)
    
    handler.cmd_status()


@cli.command()
def active():
    """List active deployments"""
    labs_dir, state_dir, config_dir, _ = get_project_paths()
    handler = CommandHandler(labs_dir, state_dir, config_dir)
    handler.cmd_active()


@cli.command()
def search(query):
    """Search for labs"""
    labs_dir, state_dir, config_dir, _ = get_project_paths()
    handler = CommandHandler(labs_dir, state_dir, config_dir)
    handler.cmd_search(query)


@cli.command()
def check():
    """Check which CSP CLI tools are installed"""
    labs_dir, state_dir, config_dir, _ = get_project_paths()
    handler = CommandHandler(labs_dir, state_dir, config_dir)
    handler.cmd_check()


@cli.command()
@click.argument("tool", type=click.Choice(["aws", "az", "gcloud", "terraform"]))
def install(tool):
    """Show installation instructions for CSP tools"""
    labs_dir, state_dir, config_dir, _ = get_project_paths()
    handler = CommandHandler(labs_dir, state_dir, config_dir)
    
    if not handler.cmd_install(tool):
        sys.exit(1)


@cli.command()
def git():
    """Show git repository status"""
    labs_dir, state_dir, config_dir, _ = get_project_paths()
    handler = CommandHandler(labs_dir, state_dir, config_dir)
    handler.cmd_git()


def main():
    try:
        cli()
    except KeyboardInterrupt:
        console.print("\n[dim]Interrupted[/dim]")
        sys.exit(130)
    except Exception as e:
        log_error(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()