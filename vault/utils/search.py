import re
from pathlib import Path
from typing import Optional

from fuzzywuzzy import fuzz

from vault.core.lab import CloudProvider, Difficulty, Lab, LabSearchResult


class LabDiscovery:
    def __init__(self, labs_dir: Path):
        self.labs_dir = labs_dir
        self._lab_cache: Optional[list[Lab]] = None
    
    def discover_labs(self, force_refresh: bool = False) -> list[Lab]:
        if self._lab_cache is not None and not force_refresh:
            return self._lab_cache
        
        labs = []
        
        for provider_dir in self.labs_dir.iterdir():
            if not provider_dir.is_dir():
                continue
            
            try:
                provider = CloudProvider(provider_dir.name)
            except ValueError:
                continue
            
            for lab_dir in provider_dir.iterdir():
                if not lab_dir.is_dir():
                    continue
                
                if not (lab_dir / "main.tf").exists():
                    continue
                
                lab = self._create_lab(lab_dir, provider)
                labs.append(lab)
        
        self._lab_cache = sorted(labs, key=lambda x: (x.provider.value, x.name))
        return self._lab_cache
    
    def _create_lab(self, lab_path: Path, provider: CloudProvider) -> Lab:
        lab = Lab(
            name=lab_path.name,
            path=lab_path,
            provider=provider
        )
        
        if lab.has_readme:
            self._parse_readme(lab)
        
        return lab
    
    def _parse_readme(self, lab: Lab) -> None:
        try:
            content = lab.readme_path.read_text()
            
            difficulty_match = re.search(
                r'Difficulty:\s*\*\*(.+?)\*\*',
                content,
                re.IGNORECASE
            )
            if difficulty_match:
                diff_str = difficulty_match.group(1).strip().lower().replace(" ", "-")
                try:
                    lab.difficulty = Difficulty(diff_str)
                except ValueError:
                    lab.difficulty = Difficulty.UNKNOWN
            
            desc_match = re.search(
                r'(?:Description|Overview):\s*(.+?)(?:\n\n|\n#)',
                content,
                re.IGNORECASE | re.DOTALL
            )
            if desc_match:
                lab.description = desc_match.group(1).strip()
            
            time_match = re.search(
                r'(?:Estimated Time|Duration):\s*(.+)',
                content,
                re.IGNORECASE
            )
            if time_match:
                lab.estimated_time = time_match.group(1).strip()
            
            objectives_section = re.search(
                r'(?:Learning Objectives|Objectives):\s*(.+?)(?:\n\n|\n#)',
                content,
                re.IGNORECASE | re.DOTALL
            )
            if objectives_section:
                objectives_text = objectives_section.group(1).strip()
                lab.learning_objectives = [
                    obj.strip().lstrip('-•*').strip()
                    for obj in objectives_text.split('\n')
                    if obj.strip() and not obj.strip().startswith('#')
                ]
        except Exception:
            pass
    
    def get_lab_by_path(self, lab_path: str) -> Optional[Lab]:
        labs = self.discover_labs()
        
        for lab in labs:
            if lab.relative_path == lab_path or lab.name == lab_path:
                return lab
        
        return None
    
    def get_lab_by_index(self, index: int) -> Optional[Lab]:
        labs = self.discover_labs()
        
        if 0 <= index < len(labs):
            return labs[index]
        
        return None
    
    def search_labs(
        self,
        query: str,
        provider: Optional[CloudProvider] = None,
        difficulty: Optional[Difficulty] = None,
        min_score: int = 60
    ) -> list[LabSearchResult]:
        labs = self.discover_labs()
        
        if provider:
            labs = [lab for lab in labs if lab.provider == provider]
        
        if difficulty:
            labs = [lab for lab in labs if lab.difficulty == difficulty]
        
        if not query:
            return [
                LabSearchResult(lab=lab, score=100.0, matched_fields=[])
                for lab in labs
            ]
        
        results = []
        query_lower = query.lower()
        
        for lab in labs:
            score = 0
            matched_fields = []
            
            name_score = fuzz.partial_ratio(query_lower, lab.name.lower())
            if name_score > min_score:
                score = max(score, name_score)
                matched_fields.append("name")
            
            desc_score = fuzz.partial_ratio(query_lower, lab.description.lower())
            if desc_score > min_score:
                score = max(score, desc_score * 0.8)
                matched_fields.append("description")
            
            for obj in lab.learning_objectives:
                obj_score = fuzz.partial_ratio(query_lower, obj.lower())
                if obj_score > min_score:
                    score = max(score, obj_score * 0.7)
                    if "objectives" not in matched_fields:
                        matched_fields.append("objectives")
            
            if query_lower in lab.relative_path.lower():
                score = max(score, 90)
                if "path" not in matched_fields:
                    matched_fields.append("path")
            
            if score > min_score:
                results.append(
                    LabSearchResult(
                        lab=lab,
                        score=score,
                        matched_fields=matched_fields
                    )
                )
        
        return sorted(results, key=lambda x: x.score, reverse=True)
    
    def filter_by_tags(self, tags: list[str]) -> list[Lab]:
        labs = self.discover_labs()
        
        tag_lower = [t.lower() for t in tags]
        filtered = []
        
        for lab in labs:
            lab_text = f"{lab.name} {lab.description} {' '.join(lab.learning_objectives)}".lower()
            
            if any(tag in lab_text for tag in tag_lower):
                filtered.append(lab)
        
        return filtered