from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any
import time
import json
from pathlib import Path
from datetime import datetime


@dataclass
class AttackResult:
    success: bool
    phase: str
    message: str
    data: dict[str, Any] | None = None
    timestamp: float | None = None
    verbose_log: list[str] = field(default_factory=list)
    
    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = time.time()


class BaseAttackChain(ABC):
    def __init__(self, outputs: dict[str, Any], verbose: bool = False, log_file: str | None = None):
        self.outputs = outputs
        self.results: list[AttackResult] = []
        self.verbose = verbose
        self.log_file = log_file
        self.verbose_buffer: list[str] = []
        
    @abstractmethod
    def run(self) -> list[AttackResult]:
        """Execute the complete attack chain"""
        pass
    
    def log_phase(self, phase: str, success: bool, message: str, data: dict[str, Any] | None = None):
        result = AttackResult(
            success=success,
            phase=phase,
            message=message,
            data=data or {},
            verbose_log=self.verbose_buffer.copy()
        )
        self.results.append(result)
        print(f"[{'✓' if success else '✗'}] {phase}: {message}")
        self.verbose_buffer.clear()
        return result
    
    def log_verbose(self, message: str, data: Any = None):
        """Log detailed execution information"""
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        log_entry = f"[{timestamp}] {message}"
        
        if data is not None:
            if isinstance(data, (dict, list)):
                log_entry += f"\n{json.dumps(data, indent=2)}"
            else:
                log_entry += f"\n{data}"
        
        self.verbose_buffer.append(log_entry)
        
        if self.verbose:
            print(f"  [debug] {message}")
            if data is not None:
                if isinstance(data, (dict, list)):
                    print(f"  {json.dumps(data, indent=2)}")
                elif isinstance(data, str) and len(data) > 200:
                    print(f"  {data[:200]}...")
                else:
                    print(f"  {data}")
    
    def save_log(self):
        """Save complete attack log to file"""
        if not self.log_file:
            return
        
        log_data = {
            "timestamp": datetime.now().isoformat(),
            "outputs": self.outputs,
            "phases": []
        }
        
        for result in self.results:
            log_data["phases"].append({
                "phase": result.phase,
                "success": result.success,
                "message": result.message,
                "timestamp": result.timestamp,
                "data": result.data,
                "verbose_log": result.verbose_log
            })
        
        Path(self.log_file).write_text(json.dumps(log_data, indent=2))
        print(f"\n[log] Attack log saved to: {self.log_file}")