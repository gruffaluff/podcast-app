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
        with urllib.request.urlopen(request, timeout=30) as response:
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

print("== Build TestFlight states")
details = get(f"/builds?filter[app]={app_id}&limit=10&sort=-uploadedDate&include=buildBetaDetail")
for item in details.get("included", []):
    if item["type"] == "buildBetaDetails":
        print(json.dumps({"id": item["id"], **{k: item["attributes"].get(k) for k in ("internalBuildState", "externalBuildState", "autoNotifyEnabled")}}))
for build in details.get("data", []):
    print(build["attributes"].get("version"), "encryption:", build["attributes"].get("usesNonExemptEncryption"))

print("== Beta groups and testers")
groups = get(f"/apps/{app_id}/betaGroups")
for group in groups.get("data", []):
    a = group["attributes"]
    testers = get(f"/betaGroups/{group['id']}/betaTesters")
    print(json.dumps({"name": a.get("name"), "internal": a.get("isInternalGroup"), "allBuilds": a.get("hasAccessToAllBuilds"), "testers": len(testers.get("data", []))}))
if not groups.get("data"):
    print("(no tester groups yet)")

print("== Distribution certificates")
certs = get("/certificates?filter[certificateType]=DISTRIBUTION,IOS_DISTRIBUTION&limit=50")
for cert in certs.get("data", []):
    a = cert["attributes"]
    print(json.dumps({"id": cert["id"], "name": a.get("name"), "type": a.get("certificateType"), "expires": a.get("expirationDate")}))

print("== App IDs and their capabilities")
for identifier in (bundle_id, bundle_id + ".widgets"):
    found = [b for b in get(f"/bundleIds?filter[identifier]={urllib.parse.quote(identifier)}&limit=20").get("data", [])
             if b["attributes"]["identifier"] == identifier]
    if not found:
        print(f"{identifier}: MISSING")
        continue
    caps = get(f"/bundleIds/{found[0]['id']}/bundleIdCapabilities").get("data", [])
    print(f"{identifier}: " + ", ".join(sorted(c["attributes"].get("capabilityType", "?") for c in caps)))
