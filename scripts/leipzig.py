"""Downloads Leipzig Corpora Collection archives into build/corpora/ (shared by the build scripts)."""

import hashlib
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CORPORA_DIR = ROOT / "build" / "corpora"
DOWNLOAD_URL = "https://downloads.wortschatz-leipzig.de/corpora/{}.tar.gz"


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(1 << 20):
            digest.update(chunk)
    return digest.hexdigest()


def download(corpus: str, expected_sha256: str) -> pathlib.Path:
    """Path of the corpus archive, downloading it first if needed; exits if its SHA-256 differs.

    Uses curl rather than urllib: python.org builds of Python ship without CA certificates.
    """
    path = CORPORA_DIR / f"{corpus}.tar.gz"
    if not path.exists():
        CORPORA_DIR.mkdir(parents=True, exist_ok=True)
        partial = path.with_suffix(".part")
        url = DOWNLOAD_URL.format(corpus)
        print(f"downloading {url}", file=sys.stderr)
        subprocess.run(
            ["curl", "--fail", "--location", "--silent", "--show-error", "--connect-timeout", "30",
             "--speed-limit", "10000", "--speed-time", "60", "--output", partial, url],
            check=True,
        )
        partial.rename(path)
    actual = sha256(path)
    if actual != expected_sha256:
        sys.exit(f"{path}: SHA-256 {actual} does not match the pinned {expected_sha256}; "
                 "delete the file to download it again, or update the pin if Leipzig republished it")
    return path
