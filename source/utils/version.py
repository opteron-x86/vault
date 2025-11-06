from importlib.metadata import version, PackageNotFoundError

def get_version() -> str:
    try:
        return version("vault")
    except PackageNotFoundError:
        return "unknown"