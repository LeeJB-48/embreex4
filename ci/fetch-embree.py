#!/usr/bin/env python3
"""A Python 3 standard library only utility to download embree releases
and copy them into the home directory for every plaform.
"""

import os
import sys
import json
import tarfile
import logging
import argparse
import shutil
from io import BytesIO
from fnmatch import fnmatch
from platform import system, machine
from typing import Optional
from zipfile import ZipFile

log = logging.getLogger("embreex")
log.setLevel(logging.DEBUG)
log.addHandler(logging.StreamHandler(sys.stdout))
_cwd = os.path.abspath(os.path.expanduser(os.path.dirname(__file__)))


def fetch(url, sha256):
    """A simple standard-library only "fetch remote URL" function.

    Parameters
    ----------
    url : str
      Location of remote resource.
    sha256: str
      The SHA256 hash of the resource once retrieved,
      wil raise a `ValueError` if the hash doesn't match.

    Returns
    -------
    data : bytes
      Retrieved data in memory with correct hash.

    """
    import hashlib
    from urllib.request import urlopen

    data = urlopen(url).read()
    hashed = hashlib.sha256(data).hexdigest()
    if hashed != sha256:
        log.error(f"`{hashed}` != `{sha256}`")
        raise ValueError("sha256 hash does not match!")

    return data


def extract(tar, member, path, chmod):
    """Extract a single member from a tarfile to a path."""
    if os.path.isdir(path):
        return

    if hasattr(tar, "extractfile"):
        # a tarfile
        data = tar.extractfile(member=member)
        if not hasattr(data, "read"):
            return
        data = data.read()
    else:
        # ZipFile -_-
        data = tar.read(member.filename)

    if len(data) == 0:
        return
    # make sure root path exists
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)
    if chmod is not None:
        # python os.chmod takes an octal value
        os.chmod(path, int(str(chmod), base=8))


def handle_fetch(
    url: str,
    sha256: str,
    target: str,
    chmod: Optional[int] = None,
    extract_skip: Optional[bool] = None,
    extract_only: Optional[bool] = None,
    strip_components: int = 0,
):
    """A macro to fetch a remote resource (usually an executable) and
    move it somewhere on the file system.

    Parameters
    ----------
    url : str
      A string with a remote resource.
    sha256 : str
      A hex string for the hash of the remote resource.
    target : str
      Target location on the local file system.
    chmod : None or int.
      Change permissions for extracted files.
    extract_skip : None or iterable
      Skip a certain member of the archive.
    extract_only : None or str
      Extract *only* a single file from the archive,
      overrides `extract_skip`.
    strip_components : int
      Strip off this many components from the file path
      in the archive, i.e. at `1`, `a/b/c` is extracted to `target/b/c`

    """
    if ".." in target:
        target = os.path.join(_cwd, target)
    target = os.path.abspath(os.path.expanduser(target))

    if os.path.exists(target):
        log.debug(f"`{target}` exists, skipping")
        repair_text_symlinks(target)
        return

    # get the raw bytes
    log.debug(f"fetching: `{url}`")
    raw = fetch(url=url, sha256=sha256)

    if len(raw) == 0:
        raise ValueError(f"{url} is empty!")

    # if we have an archive that tar supports
    if url.endswith((".tar.gz", ".tar.xz", ".tar.bz2", "zip")):
        if url.endswith(".zip"):
            tar = ZipFile(BytesIO(raw))
            members = tar.infolist()
        else:
            # mode needs to know what type of compression
            mode = f'r:{url.split(".")[-1]}'
            # get the archive
            tar = tarfile.open(fileobj=BytesIO(raw), mode=mode)
            members = tar.getmembers()

        if extract_skip is None:
            extract_skip = []

        for member in members:
            if hasattr(member, "filename"):
                name = member.filename
            else:
                name = member.name

            # final name after stripping components
            name = "/".join(name.split("/")[strip_components:])

            # if any of the skip patterns match continue
            if any(fnmatch(name, p) for p in extract_skip):
                log.debug(f"skipping: `{name}`")
                continue

            if extract_only is None:
                path = os.path.join(target, name)
                log.debug(f"extracting: `{path}`")
                extract(tar=tar, member=member, path=path, chmod=chmod)
            else:
                name = name.split("/")[-1]
                if name == extract_only:
                    path = os.path.join(target, name)
                    log.debug(f"extracting `{path}`")
                    extract(tar=tar, member=member, path=path, chmod=chmod)
                    return
    else:
        # a single file
        name = url.split("/")[-1].strip()
        path = target
        with open(path, "wb") as f:
            f.write(raw)

        # apply chmod if requested
        if chmod is not None:
            # python os.chmod takes an octal value
            os.chmod(path, int(str(chmod), base=8))

    repair_text_symlinks(target)


def load_config(path: Optional[str] = None) -> list:
    """Load a config file for embree download locations."""
    if path is None or len(path) == 0:
        # use a default config file
        path = os.path.join(_cwd, "embree.json")
    with open(path, "r") as f:
        return json.load(f)


def _normalize_arch(value: str) -> str:
    """Normalize platform.machine outputs to config arch values."""
    value = value.lower()
    if value in ("amd64", "x86_64", "x64"):
        return "x86_64"
    if value in ("arm64", "aarch64"):
        return "arm64"
    return value


def is_current_platform(platform: str, arch: Optional[str] = None) -> bool:
    """Check to see if a string platform identifier matches the current platform."""
    current = system().lower().strip()
    if current.startswith("dar"):
        match = platform.startswith("dar") or platform.startswith("mac")
    elif current.startswith("win"):
        match = platform.startswith("win")
    elif current.startswith("lin"):
        match = platform.startswith("lin")
    else:
        raise ValueError(f"{current} ?= {platform}")

    if not match:
        return False

    if arch is None:
        return True

    return _normalize_arch(machine()) == _normalize_arch(arch)


def repair_text_symlinks(target_root: str) -> None:
    """Some embree archives store symlinks as text files; repair them."""
    lib_dir = os.path.join(target_root, "lib")
    if not os.path.isdir(lib_dir):
        return

    for name in os.listdir(lib_dir):
        path = os.path.join(lib_dir, name)
        if not os.path.isfile(path):
            continue

        try:
            size = os.path.getsize(path)
        except OSError:
            continue

        # heuristic: tiny placeholder files typically contain symlink targets
        if size == 0 or size > 64:
            continue

        try:
            with open(path, "r") as f:
                target = f.read().strip()
        except Exception:
            continue

        if len(target) == 0:
            continue

        target_path = os.path.join(lib_dir, target)
        if not os.path.exists(target_path):
            continue

        try:
            os.remove(path)
        except OSError:
            continue

        try:
            os.symlink(target, path)
        except OSError:
            shutil.copy2(target_path, path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Install system packages for trimesh.")
    parser.add_argument("--install", type=str, action="append", help="Install package.")
    parser.add_argument(
        "--config", type=str, help="Specify a different config JSON path"
    )

    args = parser.parse_args()

    config = load_config(path=args.config)

    # allow comma delimeters and de-duplicate
    if args.install is None:
        parser.print_help()
        exit()
    else:
        select = set(" ".join(args.install).replace(",", " ").split())

    for option in config:
        if option["name"] in select and is_current_platform(option["platform"], option.get("arch")):
            subset = option.copy()
            subset.pop("name")
            subset.pop("platform")
            subset.pop("arch", None)
            handle_fetch(**subset)
