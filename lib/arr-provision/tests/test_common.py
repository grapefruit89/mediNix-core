import tempfile
import unittest
from pathlib import Path

from arr_provision.common import arr_api_base, read_key_file, title_case_service


class CommonHelpersTest(unittest.TestCase):
    def test_arr_api_base(self) -> None:
        self.assertEqual(arr_api_base("127.0.0.1", 5003, "v3"), "http://127.0.0.1:5003/api/v3")

    def test_title_case_service(self) -> None:
        self.assertEqual(title_case_service("sonarr"), "Sonarr")

    def test_read_key_file_missing(self) -> None:
        self.assertIsNone(read_key_file("/definitely/missing/key"))

    def test_read_key_file_xml(self) -> None:
        with tempfile.NamedTemporaryFile("w+", delete=False) as tf:
            tf.write("<Config>\n  <ApiKey>1234567890abcdef1234567890abcdef</ApiKey>\n</Config>")
            tf.flush()
            path = tf.name
        try:
            self.assertEqual(read_key_file(path), "1234567890abcdef1234567890abcdef")
        finally:
            Path(path).unlink(missing_ok=True)

    def test_read_key_file_ini_with_sections(self) -> None:
        with tempfile.NamedTemporaryFile("w+", delete=False) as tf:
            tf.write("[misc]\nport = 5410\napi_key = a1b2c3d4e5f678901234567890abcdef\nnzb_key = z9y8x7w6\n")
            tf.flush()
            path = tf.name
        try:
            self.assertEqual(read_key_file(path), "a1b2c3d4e5f678901234567890abcdef")
        finally:
            Path(path).unlink(missing_ok=True)

    def test_read_key_file_env_style(self) -> None:
        with tempfile.NamedTemporaryFile("w+", delete=False) as tf:
            tf.write("API_KEY=envkey1234567890abcdef1234567890\n")
            tf.flush()
            path = tf.name
        try:
            self.assertEqual(read_key_file(path), "envkey1234567890abcdef1234567890")
        finally:
            Path(path).unlink(missing_ok=True)

    def test_read_key_file_plaintext(self) -> None:
        with tempfile.NamedTemporaryFile("w+", delete=False) as tf:
            tf.write("32charplaintoken1234567890abcdef\n")
            tf.flush()
            path = tf.name
        try:
            self.assertEqual(read_key_file(path), "32charplaintoken1234567890abcdef")
        finally:
            Path(path).unlink(missing_ok=True)

    def test_read_key_file_empty(self) -> None:
        with tempfile.NamedTemporaryFile("w+", delete=False) as tf:
            tf.write("   \n")
            tf.flush()
            path = tf.name
        try:
            self.assertIsNone(read_key_file(path))
        finally:
            Path(path).unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()