from typing import Type
from vault.attacks.base import BaseAttackChain

ATTACK_CHAINS: dict[str, Type[BaseAttackChain]] = {}


def register_attack(provider: str, lab_name: str):
    def decorator(cls: Type[BaseAttackChain]):
        key = f"{provider}/{lab_name}"
        ATTACK_CHAINS[key] = cls
        return cls
    return decorator


class AttackChainLoader:
    @staticmethod
    def load(provider: str, lab_name: str) -> Type[BaseAttackChain] | None:
        key = f"{provider}/{lab_name}"
        return ATTACK_CHAINS.get(key)
    
    @staticmethod
    def list_available() -> list[str]:
        return list(ATTACK_CHAINS.keys())

try:
    from vault.attacks.aws import ssrf_metadata
except ImportError:
    pass