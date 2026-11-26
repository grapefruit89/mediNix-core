"""Unit tests for arr-provision unified CLI and symlink dispatch."""

import os
import unittest
from unittest.mock import patch

from arr_provision.cli import ALIAS_MAP, build_parser, _collect_readiness_targets, main


class CliTests(unittest.TestCase):
    def test_alias_map(self) -> None:
        self.assertEqual(ALIAS_MAP["arr-sync-keys"], "keys")
        self.assertEqual(ALIAS_MAP["arr-sync-settings"], "settings")
        self.assertEqual(ALIAS_MAP["arr-sync-download-clients"], "clients")
        self.assertEqual(ALIAS_MAP["arr-sync-prowlarr"], "prowlarr")
        self.assertEqual(ALIAS_MAP["arr-sync-locale"], "locale")
        self.assertEqual(ALIAS_MAP["arr-sync-profiles"], "profiles")
        self.assertEqual(ALIAS_MAP["arr-sync-jellyfin"], "jellyfin")
        self.assertEqual(ALIAS_MAP["arr-sync-seerr"], "seerr")

    def test_parser_subcommands(self) -> None:
        parser = build_parser()
        args = parser.parse_args(["keys"])
        self.assertEqual(args.subcommand, "keys")

        args = parser.parse_args(["all", "--debug", "--dry-run", "--no-preflight"])
        self.assertEqual(args.subcommand, "all")
        self.assertTrue(args.debug)
        self.assertTrue(args.dry_run)
        self.assertTrue(args.no_preflight)

        args = parser.parse_args(["clients"])
        self.assertEqual(args.subcommand, "clients")

    def test_collect_readiness_targets_from_env(self) -> None:
        env = {
            "SYNC_SONARR": "1",
            "SONARR_PORT": "5003",
            "SYNC_PROWLARR": "1",
            "PROWLARR_PORT": "5002",
            "SYNC_RADARR": "0",
        }
        with patch.dict(os.environ, env, clear=False):
            targets = _collect_readiness_targets()
            names = [t.name for t in targets]
            self.assertIn("sonarr", names)
            self.assertIn("prowlarr", names)
            self.assertNotIn("radarr", names)

    @patch("arr_provision.cli.run_keys")
    def test_main_symlink_dispatch(self, mock_run_keys) -> None:
        mock_run_keys.return_value = 0
        with patch("sys.argv", ["/nix/store/test/bin/arr-sync-keys"]):
            exit_code = main([])
            self.assertEqual(exit_code, 0)
            mock_run_keys.assert_called_once()
