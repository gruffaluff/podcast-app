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
PEM) and optionally CLOUDKIT_ENV (development by default).
"""
import base64
import datetime as dt
import email.utils
import hashlib
import json
import os
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec

CONTAINER = "iCloud.com.gruffaluff.podcasts"
ENVIRONMENT = os.environ.get("CLOUDKIT_ENV", "development")
KEY_ID = os.environ["CLOUDKIT_KEY_ID"]
KEY = serialization.load_pem_private_key(open(os.environ["CLOUDKIT_KEY_PATH"], "rb").read(), password=None)
BASE = "https://api.apple-cloudkit.com"
FRESH_FOR = dt.timedelta(days=2)
USER_AGENT = "Poddeck-alerts/1.0 (personal podcast app)"


def cloudkit(operation, body):
    """Signed CloudKit Web Services call on the public database."""
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
        sys.exit(f"CloudKit {operation} failed ({error.code}): {error.read().decode(errors='replace')[:500]}")


def lookup(record_name):
    result = cloudkit("records/lookup", {"records": [{"recordName": record_name}]})
    record = (result.get("records") or [{}])[0]
    return None if "serverErrorCode" in record else record


def field(record, name, default):
    return (record or {}).get("fields", {}).get(name, {}).get("value", default)


def fetch_feed(url):
    """(show title, [(guid, title, published)]) or None if it can't be read."""
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            root = ET.fromstring(response.read())
    except Exception as error:  # noqa: BLE001 - one bad feed shouldn't stop the rest
        print(f"  skipped {url}: {error}")
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


def main():
    follows = lookup("follows")
    feeds = field(follows, "feeds", [])
    alert_feeds = set(field(follows, "alertFeeds", []))
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
        known = set(seen.get(url, []))
        first_look = url not in seen
        for guid, title, published in items:
            if guid in known or first_look:
                continue
            if published is None or now - published > FRESH_FOR:
                continue
            kind = "PoddeckAlertEpisode" if url in alert_feeds else "PoddeckQuietEpisode"
            print(f"  new: {show} - {title} ({kind})")
            new_records.append({"operationType": "create", "record": {"recordType": kind, "fields": {
                "feedURL": {"value": url},
                "showTitle": {"value": show or "A show you follow"},
                "episodeTitle": {"value": title or "New episode"},
                "guid": {"value": guid},
            }}})
        # Remember the newest 300 per feed.
        seen[url] = [guid for guid, _, _ in items[:300]]

    # Forget unfollowed shows.
    seen = {url: guids for url, guids in seen.items() if url in feeds}

    operations = new_records + [{"operationType": "forceReplace", "record": {
        "recordName": "alert-state", "recordType": "PoddeckAlertState",
        "fields": {"json": {"value": json.dumps(seen)}},
    }}]
    # First run: create one record of each kind so the app can subscribe.
    if state_record is None:
        for kind in ("PoddeckAlertEpisode", "PoddeckQuietEpisode"):
            operations.append({"operationType": "forceReplace", "record": {
                "recordName": f"setup-{kind}", "recordType": kind,
                "fields": {"feedURL": {"value": ""}, "showTitle": {"value": ""},
                           "episodeTitle": {"value": ""}, "guid": {"value": "setup"}},
            }})
    result = cloudkit("records/modify", {"operations": operations})
    failed = [r for r in result.get("records", []) if "serverErrorCode" in r]
    for record in failed:
        print(f"  CloudKit refused a record: {record.get('serverErrorCode')} {record.get('reason', '')}")
    print(f"Checked {len(feeds)} shows; {len(new_records)} new episode(s).")
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
