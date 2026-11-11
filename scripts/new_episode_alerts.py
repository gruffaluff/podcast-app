#!/usr/bin/env python3
"""New-episode alerts for Poddeck, run every ~15 minutes by GitHub Actions
(.github/workflows/alerts.yml). Free: GitHub's Linux machines for a public
repository, and Poddeck's own iCloud (CloudKit) public database.

1. Reads which shows Paul follows from the record the app keeps in the
   public database ("PoddeckFollows" / "follows").
2. Fetches each feed and compares it with what it saw last time (kept in a
   "PoddeckAlertState" record), so nothing is announced twice.
3. For each new episode (published in the last 2 days), saves a record:
   "PoddeckAlertEpisode" for shows with the bell on (iCloud shows an alert),
   "PoddeckQuietEpisode" for the rest (a silent push that updates Up Next).

Needs CLOUDKIT_KEY_ID, CLOUDKIT_KEY_PATH (the server-to-server private key,
PEM) and optionally CLOUDKIT_ENV (production by default; TestFlight
builds use Production).
"""
import base64
import datetime as dt
import email.utils
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

CONTAINER = "iCloud.com.gruffaluff.podcasts"
ENVIRONMENT = os.environ.get("CLOUDKIT_ENV", "production")
KEY_ID = os.environ["CLOUDKIT_KEY_ID"]
KEY = serialization.load_pem_private_key(open(os.environ["CLOUDKIT_KEY_PATH"], "rb").read(), password=None)
BASE = "https://api.apple-cloudkit.com"
FRESH_FOR = dt.timedelta(days=2)
USER_AGENT = "Poddeck-alerts/1.0 (personal podcast app)"


# Apple's side sometimes refuses a call for a few minutes and then recovers
# (11 Nov 2026: "UNKNOWN_CONTAINER ... Invalid container to get container key"
# for two runs, fine before and after). These answers mean nothing was done,
# so the call is safe to send again.
PASSING_TROUBLE = ("UNKNOWN_CONTAINER", "SERVICE_UNAVAILABLE", "THROTTLED", "TRY_AGAIN_LATER", "INTERNAL_ERROR")
RETRY_WAITS = (20, 60, 120)


def cloudkit(operation, body):
    """Signed CloudKit Web Services call on the public database. Waits and
    tries again (up to 3 more times, about 3½ minutes) when Apple's side is
    briefly unavailable; fails the run only if it stays that way."""
    for attempt, wait in enumerate((0,) + RETRY_WAITS):
        if wait:
            print(f"  CloudKit {operation}: Apple's side unavailable, trying again in {wait}s")
            time.sleep(wait)
        outcome = _cloudkit_once(operation, body, last=attempt == len(RETRY_WAITS))
        if outcome is not None:
            return outcome


def _cloudkit_once(operation, body, last):
    """The result, or None to try again. Ends the run on a real error."""
    subpath = f"/database/1/{CONTAINER}/{ENVIRONMENT}/public/{operation}"
    data = json.dumps(body).encode()
    date = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    payload = f"{date}:{base64.b64encode(hashlib.sha256(data).digest()).decode()}:{subpath}"
    signature = base64.b64encode(KEY.sign(payload.encode(), ec.ECDSA(hashes.SHA256()))).decode()
    request = urllib.request.Request(BASE + subpath, data=data, method="POST", headers={
        "Content-Type": "application/json",
        "X-Apple-CloudKit-Request-KeyID": KEY_ID,
        "X-Apple-CloudKit-Request-ISO8601Date": date,
        "X-Apple-CloudKit-Request-SignatureV1": signature,
    })
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as error:
        text = error.read().decode(errors="replace")[:500]
        passing = error.code == 429 or error.code >= 500 or any(code in text for code in PASSING_TROUBLE)
        if passing and not last:
            return None
        sys.exit(f"CloudKit {operation} failed ({error.code}): {text}")
    except (urllib.error.URLError, TimeoutError) as error:
        # No answer at all: a save might have gone through, so only reads
        # are sent again (a repeated save could send an alert twice).
        if operation.endswith("lookup") and not last:
            return None
        sys.exit(f"CloudKit {operation} failed: {error}")


def lookup(record_name):
    result = cloudkit("records/lookup", {"records": [{"recordName": record_name}]})
    record = (result.get("records") or [{}])[0]
    if "serverErrorCode" in record:
        if record["serverErrorCode"] != "NOT_FOUND":
            print(f"  lookup {record_name}: {record['serverErrorCode']} {record.get('reason', '')}")
        return None
    return record


def field(record, name, default):
    return (record or {}).get("fields", {}).get(name, {}).get("value", default)


def fetch_feed(url):
    """(show title, [(guid, title, published)]) or None if it can't be read."""
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            root = ET.fromstring(response.read())
    except Exception as error:  # noqa: BLE001 - one bad feed shouldn't stop the rest
        # The repo is public, so its logs are too: never print feed links
        # (subscriber feeds carry a private key in the link) or titles.
        host = urllib.parse.urlsplit(url).hostname or "?"
        code = getattr(error, "code", None) or type(error).__name__
        print(f"  skipped a feed on {host} ({code})")
        return None
    channel = root.find("channel")
    if channel is None:
        return None
    show = (channel.findtext("title") or "").strip()
    items = []
    for item in channel.findall("item"):
        guid = (item.findtext("guid") or item.findtext("link") or "").strip()
        enclosure = item.find("enclosure")
        if not guid and enclosure is not None:
            guid = enclosure.get("url", "")
        if not guid:
            continue
        published = None
        if item.findtext("pubDate"):
            try:
                published = email.utils.parsedate_to_datetime(item.findtext("pubDate"))
                if published.tzinfo is None:
                    published = published.replace(tzinfo=dt.timezone.utc)
            except (TypeError, ValueError):
                published = None
        items.append((guid, (item.findtext("title") or "").strip(), published))
    return show, items


def tag(text):
    """A short one-way fingerprint, so saved state never holds feed links."""
    return hashlib.sha256(text.encode()).hexdigest()[:20]


def followed_feeds(record):
    """The app seals the list of followed shows to this job's key (records in
    the public database can be read by anyone using the app; subscriber feed
    links carry a private key). "feeds" holds ["sealed-v1", ephemeral public
    key, AES-GCM box], all base64. Returns (feeds, alert feeds)."""
    sealed = field(record, "feeds", [])
    if len(sealed) != 3 or sealed[0] != "sealed-v1":
        return [], set()
    peer = ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), base64.b64decode(sealed[1]))
    shared = KEY.exchange(ec.ECDH(), peer)
    key = HKDF(algorithm=hashes.SHA256(), length=32, salt=None, info=b"poddeck-follows").derive(shared)
    box = base64.b64decode(sealed[2])
    data = json.loads(AESGCM(key).decrypt(box[:12], box[12:], None))
    return data.get("feeds", []), set(data.get("alertFeeds", []))


def main():
    follows = lookup("follows")
    feeds, alert_feeds = followed_feeds(follows)
    if not feeds:
        print("No followed shows published yet (the app saves them after its next feed check).")
    state_record = lookup("alert-state")
    seen = json.loads(field(state_record, "json", "{}"))
    now = dt.datetime.now(dt.timezone.utc)
    new_records = []

    for url in feeds:
        result = fetch_feed(url)
        if result is None:
            continue
        show, items = result
        key = tag(url)
        known = set(seen.get(key, []))
        first_look = key not in seen
        for guid, title, published in items:
            if tag(guid) in known or first_look:
                continue
            if published is None or now - published > FRESH_FOR:
                continue
            kind = "PoddeckAlertEpisode" if url in alert_feeds else "PoddeckQuietEpisode"
            new_records.append({"operationType": "create", "record": {"recordType": kind, "fields": {
                "feedURL": {"value": key},
                "showTitle": {"value": show or "A show you follow"},
                "episodeTitle": {"value": title or "New episode"},
                "guid": {"value": tag(guid)},
            }}})
        # Remember the newest 300 per feed.
        seen[key] = [tag(guid) for guid, _, _ in items[:300]]

    # Forget unfollowed shows.
    followed = {tag(url) for url in feeds}
    seen = {key: guids for key, guids in seen.items() if key in followed}

    operations = new_records + [{"operationType": "forceReplace", "record": {
        "recordName": "alert-state", "recordType": "PoddeckAlertState",
        "fields": {"json": {"value": json.dumps(seen)}},
    }}]
    result = cloudkit("records/modify", {"operations": operations})
    failed = [r for r in result.get("records", []) if "serverErrorCode" in r]
    for record in failed:
        print(f"  CloudKit refused a record: {record.get('serverErrorCode')} {record.get('reason', '')}")
    alerts = sum(1 for r in new_records if r["record"]["recordType"] == "PoddeckAlertEpisode")
    print(f"Checked {len(feeds)} shows; {len(new_records)} new episode(s), {alerts} with an alert.")
    if failed and all("record_type" in r.get("reason", "") for r in failed):
        # The app creates the record types the first time a new build runs.
        print("Waiting for the app to set up its iCloud records (open Poddeck once on the new build).")
    elif failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
