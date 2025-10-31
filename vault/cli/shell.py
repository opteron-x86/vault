from pathlib import Path

from prompt_toolkit import PromptSession
from prompt_toolkit.completion import Completer, Completion
from prompt_toolkit.history import FileHistory
from prompt_toolkit.lexers import PygmentsLexer
from prompt_toolkit.styles import Style
from pygments.lexers.shell import BashLexer
from rich.console import Console

from vault.cli.commands import CommandHandler
from vault.cli.formatting import log_error, log_warning, print_banner
from vault.utils.git import GitRepo

console = Console()


class VaultCompleter(Completer):
    def __init__(self, command_handler: CommandHandler):
        self.command_handler = command_handler
        self.commands = [
            "list", "use", "info", "init", "plan", "deploy", "destroy",
            "outputs", "status", "active", "back", "check", "install",
            "search", "validate", "git", "clear", "help",  "version", "exit", "quit"
        ]
    
    def get_completions(self, document, complete_event):
        text = document.text_before_cursor
        words = text.split()
        
        if not words or (len(words) == 1 and not text.endswith(" ")):
            word = words[0] if words else ""
            for cmd in self.commands:
                if cmd.startswith(word.lower()):
                    yield Completion(
                        cmd,
                        start_position=-len(word),
                        display=cmd,
                        display_meta="command"
                    )
        elif len(words) >= 1:
            cmd = words[0].lower()
            
            if cmd in ["use", "info", "init", "plan", "deploy", "destroy", "status", "outputs", "validate"]:
                labs = self.command_handler.discovery.discover_labs()
                
                if len(words) == 1 or (len(words) == 2 and not text.endswith(" ")):
                    partial = words[1] if len(words) == 2 else ""
                    
                    for lab in labs:
                        if lab.relative_path.startswith(partial):
                            yield Completion(
                                lab.relative_path,
                                start_position=-len(partial),
                                display=lab.relative_path,
                                display_meta=f"{lab.provider.value} - {lab.difficulty.label}"
                            )


class InteractiveShell:
    def __init__(
        self,
        labs_dir: Path,
        state_dir: Path,
        config_dir: Path,
        history_file: Path
    ):
        self.command_handler = CommandHandler(labs_dir, state_dir, config_dir)
        self.git = GitRepo(labs_dir.parent)
        
        self.style = Style.from_dict({
            'prompt': '#ff0066 bold',
            'lab': '#ffaa00',
            'git': '#00aaff',
        })
        
        self.session = PromptSession(
            history=FileHistory(str(history_file)),
            completer=VaultCompleter(self.command_handler),
            lexer=PygmentsLexer(BashLexer),
            style=self.style,
        )
    
    def get_prompt_text(self) -> str:
        parts = ["vault"]

        '''
        if self.git.is_repo():
            branch = self.git.get_current_branch()
            if branch:
                status = self.git.get_status()
                if status and status.is_dirty:
                    parts.append(f"[git:*{branch}]")
                else:
                    parts.append(f"[git:{branch}]")
        '''

        if self.command_handler.current_lab:
            lab_name = self.command_handler.current_lab.name
            parts.append(f"({lab_name})")
        
        return " ".join(parts) + " > "
    
    def run(self) -> None:
        status = self.git.get_status()
        branch = status.branch if status else None
        is_dirty = status.is_dirty if status else False
        print_banner(branch, is_dirty)
        
        while True:
            try:
                user_input = self.session.prompt(
                    self.get_prompt_text(),
                    style=self.style
                ).strip()
                
                if not user_input:
                    continue
                
                self.process_command(user_input)
                
            except KeyboardInterrupt:
                console.print("\n[dim]Use 'exit' to quit[/dim]")
                continue
            except EOFError:
                break
    
    def process_command(self, user_input: str) -> None:
        parts = user_input.split()
        cmd = parts[0].lower()
        args = parts[1:]
        
        handlers = {
            "list": lambda: self.command_handler.cmd_list(args[0] if args else None),
            "ls": lambda: self.command_handler.cmd_list(args[0] if args else None),
            "use": lambda: self.command_handler.cmd_use(args[0]) if args else log_error("Usage: use <lab>"),
            "select": lambda: self.command_handler.cmd_use(args[0]) if args else log_error("Usage: select <lab>"),
            "info": lambda: self.command_handler.cmd_info(args[0] if args else None),
            "show": lambda: self.command_handler.cmd_info(args[0] if args else None),
            "init": lambda: self.command_handler.cmd_init(args[0] if args else None),
            "plan": lambda: self.command_handler.cmd_plan(args[0] if args else None, destroy="--destroy" in args),
            "deploy": lambda: self.command_handler.cmd_deploy(args[0] if args else None),
            "run": lambda: self.command_handler.cmd_deploy(args[0] if args else None),
            "destroy": lambda: self.command_handler.cmd_destroy(args[0] if args else None),
            "kill": lambda: self.command_handler.cmd_destroy(args[0] if args else None),
            "outputs": lambda: self._handle_outputs(args),
            "output": lambda: self._handle_outputs(args),
            "status": lambda: self.command_handler.cmd_status(args[0] if args else None),
            "stat": lambda: self.command_handler.cmd_status(args[0] if args else None),
            "active": lambda: self.command_handler.cmd_active(),
            "sessions": lambda: self.command_handler.cmd_active(),
            "back": lambda: self.command_handler.cmd_back(),
            "deselect": lambda: self.command_handler.cmd_back(),
            "check": lambda: self.command_handler.cmd_check(),
            "install": lambda: self.command_handler.cmd_install(args[0]) if args else log_error("Usage: install <tool>"),
            "git": lambda: self.command_handler.cmd_git(),
            "search": lambda: self.command_handler.cmd_search(" ".join(args)) if args else log_error("Usage: search <query>"),
            "validate": lambda: self.command_handler.cmd_validate(args[0] if args else None),
            "version": lambda: self._show_version(),
            "ver": lambda: self._show_version(), 
            "clear": lambda: self._clear_screen(),
            "cls": lambda: self._clear_screen(),
            "help": lambda: self._show_help(),
            "?": lambda: self._show_help(),
            "h": lambda: self._show_help(),
            "exit": lambda: self._exit(),
            "quit": lambda: self._exit(),
            "q": lambda: self._exit(),
        }
        
        handler = handlers.get(cmd)
        
        if handler:
            handler()
        else:
            log_error(f"Unknown command: {cmd}")
            log_warning("Type 'help' for available commands")
    
    def _handle_outputs(self, args: list[str]) -> None:
        show_sensitive = "--sensitive" in args
        lab_id = next((arg for arg in args if not arg.startswith("--")), None)
        self.command_handler.cmd_outputs(lab_id, show_sensitive)
    
    def _show_help(self) -> None:
        help_text = """
[bold cyan]Core Commands[/bold cyan]
  list [query]         List all available labs (optional search)
  use <lab>            Select a lab to work with (path or number)
  info [lab]           Show detailed lab information
  init [lab]           Initialize lab (download providers, configure backend)
  plan [lab]           Show terraform plan without deploying
  deploy [lab]         Deploy the selected or specified lab
  destroy [lab]        Destroy the selected or specified lab
  status [lab]         Show deployment status
  outputs [lab]        Show lab outputs (use --sensitive for sensitive values)
  active               List all active deployments
  version              Display VAULT version

[bold cyan]Prerequisites[/bold cyan]
  check                Check which CSP CLI tools are installed
  install <tool>       Show installation instructions (aws, az, gcloud, terraform)

[bold cyan]Lab Discovery[/bold cyan]
  search <query>       Search labs by name, description, or objectives
  validate [lab]       Validate lab terraform configuration

[bold cyan]Repository[/bold cyan]
  git                  Show git repository status and branch info

[bold cyan]Navigation[/bold cyan]
  back                 Deselect current lab
  clear                Clear the screen
  help                 Show this help message
  exit/quit            Exit VAULT

[bold cyan]Examples[/bold cyan]
  install aws              Install AWS CLI
  use aws/iam-privesc      Select lab by path
  use 1                    Select lab by number
  plan --destroy           Show destroy plan
  search ssrf              Search for labs containing "ssrf"
  outputs --sensitive      Show outputs including sensitive values
"""
        console.print(help_text)

    def _show_version(self) -> None:
        from vault.utils.version import get_version
        console.print(f"[cyan]VAULT version {get_version()}[/cyan]")  

    def _clear_screen(self) -> None:
        console.clear()
        status = self.git.get_status()
        branch = status.branch if status else None
        is_dirty = status.is_dirty if status else False
        print_banner(branch, is_dirty)
    
    def _exit(self) -> None:
        console.print("\n[cyan]Exiting VAULT...[/cyan]\n")
        raise EOFError