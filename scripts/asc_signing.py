#!/usr/bin/env python3
"""App Store signing for the TestFlight workflow, through the App Store
Connect API (no Mac, no registered devices).

    asc_signing.py prepare <csr.pem> <out_dir>
        Revokes older distribution certificates (keeping the newest one, so
        the last build can finish processing), creates a new one from the
        CSR, and makes a fresh App Store provisioning profile with it.
        Writes <out_dir>/distribution.cer, <out_dir>/profile.mobileprovision
        and prints PROFILE_NAME / PROFILE_UUID / CERT_ID lines for $GITHUB_ENV.

Needs ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH and BUNDLE_ID in the
environment, and the PyJWT + cryptography packages.
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
        with urllib.request.urlopen(request) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")
        sys.exit(f"App Store Connect said {error.code} to {method} {path}:\n{detail}")


def prepare(csr_path, out_dir):
    out = pathlib.Path(out_dir)
    bundle_id = os.environ["BUNDLE_ID"]

    # 1. The app's bundle ID record (made in the developer portal).
    found = call("GET", f"/bundleIds?filter[identifier]={bundle_id}&limit=50")["data"]
    matches = [b for b in found if b["attributes"]["identifier"] == bundle_id]
    if not matches:
        sys.exit(f"No App ID for {bundle_id}. Create it in Certificates, Identifiers & Profiles (docs/SETUP.md step 3).")
    bundle = matches[0]["id"]

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

    # 4. A fresh App Store profile using it (old ones with this name go).
    for profile in call("GET", f"/profiles?filter[name]={urllib.parse.quote(PROFILE_NAME)}&limit=50")["data"]:
        call("DELETE", f"/profiles/{profile['id']}")
    profile = call("POST", "/profiles", {
        "data": {
            "type": "profiles",
            "attributes": {"name": PROFILE_NAME, "profileType": "IOS_APP_STORE"},
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": bundle}},
                "certificates": {"data": [{"type": "certificates", "id": cert["id"]}]},
            },
        }
    })["data"]
    (out / "profile.mobileprovision").write_bytes(base64.b64decode(profile["attributes"]["profileContent"]))

    print(f"PROFILE_NAME={PROFILE_NAME}")
    print(f"PROFILE_UUID={profile['attributes']['uuid']}")
    print(f"CERT_ID={cert['id']}")


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "prepare":
        prepare(sys.argv[2], sys.argv[3])
    else:
        sys.exit(__doc__)
