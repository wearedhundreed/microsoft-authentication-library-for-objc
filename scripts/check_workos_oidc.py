#!/usr/bin/env python3
"""Check public WorkOS discovery metadata for Entra External ID federation."""

import argparse
import json
import re
import sys
from urllib.request import HTTPRedirectHandler, build_opener


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def validate_issuer(issuer):
    dns_label = r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?"
    if not re.fullmatch(rf"https://{dns_label}(?:\.{dns_label})+", issuer):
        raise ValueError("Use the HTTPS AuthKit origin, without a port, path, or trailing slash.")
    return issuer


def validate_metadata(issuer, metadata):
    if not isinstance(metadata, dict):
        raise ValueError("Discovery metadata must be a JSON object.")
    if metadata.get("issuer") != issuer:
        raise ValueError("Discovery issuer does not match the configured AuthKit origin.")

    endpoints = {
        "authorization_endpoint": "/oauth2/authorize",
        "token_endpoint": "/oauth2/token",
        "jwks_uri": "/oauth2/jwks",
    }
    for field, path in endpoints.items():
        if metadata.get(field) != issuer + path:
            raise ValueError(f"Unexpected WorkOS endpoint in {field}.")

    capabilities = {
        "grant_types_supported": "authorization_code",
        "response_types_supported": "code",
        "subject_types_supported": "public",
        "token_endpoint_auth_methods_supported": "client_secret_post",
        "id_token_signing_alg_values_supported": "RS256",
    }
    for field, required in capabilities.items():
        advertised = metadata.get(field)
        if not isinstance(advertised, list) or required not in advertised:
            raise ValueError(f"{field} must advertise {required}.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("issuer", help="Public staging AuthKit origin from the WorkOS Dashboard")
    args = parser.parse_args(argv)
    try:
        issuer = validate_issuer(args.issuer)
    except ValueError as error:
        parser.error(str(error))

    discovery_url = issuer + "/.well-known/openid-configuration"
    try:
        with build_opener(NoRedirect()).open(discovery_url, timeout=10) as response:
            metadata = json.load(response)
    except (OSError, ValueError):
        print("Could not read public WorkOS discovery metadata over HTTPS without redirects.", file=sys.stderr)
        return 1
    try:
        validate_metadata(issuer, metadata)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1

    print("WorkOS discovery advertises the expected Entra federation settings.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
