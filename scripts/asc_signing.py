#!/usr/bin/env python3
"""App Store signing for the TestFlight workflow, through the App Store
Connect API (no Mac, no registered devices).

    asc_signing.py prepare <csr.pem> <out_dir>
        Revokes older distribution certificates (keeping the newest one, so
        the last build can finish processing), creates a new one from the
        CSR, and makes fresh App Store provisioning profiles with it: one
        for the app and, when WIDGETS_BUNDLE_ID is set, one for the widgets.
        Writes <out_dir>/distribution.cer, <out_dir>/profile.mobileprovision
        (and widgets.mobileprovision) and prints PROFILE_NAME / PROFILE_UUID /
        WIDGETS_PROFILE_NAME / WIDGETS_PROFILE_UUID / CERT_ID lines.

Needs ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH and BUNDLE_ID in the
environment (WIDGETS_BUNDLE_ID optional), and PyJWT + cryptography.
"""
import base64
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com/v1"
PROFILE_NAME = "Poddeck CI App Store"
WIDGETS_PROFILE_NAME = "Poddeck Widgets CI App Store"


def token():
    key = pathlib.Path(os.environ["ASC_KEY_PATH"]).read_text()
    now = int(time.time())
    payload = {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"}
    return jwt.encode(payload, key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})


def call(method, path, body=None):
    request = urllib.request.Request(
        path if path.startswith("http") else API + path,
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")
        sys.exit(f"App Store Connect said {error.code} to {method} {path}:\n{detail}")


def bundle_record(identifier):
    """The App ID record made in the developer portal."""
    found = call("GET", f"/bundleIds?filter[identifier]={identifier}&limit=50")["data"]
    matches = [b for b in found if b["attributes"]["identifier"] == identifier]
    if not matches:
        sys.exit(f"No App ID for {identifier}. Create it in Certificates, Identifiers & Profiles (docs/SETUP.md).")
    return matches[0]["id"]


def make_profile(name, bundle, cert_id, path):
    """A fresh App Store profile (old ones with this name go)."""
    for profile in call("GET", f"/profiles?filter[name]={urllib.parse.quote(name)}&limit=50")["data"]:
        call("DELETE", f"/profiles/{profile['id']}")
    profile = call("POST", "/profiles", {
        "data": {
            "type": "profiles",
            "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": bundle}},
                "certificates": {"data": [{"type": "certificates", "id": cert_id}]},
            },
        }
    })["data"]
    path.write_bytes(base64.b64decode(profile["attributes"]["profileContent"]))
    return profile["attributes"]["uuid"]


def prepare(csr_path, out_dir):
    out = pathlib.Path(out_dir)

    # 1. The App ID records (made in the developer portal).
    bundle = bundle_record(os.environ["BUNDLE_ID"])
    widgets_id = os.environ.get("WIDGETS_BUNDLE_ID")
    widgets = bundle_record(widgets_id) if widgets_id else None

    # 2. Keep at most two distribution certificates: revoke all but the newest.
    certs = call("GET", "/certificates?filter[certificateType]=DISTRIBUTION,IOS_DISTRIBUTION&limit=50")["data"]
    certs.sort(key=lambda c: c["attributes"].get("expirationDate") or "", reverse=True)
    for old in certs[1:]:
        print(f"Revoking older distribution certificate {old['id']}", file=sys.stderr)
        call("DELETE", f"/certificates/{old['id']}")

    # 3. A new certificate for this build's key.
    csr = pathlib.Path(csr_path).read_text()
    cert = call("POST", "/certificates", {
        "data": {"type": "certificates", "attributes": {"certificateType": "DISTRIBUTION", "csrContent": csr}}
    })["data"]
    (out / "distribution.cer").write_bytes(base64.b64decode(cert["attributes"]["certificateContent"]))

    # 4. Fresh App Store profiles using it.
    uuid = make_profile(PROFILE_NAME, bundle, cert["id"], out / "profile.mobileprovision")
    print(f"PROFILE_NAME={PROFILE_NAME}")
    print(f"PROFILE_UUID={uuid}")
    if widgets:
        widgets_uuid = make_profile(WIDGETS_PROFILE_NAME, widgets, cert["id"], out / "widgets.mobileprovision")
        print(f"WIDGETS_PROFILE_NAME={WIDGETS_PROFILE_NAME}")
        print(f"WIDGETS_PROFILE_UUID={widgets_uuid}")
    print(f"CERT_ID={cert['id']}")


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "prepare":
        prepare(sys.argv[2], sys.argv[3])
    else:
        sys.exit(__doc__)
