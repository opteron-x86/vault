import json
from datetime import datetime
from pathlib import Path
from typing import Optional

from vault.core.lab import CloudProvider, DeploymentStatus, Lab, LabMetadata


class StateManager:
    def __init__(self, state_dir: Path):
        self.state_dir = state_dir
        self.metadata_dir = state_dir / ".metadata"
        self.metadata_dir.mkdir(parents=True, exist_ok=True)
    
    def get_state_path(self, lab: Lab) -> Path:
        state_key = lab.relative_path.replace("/", "_")
        return self.state_dir / state_key
    
    def get_metadata_path(self, lab: Lab) -> Path:
        state_key = lab.relative_path.replace("/", "_")
        return self.metadata_dir / f"{state_key}.json"
    
    def get_tfstate_path(self, lab: Lab) -> Path:
        return self.get_state_path(lab) / "terraform.tfstate"
    
    def is_deployed(self, lab: Lab) -> bool:
        tfstate = self.get_tfstate_path(lab)
        if not tfstate.exists():
            return False
        
        try:
            with open(tfstate) as f:
                state = json.load(f)
                return len(state.get("resources", [])) > 0
        except (json.JSONDecodeError, KeyError):
            return False
    
    def get_deployment_status(self, lab: Lab) -> DeploymentStatus:
        if not self.is_deployed(lab):
            return DeploymentStatus.NOT_DEPLOYED
        
        tfstate = self.get_tfstate_path(lab)
        try:
            with open(tfstate) as f:
                state = json.load(f)
                resources = state.get("resources", [])
                
                if len(resources) == 0:
                    return DeploymentStatus.NOT_DEPLOYED
                
                has_errors = any(
                    r.get("status") == "error" for r in resources
                )
                if has_errors:
                    return DeploymentStatus.ERROR
                
                return DeploymentStatus.DEPLOYED
        except Exception:
            return DeploymentStatus.ERROR
    
    def get_resource_count(self, lab: Lab) -> int:
        tfstate = self.get_tfstate_path(lab)
        if not tfstate.exists():
            return 0
        
        try:
            with open(tfstate) as f:
                state = json.load(f)
                return len(state.get("resources", []))
        except Exception:
            return 0
    
    def save_metadata(
        self,
        lab: Lab,
        action: str,
        deployed_by: str,
        region: str
    ) -> None:
        metadata = LabMetadata(
            lab_name=lab.relative_path,
            csp=lab.provider,
            last_action=action,
            timestamp=datetime.utcnow(),
            deployed_by=deployed_by,
            region=region,
            resources_count=self.get_resource_count(lab)
        )
        
        metadata_path = self.get_metadata_path(lab)
        with open(metadata_path, "w") as f:
            f.write(metadata.model_dump_json(indent=2))
    
    def load_metadata(self, lab: Lab) -> Optional[LabMetadata]:
        metadata_path = self.get_metadata_path(lab)
        if not metadata_path.exists():
            return None
        
        try:
            with open(metadata_path) as f:
                data = json.load(f)
                return LabMetadata(**data)
        except Exception:
            return None
    
    def get_active_deployments(self) -> list[tuple[str, LabMetadata]]:
        active = []
        
        for metadata_file in self.metadata_dir.glob("*.json"):
            try:
                with open(metadata_file) as f:
                    data = json.load(f)
                    metadata = LabMetadata(**data)
                    
                    state_key = metadata_file.stem
                    lab_path = state_key.replace("_", "/")
                    
                    tfstate = self.state_dir / state_key / "terraform.tfstate"
                    if tfstate.exists():
                        with open(tfstate) as tf:
                            state = json.load(tf)
                            if len(state.get("resources", [])) > 0:
                                active.append((lab_path, metadata))
            except Exception:
                continue
        
        return sorted(active, key=lambda x: x[1].timestamp, reverse=True)
    
    def cleanup_empty_states(self) -> int:
        cleaned = 0
        for state_dir in self.state_dir.iterdir():
            if state_dir.name == ".metadata":
                continue
            
            if not state_dir.is_dir():
                continue
            
            tfstate = state_dir / "terraform.tfstate"
            if tfstate.exists():
                try:
                    with open(tfstate) as f:
                        state = json.load(f)
                        if len(state.get("resources", [])) == 0:
                            tfstate.unlink()
                            if not any(state_dir.iterdir()):
                                state_dir.rmdir()
                            cleaned += 1
                except Exception:
                    pass
        
        return cleaned