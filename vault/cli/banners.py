
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
       _    ______  __  ____  ______
      | |  / / __ |/ / / / / /_  __/
      | | / / /_/ / / / / /   / /   
      | |/ / __  / /_/ / /___/ /    
      |___/_/ /_/|____/_____/_/   ____  ______
                                 |__  \/ ____/
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
    """
     ██▒   █▓ ▄▄▄       █    ██  ██▓  ▄▄▄█████▓
    ▓██░   █▒▒████▄     ██  ▓██▒▓██▒  ▓  ██▒ ▓▒
     ▓██  █▒░▒██  ▀█▄  ▓██  ▒██░▒██░  ▒ ▓██░ ▒░
     ▒██ █░░░██▄▄▄▄██ ▓▓█  ░██░▒██░  ░ ▓██▓ ░ 
      ▒▀█░   ▓█   ▓██▒▒▒█████▓ ░██████▒▒██▒ ░ 
      ░ ▐░   ▒▒   ▓▒█░░▒▓▒ ▒ ▒ ░ ▒░▓  ░▒ ░░   
      ░ ░░    ▒   ▒▒ ░░░▒░ ░ ░ ░ ░ ▒  ░  ░    
       ░░    ░   ▒    ░░░ ░ ░   ░ ░   ░      
        ░        ░  ░   ░         ░  ░       
        ░                                                                         
    """,
    """
 █████   █████   █████████   █████  █████ █████       ███████████     ████████  ██████████
░░███   ░░███   ███░░░░░███ ░░███  ░░███ ░░███       ░█░░░███░░░█    ███░░░░███░███░░░░░░█
 ░███    ░███  ░███    ░███  ░███   ░███  ░███       ░   ░███  ░    ░░░    ░███░███     ░ 
 ░███    ░███  ░███████████  ░███   ░███  ░███           ░███          ██████░ ░█████████ 
 ░░███   ███   ░███░░░░░███  ░███   ░███  ░███           ░███         ░░░░░░███░░░░░░░░███
  ░░░█████░    ░███    ░███  ░███   ░███  ░███      █    ░███        ███   ░███ ███   ░███
    ░░███      █████   █████ ░░████████   ███████████    █████    ██░░████████ ░░████████ 
     ░░░      ░░░░░   ░░░░░   ░░░░░░░░   ░░░░░░░░░░░    ░░░░░    ░░  ░░░░░░░░   ░░░░░░░░  
                                                                                                                                                                             
    """,
    """
:::     :::     :::     :::    ::: :::    :::::::::::       ::::::::  :::::::::: 
:+:     :+:   :+: :+:   :+:    :+: :+:        :+:          :+:    :+: :+:    :+: 
+:+     +:+  +:+   +:+  +:+    +:+ +:+        +:+                 +:+ +:+        
+#+     +:+ +#++:++#++: +#+    +:+ +#+        +#+              +#++:  +#++:++#+  
 +#+   +#+  +#+     +#+ +#+    +#+ +#+        +#+                 +#+        +#+ 
  #+#+#+#   #+#     #+# #+#    #+# #+#        #+#          #+#    #+# #+#    #+# 
    ###     ###     ###  ########  ########## ###           ########   ########  
    """,
    """
'##::::'##::::'###::::'##::::'##:'##:::::::'########:::::'#######::'########:
 ##:::: ##:::'## ##::: ##:::: ##: ##:::::::... ##..:::::'##.... ##: ##.....::
 ##:::: ##::'##:. ##:: ##:::: ##: ##:::::::::: ##:::::::..::::: ##: ##:::::::
 ##:::: ##:'##:::. ##: ##:::: ##: ##:::::::::: ##::::::::'#######:: #######::
. ##:: ##:: #########: ##:::: ##: ##:::::::::: ##::::::::...... ##:...... ##:
:. ## ##::: ##.... ##: ##:::: ##: ##:::::::::: ##:::::::'##:::: ##:'##::: ##:
::. ###:::: ##:::: ##:. #######:: ########:::: ##:::::::. #######::. ######::
:::...:::::..:::::..:::.......:::........:::::..:::::::::.......::::......:::
    """,
    """
                                                                      
@@@  @@@   @@@@@@   @@@  @@@  @@@       @@@@@@@     @@@@@@   @@@@@@@  
@@@  @@@  @@@@@@@@  @@@  @@@  @@@       @@@@@@@     @@@@@@@  @@@@@@@  
@@!  @@@  @@!  @@@  @@!  @@@  @@!         @@!           @@@  !@@      
!@!  @!@  !@!  @!@  !@!  @!@  !@!         !@!           @!@  !@!      
@!@  !@!  @!@!@!@!  @!@  !@!  @!!         @!!       @!@!!@   !!@@!!   
!@!  !!!  !!!@!!!!  !@!  !!!  !!!         !!!       !!@!@!   @!!@!!!  
:!:  !!:  !!:  !!!  !!:  !!!  !!:         !!:           !!:      !:!  
 ::!!:!   :!:  !:!  :!:  !:!   :!:        :!:           :!:      !:!  
  ::::    ::   :::  ::::: ::   :: ::::     ::       :: ::::  :::: ::  
   :       :   : :   : :  :   : :: : :     :         : : :   :: : :   
                                                                      
    """,
    """
    @@@  @@@  @@@@@@  @@@  @@@ @@@      @@@@@@@      @@@@@@  @@@@@@@
    @@!  @@@ @@!  @@@ @@!  @@@ @@!        @@!            @@! !@@    
    @!@  !@! @!@!@!@! @!@  !@! @!!        @!!         @!!!:  !!@@!! 
     !: .:!  !!:  !!! !!:  !!! !!:        !!:            !!:     !:!
       ::     :   : :  :.:: :  : ::.: :    :         ::: ::  :: : : 
                                                                 
    """,
    """

"""
]

TAGLINES = [
    "Your next SQL injection will return unexpected results... in bed.",
    "A forgotten password holds the key to your future. It's probably 'password123'.",
    "You will soon find a zero-day vulnerability in your relationship status.",
    "The firewall you build around your heart can also be bypassed with the right exploit.",
    "Your lucky port: 8080",
    "A brute force approach will not solve your current problem. Try social engineering.",
    "Remember: the best hackers never leave /var/log traces.",
    "You will soon receive a connection request from someone who matters. Accept it.",
    "Your root access to happiness requires better authentication.",
    "The only thing you can't hack is time. But you can optimize it.",
    "404: Fortune Not Found. Please clear your cache and try again.",
    "Your next commit will be the one that finally fixes production.",
    "In the coming week, someone will ask you to do it in Rust.",
    "The vulnerability you seek is between keyboard and chair.",
    "Your penetration test of life will reveal unexpected open ports.",
    "sudo make me a sandwich of success.",
    "Wisdom is knowing that 'works on my machine' is never enough.",
    "Your next merge conflict will teach you more than any tutorial ever could.",
    "The bug you've been hunting is a feature in someone else's code.",
    "You will soon discover that the real treasure was the stack traces we made along the way.",
    "Fortune cookie says: git push --force at your own risk.",
    "A wise hacker knows: there is no cloud, only someone else's computer.",
    "Your next rubber duck debugging session will achieve enlightenment.",
    "The answer you seek is in the documentation you refused to read.",
    "You will soon experience a buffer overflow of good fortune.",
    "ctrl+Z cannot undo what you are about to deploy to production.",
    "Your lucky hex: 0xDEADBEEF",
    "The encryption of your feelings is stronger than AES-256.",
    "You will soon pivot to a new attack vector in your career.",
    "Beware: your next dependency update will break everything. Again.",
    "The kernel panic in your life requires a hard reboot, not a patch.",
    "Success arrives on port 443, but happiness listens on localhost.",
    "Your threat model does not account for your cat walking across the keyboard.",
    "The payload you deliver today will execute perfectly tomorrow.",
    "Your next phishing attempt will catch feelings instead of credentials.",
    "The packet you lost will find its way back to you... eventually.",
    "rm -rf is not the solution to your problems. Usually.",
    "You will soon achieve privilege escalation in your personal life.",
    "The honeypot you set up will attract more bears than hackers.",
    "Your lucky algorithm: bubble sort (said no one ever).",
    "A watched build never compiles. A forgotten build always fails.",
    "You will soon find what you're looking for in the last place you grep.",
    "The race condition in your heart can only be fixed with a mutex of communication.",
    "Your next container will not be stateless, no matter what you promise.",
    "Beware of programmers carrying screwdrivers. They have achieved hardware access.",
    "The MITM attack on your lunch plans will succeed.",
    "Your session will expire in 30 days, but your technical debt is forever.",
    "A distributed system of friends is more fault-tolerant than a single point of contact.",
    "The XSS vulnerability in your jokes allows others to inject their own punchlines.",
    "Your next API call will return 418: I'm a teapot.",
    "The backdoor to happiness was open source all along.",
]

TIPS = [
    "Use 'search' to find labs by keyword",
    "Run 'check' to verify cloud credentials",
    "Use 'active' to see deployed infrastructure",
    "Press TAB for command completion",
    "Run 'validate' before deploying labs",
    "Use 'list' to show all labs",
    "Run 'info' to view a lab's README",
    "Run 'setup' to automatically create CSP configs",
    "Run 'install' to automatically install CSP CLI tools",
    "New labs need to be initialized using 'init'",
    "Use 'status' to check a lab's deployment status",
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