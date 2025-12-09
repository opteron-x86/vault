import json
import subprocess
from pathlib import Path
from typing import Optional

from vault.core.lab import DeploymentResult, Lab, TerraformOutput


class TerraformError(Exception):
    pass


class TerraformWrapper:
    def __init__(self, state_dir: Path):
        self.state_dir = state_dir
        self._check_terraform_installed()
    
    def _check_terraform_installed(self) -> None:
        try:
            result = subprocess.run(
                ["terraform", "version"],
                capture_output=True,
                text=True,
                check=True
            )
            if result.returncode != 0:
                raise TerraformError("Terraform is not properly installed")
        except FileNotFoundError:
            raise TerraformError(
                "Terraform not found. Please install Terraform: "
                "https://www.terraform.io/downloads"
            )
    
    def _get_state_path(self, lab: Lab) -> Path:
        state_key = lab.relative_path.replace("/", "_")
        state_path = self.state_dir / state_key
        state_path.mkdir(parents=True, exist_ok=True)
        return state_path
    
    def _run_terraform(
        self,
        args: list[str],
        cwd: Path,
        capture_output: bool = False
    ) -> subprocess.CompletedProcess:
        cmd = ["terraform"] + args
        
        try:
            if capture_output:
                result = subprocess.run(
                    cmd,
                    cwd=cwd,
                    capture_output=True,
                    text=True,
                    check=True
                )
            else:
                result = subprocess.run(
                    cmd,
                    cwd=cwd,
                    check=True
                )
            return result
        except subprocess.CalledProcessError as e:
            error_msg = e.stderr if hasattr(e, 'stderr') else str(e)
            raise TerraformError(f"Terraform command failed: {error_msg}")
    
    def init(self, lab: Lab, var_files: list[Path]) -> None:
        state_path = self._get_state_path(lab)
        tfstate_path = (state_path / "terraform.tfstate").resolve()
        
        # Remove cached terraform state to force reconfiguration
        terraform_dir = lab.terraform_dir / ".terraform"
        if terraform_dir.exists():
            import shutil
            shutil.rmtree(terraform_dir)
        
        args = [
            "init",
            f"-backend-config=path={tfstate_path}",
            "-reconfigure"
        ]
        
        self._run_terraform(args, lab.terraform_dir, capture_output=True)
    
    def plan(
        self,
        lab: Lab,
        var_files: list[Path],
        destroy: bool = False
    ) -> str:
        self.init(lab, var_files)
        
        args = ["plan", "-no-color", "-compact-warnings"]
        
        if destroy:
            args.append("-destroy")
        
        for var_file in var_files:
            args.extend(["-var-file", str(var_file)])
        
        result = self._run_terraform(
            args,
            lab.terraform_dir,
            capture_output=True
        )
        return result.stdout
    
    def apply(
        self,
        lab: Lab,
        var_files: list[Path],
        auto_approve: bool = False
    ) -> DeploymentResult:
        self.init(lab, var_files)
        
        args = ["apply", "-no-color", "-compact-warnings"]
        
        for var_file in var_files:
            args.extend(["-var-file", str(var_file)])
        
        if auto_approve:
            args.append("-auto-approve")
        
        try:
            self._run_terraform(args, lab.terraform_dir)
            
            outputs = self.get_outputs(lab)
            resource_count = self._get_resource_count(lab)
            
            return DeploymentResult(
                success=True,
                lab_name=lab.relative_path,
                outputs=outputs,
                resources_created=resource_count
            )
        except TerraformError as e:
            return DeploymentResult(
                success=False,
                lab_name=lab.relative_path,
                error_message=str(e)
            )
    
    def destroy(
        self,
        lab: Lab,
        var_files: list[Path],
        auto_approve: bool = False
    ) -> bool:
        self.init(lab, var_files)
        
        args = ["destroy", "-no-color", "-compact-warnings"]
        
        for var_file in var_files:
            args.extend(["-var-file", str(var_file)])
        
        if auto_approve:
            args.append("-auto-approve")
        
        try:
            self._run_terraform(args, lab.terraform_dir)
            return True
        except TerraformError:
            return False
    
    def get_outputs(self, lab: Lab) -> dict[str, TerraformOutput]:
        outputs = self._get_outputs_from_state(lab)
        if outputs:
            return outputs
        
        terraform_dir = lab.terraform_dir / ".terraform"
        if not terraform_dir.exists():
            try:
                state_path = self._get_state_path(lab)
                tfstate_path = (state_path / "terraform.tfstate").resolve()
                
                args = [
                    "init",
                    f"-backend-config=path={tfstate_path}",
                    "-reconfigure"
                ]
                
                self._run_terraform(args, lab.terraform_dir, capture_output=True)
            except Exception:
                return {}
        
        try:
            result = self._run_terraform(
                ["output", "-json"],
                lab.terraform_dir,
                capture_output=True
            )
            
            raw_outputs = json.loads(result.stdout)
            outputs = {}
            
            for key, data in raw_outputs.items():
                outputs[key] = TerraformOutput(
                    value=data.get("value"),
                    sensitive=data.get("sensitive", False),
                    type=data.get("type", "")
                )
            
            return outputs
        except Exception:
            return {}
    
    def state_list(self, lab: Lab) -> list[str]:
        try:
            result = self._run_terraform(
                ["state", "list"],
                lab.terraform_dir,
                capture_output=True
            )
            return [
                line.strip()
                for line in result.stdout.splitlines()
                if line.strip()
            ]
        except Exception:
            return []

    def _get_outputs_from_state(self, lab: Lab) -> dict[str, TerraformOutput]:
        try:
            state_path = self._get_state_path(lab)
            tfstate = state_path / "terraform.tfstate"
            
            if not tfstate.exists():
                return {}
            
            with open(tfstate) as f:
                state = json.load(f)
                raw_outputs = state.get("outputs", {})
                outputs = {}
                
                for key, data in raw_outputs.items():
                    try:
                        outputs[key] = TerraformOutput(
                            value=data.get("value"),
                            sensitive=data.get("sensitive", False),
                            type=data.get("type", "")
                        )
                    except Exception:
                        pass
                
                return outputs
        except Exception:
            return {}
        
    def _get_resource_count(self, lab: Lab) -> int:
        state_path = self._get_state_path(lab)
        tfstate = state_path / "terraform.tfstate"
        
        if not tfstate.exists():
            return 0
        
        try:
            with open(tfstate) as f:
                state = json.load(f)
                return len(state.get("resources", []))
        except Exception:
            return 0
    
    def validate(self, lab: Lab) -> tuple[bool, str]:
        try:
            result = self._run_terraform(
                ["validate", "-no-color"],
                lab.terraform_dir,
                capture_output=True
            )
            return True, result.stdout
        except TerraformError as e:
            return False, str(e)