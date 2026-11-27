import json
import unittest
from io import BytesIO, StringIO
from unittest.mock import patch
from urllib.error import HTTPError

from scripts.check_workos_oidc import main, validate_issuer, validate_metadata


ISSUER = "https://staging-example.authkit.app"
DISCOVERY = {
    "issuer": ISSUER,
    "authorization_endpoint": ISSUER + "/oauth2/authorize",
    "token_endpoint": ISSUER + "/oauth2/token",
    "jwks_uri": ISSUER + "/oauth2/jwks",
    "grant_types_supported": ["authorization_code", "refresh_token"],
    "response_types_supported": ["code"],
    "subject_types_supported": ["public"],
    "token_endpoint_auth_methods_supported": ["none", "client_secret_post"],
    "id_token_signing_alg_values_supported": ["RS256"],
}


class WorkOSDiscoveryTests(unittest.TestCase):
    def test_documented_discovery_metadata_passes(self):
        self.assertEqual(validate_issuer(ISSUER), ISSUER)
        validate_metadata(ISSUER, DISCOVERY)

    def test_rejects_incorrect_issuer(self):
        with self.assertRaisesRegex(ValueError, "issuer"):
            validate_metadata(ISSUER, {**DISCOVERY, "issuer": ISSUER + "/"})

    def test_rejects_endpoints_outside_expected_issuer_and_paths(self):
        for field, url in {
            "authorization_endpoint": ISSUER + "/other",
            "token_endpoint": "https://other.example/oauth2/token",
            "jwks_uri": "http://staging-example.authkit.app/oauth2/jwks",
        }.items():
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, field):
                validate_metadata(ISSUER, {**DISCOVERY, field: url})

    def test_rejects_missing_or_malformed_capabilities(self):
        for field, invalid in {
            "grant_types_supported": ["client_credentials"],
            "response_types_supported": ["id_token"],
            "token_endpoint_auth_methods_supported": ["client_secret_basic"],
            "id_token_signing_alg_values_supported": ["HS256"],
            "subject_types_supported": "public",
        }.items():
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, field):
                validate_metadata(ISSUER, {**DISCOVERY, field: invalid})

    def test_rejects_non_origin_input(self):
        for suffix in ("/", "/oauth2", "?query=example", "#fragment", ":443"):
            with self.subTest(suffix=suffix), self.assertRaises(ValueError):
                validate_issuer(ISSUER + suffix)
        with self.assertRaises(ValueError):
            validate_issuer("http://staging-example.authkit.app")

    def test_cli_reads_public_discovery(self):
        with patch("sys.stdout", new_callable=StringIO), \
                patch("scripts.check_workos_oidc.build_opener") as opener:
            request = opener.return_value.open
            request.return_value = BytesIO(json.dumps(DISCOVERY).encode())
            self.assertEqual(main([ISSUER]), 0)
            request.assert_called_once_with(ISSUER + "/.well-known/openid-configuration", timeout=10)

    def test_cli_reports_http_errors_without_printing_response_body(self):
        with patch("sys.stderr", new_callable=StringIO) as stderr, \
                patch("scripts.check_workos_oidc.build_opener") as opener:
            opener.return_value.open.side_effect = HTTPError(ISSUER, 302, "response detail", None, None)
            self.assertEqual(main([ISSUER]), 1)
            self.assertIn("without redirects", stderr.getvalue())
            self.assertNotIn("response detail", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
