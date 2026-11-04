#!/usr/bin/env python3
"""Prints what App Store Connect knows about Poddeck's uploads and builds:
processing state, and any errors Apple found while processing an upload.

Needs ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH and BUNDLE_ID in the
environment, and PyJWT + cryptography.
"""
import json
import os
import sys
import urllib.error
import urllib.parse

sys.path.insert(0, os.path.dirname(__file__))
from asc_signing import API, token  # noqa: E402
import urllib.request  # noqa: E402


def get(path):
    request = urllib.request.Request(API + path, headers={"Authorization": f"Bearer {token()}"})
    try:
        with urllib.request.urlopen(request) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as error:
        return {"error": error.code, "detail": error.read().decode(errors="replace")[:800]}


bundle_id = os.environ["BUNDLE_ID"]
apps = get(f"/apps?filter[bundleId]={urllib.parse.quote(bundle_id)}")
print("== Apps")
print(json.dumps([{**a["attributes"], "id": a["id"]} for a in apps.get("data", [])], indent=1) if "data" in apps else apps)
if not apps.get("data"):
    sys.exit(0)
app_id = apps["data"][0]["id"]

print("== Build uploads (newest first)")
uploads = get(f"/apps/{app_id}/buildUploads?limit=10")
if "data" in uploads:
    for upload in uploads["data"]:
        print(json.dumps({"id": upload["id"], **upload["attributes"]}, indent=1))
else:
    print(uploads)

print("== Builds")
builds = get(f"/builds?filter[app]={app_id}&limit=10&sort=-uploadedDate")
if "data" in builds:
    for build in builds["data"]:
        a = build["attributes"]
        print(json.dumps({k: a.get(k) for k in ("version", "uploadedDate", "processingState", "expired", "minOsVersion", "usesNonExemptEncryption")}))
    if not builds["data"]:
        print("(none)")
else:
    print(builds)
