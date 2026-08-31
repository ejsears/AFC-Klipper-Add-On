"""Regression tests for issue #853.

Two related installer bugs:

1. ``afc_path`` was hardcoded to ``$HOME/AFC-Klipper-Add-On`` in both
   ``install-afc.sh`` and ``update-afc.sh``. Cloning the repo anywhere else
   (e.g. ``/usr/data`` on Creality K1 machines, where cloning into ``/root``
   can fill the tiny rootfs) made the installer ignore the real checkout,
   print a bogus "installed via ZIP file" warning, and then fail with
   ``cp: can't stat '.../config/AFC.cfg'``. It must resolve from the
   script's own location (``SCRIPT_DIR``) instead.

2. ``install-afc.sh`` documented a ``-m`` flag (Moonraker config path) but
   unconditionally overwrote it with ``$printer_config_dir/moonraker.conf``.

3. The Moonraker ``[update_manager afc-software]`` block hardcoded
   ``path: ~/AFC-Klipper-Add-On`` instead of the resolved add-on path.
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
ANSI = re.compile(r"\x1b\[[0-9;]*m")

# Files/dirs the installer needs to reach the main menu.
_CHECKOUT_ITEMS = ("install-afc.sh", "update-afc.sh", "include", "config", "templates")


def _make_checkout(dest: Path) -> Path:
    """Copy the add-on tree to ``dest`` with a ``.git`` dir so it reads as a
    real git checkout."""
    dest.mkdir(parents=True)
    for item in _CHECKOUT_ITEMS:
        src = REPO_ROOT / item
        dst = dest / item
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)
    (dest / ".git").mkdir()
    (dest / "extras").mkdir()
    return dest


@pytest.fixture
def fake_checkout(tmp_path: Path) -> Path:
    """A checkout at a path *outside* ``$HOME``."""
    return _make_checkout(tmp_path / "opt" / "AFC-Klipper-Add-On")


def _make_zip_extract(dest: Path) -> Path:
    """Like ``_make_checkout`` but with no ``.git`` dir, mimicking an
    extracted release archive."""
    checkout = _make_checkout(dest)
    shutil.rmtree(checkout / ".git")
    return checkout


def _run_installer(checkout: Path, home: Path, *args: str, stdin: str = "Q\n") -> tuple[int, str]:
    (home / "printer_data" / "config").mkdir(parents=True, exist_ok=True)
    (home / "klipper" / "klippy" / "extras").mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["HOME"] = str(home)
    env["LC_ALL"] = "C"
    proc = subprocess.run(
        [
            "bash",
            "install-afc.sh",
            "-t",  # test_mode: skip python-version check and the git clone/restart
            "-p", str(home / "printer_data" / "config"),
            "-k", str(home / "klipper"),
            "-y", str(home / "klippy-env" / "bin"),
            *args,
        ],
        cwd=checkout,
        env=env,
        input=stdin,
        capture_output=True,
        text=True,
        timeout=60,
    )
    return proc.returncode, ANSI.sub("", proc.stdout + proc.stderr)


def test_afc_path_follows_script_location_not_home(fake_checkout: Path, tmp_path: Path):
    # Running from a real checkout that is NOT at $HOME/AFC-Klipper-Add-On must
    # not be mistaken for a ZIP install, and must exit cleanly.
    rc, out = _run_installer(fake_checkout, tmp_path / "home")
    assert "installed via ZIP" not in out, out
    assert rc == 0, out


def test_canonical_home_checkout_still_works(tmp_path: Path):
    # The common case (repo cloned at ~/AFC-Klipper-Add-On) is unchanged:
    # SCRIPT_DIR resolves to the same place $HOME/AFC-Klipper-Add-On used to,
    # so there is no ZIP warning and the installer still reaches the menu.
    home = tmp_path / "home"
    checkout = _make_checkout(home / "AFC-Klipper-Add-On")
    rc, out = _run_installer(checkout, home)
    assert "installed via ZIP" not in out, out
    assert rc == 0, out
    default_moonraker = home / "printer_data" / "config" / "moonraker.conf"
    assert f"Moonraker Config File    : {default_moonraker}" in out, out


def test_zip_extract_outside_home_is_detected_and_usable(tmp_path: Path):
    # No .git dir (extracted archive). The installer must still recognise it as
    # a ZIP install and operate on the extracted location, wherever it is,
    # rather than a hardcoded ~/AFC-Klipper-Add-On.
    home = tmp_path / "home"
    extract = _make_zip_extract(tmp_path / "downloads" / "AFC-Klipper-Add-On-main")
    # First newline answers check_for_zip_install's "Press Enter"; Q exits the menu.
    rc, out = _run_installer(extract, home, stdin="\nQ\n")
    assert "installed via ZIP file" in out, out
    assert "config/AFC.cfg" not in out, out  # i.e. no "can't stat" failure
    assert rc == 0, out


def test_m_flag_is_honoured(fake_checkout: Path, tmp_path: Path):
    custom = tmp_path / "elsewhere" / "moonraker.conf"
    rc, out = _run_installer(fake_checkout, tmp_path / "home", "-m", str(custom))
    assert f"Moonraker Config File    : {custom}" in out, out


def test_m_flag_defaults_to_printer_config_dir(fake_checkout: Path, tmp_path: Path):
    home = tmp_path / "home"
    rc, out = _run_installer(fake_checkout, home)
    expected = home / "printer_data" / "config" / "moonraker.conf"
    assert f"Moonraker Config File    : {expected}" in out, out


_MOONRAKER_HARNESS = r"""
set -u
REPO="{repo}"
source "$REPO/include/constants.sh"
source "$REPO/include/update_commands.sh"
restart_service() {{ :; }}
export HOME="{home}"
afc_path="{afc_path}"
moonraker_config_file="$(mktemp)"
update_moonraker_config
cat "$moonraker_config_file"
rm -f "$moonraker_config_file"
"""


def _run_moonraker_update(afc_path: str, home: str) -> str:
    script = _MOONRAKER_HARNESS.format(repo=REPO_ROOT, afc_path=afc_path, home=home)
    proc = subprocess.run(
        ["bash", "-c", script], capture_output=True, text=True, timeout=30
    )
    assert proc.returncode == 0, proc.stderr
    return proc.stdout


def test_moonraker_update_manager_uses_home_relative_path():
    out = _run_moonraker_update("/root/AFC-Klipper-Add-On", "/root")
    assert "path: ~/AFC-Klipper-Add-On" in out, out


def test_moonraker_update_manager_uses_absolute_path_outside_home():
    # e.g. a K1 clone under /usr/data
    out = _run_moonraker_update("/usr/data/AFC-Klipper-Add-On", "/root")
    assert "path: /usr/data/AFC-Klipper-Add-On" in out, out
    assert "path: ~/AFC-Klipper-Add-On" not in out, out
