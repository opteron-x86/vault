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


@dataclass
class Difficulty:
    rating: int
    
    @property
    def label(self) -> str:
        if self.rating <= 2:
            return "Easy"
        elif self.rating <= 4:
            return "Medium"
        elif self.rating <= 6:
            return "Hard"
        elif self.rating <= 8:
            return "Very Hard"
        else:
            return "NIGHTMARE"
    
    @property
    def color(self) -> str:
        if self.rating <= 2:
            return "green"
        elif self.rating <= 4:
            return "yellow"
        elif self.rating <= 6:
            return "orange3"
        elif self.rating <= 8:
            return "red"
        else:
            return "bright_red"
    
    def bar(self, width: int = 10) -> str:
        filled = min(self.rating, 10)
        empty = width - filled
        return "█" * filled + "░" * empty
    
    @classmethod
    def from_rating(cls, rating: int) -> "Difficulty":
        return cls(max(1, min(rating, 10)))
    
    @classmethod
    def unknown(cls) -> "Difficulty":
        return cls(0)
    
    def __str__(self) -> str:
        if self.rating == 0:
            return "Unknown"
        return f"{self.rating}/10 - {self.label}"


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
    difficulty: Difficulty = field(default_factory=Difficulty.unknown)
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
    type: str | list = ""


class DeploymentResult(BaseModel):
    success: bool
    lab_name: str
    outputs: dict[str, TerraformOutput] = Field(default_factory=dict)
    error_message: Optional[str] = None
    resources_created: int = 0