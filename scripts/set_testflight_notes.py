#!/usr/bin/env python3
"""
Pushes the "What to Test" notes (testflight-notes-<build>.txt) onto the
latest TestFlight build of Casalist via the App Store Connect API.

Usage:
    scripts/set_testflight_notes.py                  # uses latest notes file
    scripts/set_testflight_notes.py 4.0              # specific build/notes

Auth uses the same App Store Connect key configured for altool. PyJWT is
required (already installed system-wide); requests is NOT (we use urllib).
"""

from __future__ import annotations
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

import jwt

REPO = Path(__file__).resolve().parent.parent
KEY_ID = "RSZWNZ7YL3"
ISSUER_ID = "69a6de73-6a85-47e3-e053-5b8c7c11a4d1"
KEY_PATH = Path.home() / ".appstoreconnect" / "private_keys" / f"AuthKey_{KEY_ID}.p8"
BUNDLE_ID = "com.gbrown10.casalist"
API_BASE = "https://api.appstoreconnect.apple.com/v1"


def make_token() -> str:
    private_key = KEY_PATH.read_text()
    iat = datetime.now(timezone.utc)
    payload = {
        "iss": ISSUER_ID,
        "iat": int(iat.timestamp()),
        "exp": int((iat + timedelta(minutes=15)).timestamp()),
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(
        payload,
        private_key,
        algorithm="ES256",
        headers={"kid": KEY_ID, "typ": "JWT"},
    )


def api(method: str, path: str, *, token: str, body: dict | None = None) -> dict:
    url = path if path.startswith("http") else f"{API_BASE}{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    if body is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        sys.stderr.write(f"\nHTTP {e.code} on {method} {path}\n")
        sys.stderr.write(e.read().decode() + "\n")
        raise


def find_app(token: str) -> str:
    q = urllib.parse.urlencode({"filter[bundleId]": BUNDLE_ID, "limit": 1})
    r = api("GET", f"/apps?{q}", token=token)
    apps = r.get("data") or []
    if not apps:
        sys.exit(f"No app found for bundle id {BUNDLE_ID!r}")
    return apps[0]["id"]


def find_build(token: str, app_id: str, version: str | None) -> dict:
    """Returns the latest build, or a specific version if provided.

    NOTE: Apple's `filter[version]` does NOT always do exact string match —
    in particular "4.0" can match a stale "4" build that has since been
    superseded. So we fetch the recent list sorted by upload date and pick
    the first one whose version *exactly* matches the requested string.
    """
    params = {
        "filter[app]": app_id,
        "sort": "-uploadedDate",
        "limit": 20,
    }
    q = urllib.parse.urlencode(params)
    r = api("GET", f"/builds?{q}", token=token)
    builds = r.get("data") or []
    if not version:
        return builds[0] if builds else {}
    for b in builds:
        if (b.get("attributes") or {}).get("version") == version:
            return b
    return {}


def upsert_notes(token: str, build_id: str, notes: str) -> None:
    # Look for an existing en-US localization on this build.
    r = api("GET", f"/builds/{build_id}/betaBuildLocalizations", token=token)
    existing = None
    for loc in r.get("data", []):
        if loc.get("attributes", {}).get("locale") == "en-US":
            existing = loc
            break

    if existing:
        loc_id = existing["id"]
        api(
            "PATCH",
            f"/betaBuildLocalizations/{loc_id}",
            token=token,
            body={
                "data": {
                    "type": "betaBuildLocalizations",
                    "id": loc_id,
                    "attributes": {"whatsNew": notes},
                }
            },
        )
        print(f"✅ Updated existing en-US localization ({loc_id})")
    else:
        api(
            "POST",
            "/betaBuildLocalizations",
            token=token,
            body={
                "data": {
                    "type": "betaBuildLocalizations",
                    "attributes": {"locale": "en-US", "whatsNew": notes},
                    "relationships": {
                        "build": {"data": {"type": "builds", "id": build_id}}
                    },
                }
            },
        )
        print(f"✅ Created en-US localization for build {build_id}")


def main() -> None:
    # Two args: version (MARKETING_VERSION used to filter App Store Connect)
    # AND notes-suffix (filename testflight-notes-<suffix>.txt). They diverge
    # whenever MARKETING_VERSION != CURRENT_PROJECT_VERSION — e.g. version 1
    # build 1.1.
    #     scripts/set_testflight_notes.py                # newest notes file
    #     scripts/set_testflight_notes.py 1.0            # both = "1.0"
    #     scripts/set_testflight_notes.py 1 1.1          # filter version, notes file
    if len(sys.argv) >= 3:
        version = sys.argv[1]
        notes_suffix = sys.argv[2]
        notes_path = REPO / f"testflight-notes-{notes_suffix}.txt"
    elif len(sys.argv) == 2:
        version = sys.argv[1]
        notes_path = REPO / f"testflight-notes-{version}.txt"
        # If exact match doesn't exist, fall back to newest file by mtime.
        if not notes_path.exists():
            candidates = sorted(REPO.glob("testflight-notes-*.txt"),
                                key=lambda p: p.stat().st_mtime)
            if candidates:
                notes_path = candidates[-1]
                print(f"  (no testflight-notes-{version}.txt — falling back to {notes_path.name})")
    else:
        notes_files = sorted(REPO.glob("testflight-notes-*.txt"),
                             key=lambda p: p.stat().st_mtime)
        if not notes_files:
            sys.exit("No testflight-notes-*.txt files in repo")
        notes_path = notes_files[-1]
        version = notes_path.stem.replace("testflight-notes-", "")

    if not notes_path.exists():
        sys.exit(f"Missing {notes_path}")
    notes = notes_path.read_text().rstrip() + "\n"
    print(f"› Notes file: {notes_path.name} ({len(notes)} chars)")
    print(f"› Targeting build version: {version}")

    token = make_token()
    app_id = find_app(token)
    print(f"› App ID: {app_id}")

    # Build may still be processing immediately after upload. Retry a few
    # times so this works as a one-shot post-upload step.
    for attempt in range(1, 11):
        build = find_build(token, app_id, version)
        if build:
            break
        wait = 30
        print(f"  build {version} not visible yet (attempt {attempt}/10) — waiting {wait}s…")
        time.sleep(wait)
    else:
        sys.exit(f"Build {version} never appeared in App Store Connect.")

    build_id = build["id"]
    attrs = build.get("attributes", {})
    print(f"› Build {attrs.get('version')} (build {attrs.get('buildNumber')}) id={build_id}")
    print(f"  uploaded: {attrs.get('uploadedDate')}  state: {attrs.get('processingState')}")

    upsert_notes(token, build_id, notes)


if __name__ == "__main__":
    main()
