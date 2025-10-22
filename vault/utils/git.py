import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


@dataclass
class GitStatus:
    branch: str
    is_dirty: bool
    ahead: int
    behind: int
    untracked: int
    modified: int
    staged: int


class GitRepo:
    def __init__(self, repo_path: Path):
        self.repo_path = repo_path
        self._is_repo = self._check_is_repo()
    
    def _check_is_repo(self) -> bool:
        try:
            result = subprocess.run(
                ["git", "rev-parse", "--git-dir"],
                cwd=self.repo_path,
                capture_output=True,
                check=False
            )
            return result.returncode == 0
        except FileNotFoundError:
            return False
    
    def is_repo(self) -> bool:
        return self._is_repo
    
    def get_current_branch(self) -> Optional[str]:
        if not self._is_repo:
            return None
        
        try:
            result = subprocess.run(
                ["git", "rev-parse", "--abbrev-ref", "HEAD"],
                cwd=self.repo_path,
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout.strip()
        except (subprocess.CalledProcessError, FileNotFoundError):
            return None
    
    def get_status(self) -> Optional[GitStatus]:
        if not self._is_repo:
            return None
        
        branch = self.get_current_branch()
        if not branch:
            return None
        
        try:
            status_result = subprocess.run(
                ["git", "status", "--porcelain", "--branch"],
                cwd=self.repo_path,
                capture_output=True,
                text=True,
                check=True
            )
            
            lines = status_result.stdout.splitlines()
            
            ahead = 0
            behind = 0
            if lines and lines[0].startswith("##"):
                branch_line = lines[0]
                if "[ahead" in branch_line:
                    ahead = int(branch_line.split("ahead ")[1].split("]")[0].split(",")[0])
                if "[behind" in branch_line:
                    behind = int(branch_line.split("behind ")[1].split("]")[0].split(",")[0])
            
            untracked = sum(1 for line in lines[1:] if line.startswith("??"))
            modified = sum(1 for line in lines[1:] if line.startswith(" M"))
            staged = sum(1 for line in lines[1:] if line.startswith("M ") or line.startswith("A "))
            
            is_dirty = untracked > 0 or modified > 0 or staged > 0
            
            return GitStatus(
                branch=branch,
                is_dirty=is_dirty,
                ahead=ahead,
                behind=behind,
                untracked=untracked,
                modified=modified,
                staged=staged
            )
        except (subprocess.CalledProcessError, FileNotFoundError):
            return None
    
    def get_remote_url(self) -> Optional[str]:
        if not self._is_repo:
            return None
        
        try:
            result = subprocess.run(
                ["git", "config", "--get", "remote.origin.url"],
                cwd=self.repo_path,
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout.strip()
        except (subprocess.CalledProcessError, FileNotFoundError):
            return None
    
    def get_last_commit(self) -> Optional[str]:
        if not self._is_repo:
            return None
        
        try:
            result = subprocess.run(
                ["git", "log", "-1", "--pretty=format:%h - %s (%cr)"],
                cwd=self.repo_path,
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout.strip()
        except (subprocess.CalledProcessError, FileNotFoundError):
            return None