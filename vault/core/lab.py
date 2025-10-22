from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Optional

from pydantic import BaseModel, Field


class CloudProvider(str, Enum):
    AWS = "aws"
    AZURE = "azure"
    GCP = "gcp"
    UNKNOWN = "unknown"


class Difficulty(str, Enum):
    EASY = "easy"
    EASY_MEDIUM = "easy-medium"
    MEDIUM = "medium"
    MEDIUM_HARD = "medium-hard"
    HARD = "hard"
    UNKNOWN = "unknown"


class DeploymentStatus(str, Enum):
    NOT_DEPLOYED = "not_deployed"
    DEPLOYED = "deployed"
    PARTIAL = "partial"
    ERROR = "error"


class LabMetadata(BaseModel):
    lab_name: str
    csp: CloudProvider
    last_action: str
    timestamp: datetime
    deployed_by: str
    region: str
    resources_count: int = 0

    class Config:
        use_enum_values = True


@dataclass
class Lab:
    name: str
    path: Path
    provider: CloudProvider
    difficulty: Difficulty = Difficulty.UNKNOWN
    description: str = ""
    estimated_time: str = ""
    learning_objectives: list[str] = field(default_factory=list)
    
    @property
    def relative_path(self) -> str:
        return f"{self.provider.value}/{self.name}"
    
    @property
    def readme_path(self) -> Path:
        return self.path / "README.md"
    
    @property
    def has_readme(self) -> bool:
        return self.readme_path.exists()
    
    @property
    def terraform_dir(self) -> Path:
        return self.path
    
    def __str__(self) -> str:
        return f"{self.provider.value}/{self.name}"


@dataclass
class LabSearchResult:
    lab: Lab
    score: float
    matched_fields: list[str] = field(default_factory=list)


class TerraformOutput(BaseModel):
    value: str | dict | list
    sensitive: bool = False
    type: str = ""


class DeploymentResult(BaseModel):
    success: bool
    lab_name: str
    outputs: dict[str, TerraformOutput] = Field(default_factory=dict)
    error_message: Optional[str] = None
    resources_created: int = 0