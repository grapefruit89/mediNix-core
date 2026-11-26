"""Unified command-line interface for mediNix arr-provision.

Consolidates all 8 previous standalone synchronization scripts:
- arr-sync-keys
- arr-sync-settings
- arr-sync-download-clients
- arr-sync-prowlarr
- arr-sync-locale
- arr-sync-profiles
- arr-sync-jellyfin
- arr-sync-seerr

Replaces serial time.sleep polling with kernel-epoll and systemd-journald
event streaming via arr_provision.events.
"""

from __future__ import annotations

import argparse
import logging
import os
from pathlib import Path
import sys
import tempfile
from typing import List, Optional

from arr_provision.events import ReadinessStatus, ReadinessTarget, wait_for_ready

logger = logging.getLogger("arr_provision")

# Symlink compatibility map (BusyBox style argv[0] dispatch)
ALIAS_MAP = {
    "arr-sync-keys": "keys",
    "arr-sync-settings": "settings",
    "arr-sync-download-clients": "clients",
    "arr-sync-prowlarr": "prowlarr",
    "arr-sync-locale": "locale",
    "arr-sync-profiles": "profiles",
    "arr-sync-jellyfin": "jellyfin",
    "arr-sync-seerr": "seerr",
}


def _setup_logging(debug: bool = False, quiet: bool = False) -> None:
    if debug:
        level = logging.DEBUG
        fmt = "%(levelname)-7s [%(name)s] %(message)s"
    elif quiet:
        level = logging.WARNING
        fmt = "%(levelname)-7s %(message)s"
    else:
        level = logging.INFO
        fmt = "%(message)s"

    logging.basicConfig(level=level, format=fmt, stream=sys.stderr)


def _collect_readiness_targets() -> List[ReadinessTarget]:
    """Collect active services from environment variables for parallel event-based readiness."""
    targets: List[ReadinessTarget] = []
    host = os.environ.get("ARR_HOST", "127.0.0.1")

    if os.environ.get("SYNC_SONARR", "0") == "1":
        port = int(os.environ.get("SONARR_PORT", "5003"))
        targets.append(
            ReadinessTarget(
                name="sonarr",
                host=host,
                port=port,
                path="/api/v3/system/status",
                systemd_unit="sonarr.service",
            )
        )

    if os.environ.get("SYNC_RADARR", "0") == "1":
        port = int(os.environ.get("RADARR_PORT", "5004"))
        targets.append(
            ReadinessTarget(
                name="radarr",
                host=host,
                port=port,
                path="/api/v3/system/status",
                systemd_unit="radarr.service",
            )
        )

    if os.environ.get("SYNC_PROWLARR", "0") == "1":
        port = int(os.environ.get("PROWLARR_PORT", "5002"))
        targets.append(
            ReadinessTarget(
                name="prowlarr",
                host=host,
                port=port,
                path="/api/v1/system/status",
                systemd_unit="prowlarr.service",
            )
        )

    if os.environ.get("SYNC_SABNZBD", "0") == "1":
        port = int(os.environ.get("SAB_PORT", "5410"))
        targets.append(
            ReadinessTarget(
                name="sabnzbd",
                host=host,
                port=port,
                path="/api?mode=version",
                systemd_unit="sabnzbd.service",
            )
        )

    if os.environ.get("SYNC_JELLYFIN", "0") == "1":
        port = int(os.environ.get("JELLYFIN_PORT", "5510"))
        targets.append(
            ReadinessTarget(
                name="jellyfin",
                host=host,
                port=port,
                path="/System/Info/Public",
                systemd_unit="jellyfin.service",
            )
        )

    if os.environ.get("SYNC_SEERR", "0") == "1":
        port = int(os.environ.get("SEERR_PORT", "5055"))
        targets.append(
            ReadinessTarget(
                name="seerr",
                host=host,
                port=port,
                path="/api/v1/status",
                systemd_unit="seerr.service",
            )
        )

    return targets


def _preflight_readiness(timeout: float = 60.0, use_journal: bool = True) -> bool:
    """Pre-flight check: wake up immediately when services emit listening events."""
    targets = _collect_readiness_targets()
    if not targets:
        logger.debug("No active service targets for readiness check.")
        return True

    logger.info("Pre-flight: waiting for %d target service(s) to become ready (event-driven)...", len(targets))
    statuses = wait_for_ready(targets, timeout=timeout, use_journal=use_journal)
    all_ready = True
    for st in statuses:
        if st.status != "ready":
            all_ready = False
            logger.error("Target %s failed readiness: %s (%s)", st.name, st.status, st.detail)
        else:
            logger.debug("Target %s ready via %s (%s, %d attempts)", st.name, st.source, st.detail, st.attempts)

    return all_ready


def _write_flag_file(flag_path: str) -> None:
    """Atomically write the flag file indicating successful provisioning."""
    p = Path(flag_path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", dir=str(p.parent), delete=False) as tf:
        tf.write("provisioned\n")
        temp_name = tf.name
    os.replace(temp_name, str(p))
    try:
        os.chmod(str(p), 0o640)
    except OSError:
        pass
    logger.info("Provisioning flag written to %s", p)


def run_keys() -> int:
    from arr_provision.arr_keys_sync import main as fn
    fn()
    return 0


def run_settings() -> int:
    from arr_provision.arr_settings_sync import main as fn
    fn()
    return 0


def run_clients() -> int:
    from arr_provision.download_clients import main as fn
    fn()
    return 0


def run_prowlarr() -> int:
    from arr_provision.prowlarr_sync import main as fn
    fn()
    return 0


def run_locale() -> int:
    from arr_provision.locale_sync import main as fn
    fn()
    return 0


def run_profiles() -> int:
    from arr_provision.profile_sync import main as fn
    fn()
    return 0


def run_jellyfin() -> int:
    from arr_provision.jellyfin_setup import main as fn
    fn()
    return 0


def run_seerr() -> int:
    from arr_provision.seerr_sync import main as fn
    fn()
    return 0


def run_all(args: argparse.Namespace) -> int:
    """Run all provisioning steps in dependency order."""
    if not args.no_preflight:
        ready = _preflight_readiness(timeout=args.timeout, use_journal=not args.no_journal)
        if not ready:
            logger.error("Pre-flight service readiness check failed. Aborting provision.")
            return 75  # EX_TEMPFAIL

    logger.info("Executing provisioning DAG...")
    
    # 1. API Keys (Read-only validation across active services)
    logger.info("── Step 1/8: arr-provision keys ──")
    run_keys()

    # 2. Settings (Root folders, repacks, language)
    logger.info("── Step 2/8: arr-provision settings ──")
    run_settings()

    # 3. Download Clients (SABnzbd in media managers)
    logger.info("── Step 3/8: arr-provision clients ──")
    run_clients()

    # 4. Prowlarr (Indexers, apps, sync)
    logger.info("── Step 4/8: arr-provision prowlarr ──")
    run_prowlarr()

    # 5. Locale (Jellyfin metadata language & SABnzbd config)
    logger.info("── Step 5/8: arr-provision locale ──")
    run_locale()

    # 6. Profiles (TRaSH profiles on existing library media)
    logger.info("── Step 6/8: arr-provision profiles ──")
    run_profiles()

    # 7. Jellyfin (Libraries, options, extra users)
    if os.environ.get("SYNC_JELLYFIN", "0") == "1":
        logger.info("── Step 7/8: arr-provision jellyfin ──")
        run_jellyfin()
    else:
        logger.debug("Step 7/8 Jellyfin skipped (SYNC_JELLYFIN != 1)")

    # 8. Seerr (Auth init & media manager connection)
    if os.environ.get("SYNC_SEERR", "0") == "1":
        logger.info("── Step 8/8: arr-provision seerr ──")
        run_seerr()
    else:
        logger.debug("Step 8/8 Seerr skipped (SYNC_SEERR != 1)")

    if not args.dry_run and args.flag_file:
        _write_flag_file(args.flag_file)

    logger.info("All provisioning steps completed successfully.")
    return 0


def build_parser() -> argparse.ArgumentParser:
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("-v", "--debug", action="store_true", help="Enable debug logging")
    common.add_argument("-q", "--quiet", action="store_true", help="Only show warnings and errors")
    common.add_argument("-n", "--dry-run", action="store_true", help="Do not mutate remote states or write flag file")
    common.add_argument("--timeout", type=float, default=60.0, help="Pre-flight readiness timeout in seconds (default: 60.0)")
    common.add_argument("--no-journal", action="store_true", help="Disable systemd-journald streaming during readiness")
    common.add_argument("--no-preflight", action="store_true", help="Skip pre-flight event-driven readiness check")
    common.add_argument(
        "--flag-file",
        default=os.environ.get("FLAG_FILE", "/var/lib/mediNix-state/provisioned"),
        help="Path to flag file touched on complete success (default: $FLAG_FILE)",
    )

    parser = argparse.ArgumentParser(
        prog="arr-provision",
        description="Unified declarative API provisioning CLI for mediNix media stack",
        parents=[common],
    )

    subparsers = parser.add_subparsers(dest="subcommand", help="Provisioning step")

    subparsers.add_parser("all", parents=[common], help="Execute complete provisioning DAG (all 8 steps)")
    subparsers.add_parser("keys", parents=[common], help="Verify declarative API keys across all services")
    subparsers.add_parser("settings", parents=[common], help="Sync root folders, media management, and release profiles")
    subparsers.add_parser("clients", aliases=["download-clients"], parents=[common], help="Register download clients (SABnzbd) in media managers")
    subparsers.add_parser("prowlarr", parents=[common], help="Register Prowlarr indexers and applications")
    subparsers.add_parser("locale", parents=[common], help="Sync locale and categories in Jellyfin and SABnzbd")
    subparsers.add_parser("profiles", parents=[common], help="Apply TRaSH quality profiles to media")
    subparsers.add_parser("jellyfin", parents=[common], help="Configure Jellyfin libraries, users, and options")
    subparsers.add_parser("seerr", parents=[common], help="Configure Seerr connections and settings")

    return parser


def main(argv: Optional[List[str]] = None) -> int:
    if argv is None:
        argv = sys.argv[1:]

    # Check for BusyBox-style invocation via symlink
    prog_name = os.path.basename(sys.argv[0])
    if prog_name in ALIAS_MAP:
        subcmd = ALIAS_MAP[prog_name]
        # Prepend the mapped subcommand if not already explicitly supplied
        if not argv or argv[0] != subcmd:
            argv = [subcmd] + argv

    parser = build_parser()
    args = parser.parse_args(argv)

    _setup_logging(debug=args.debug, quiet=args.quiet)

    if not args.subcommand or args.subcommand == "all":
        return run_all(args)
    elif args.subcommand == "keys":
        return run_keys()
    elif args.subcommand == "settings":
        return run_settings()
    elif args.subcommand in ("clients", "download-clients"):
        return run_clients()
    elif args.subcommand == "prowlarr":
        return run_prowlarr()
    elif args.subcommand == "locale":
        return run_locale()
    elif args.subcommand == "profiles":
        return run_profiles()
    elif args.subcommand == "jellyfin":
        return run_jellyfin()
    elif args.subcommand == "seerr":
        return run_seerr()
    else:
        parser.print_help()
        return 2
