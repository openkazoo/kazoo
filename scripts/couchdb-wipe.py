#!/usr/bin/env python3
"""Delete every CouchDB database except the System DBs.

    scripts/couchdb-wipe.py

Resets a long-lived test CouchDB to empty so Kazoo can be bootstrapped from
scratch afterwards with SUP (`kapps_maintenance refresh`, master account --
see scripts/dev-init.sh). This script only deletes; booting a node and the SUP
bootstrap are the caller's next steps:

    stop Kazoo -> couchdb-wipe.py -> boot Kazoo -> SUP bootstrap

There is NO confirmation. Running it wipes whatever CouchDB it resolves to.

Precondition (not checked): every Kazoo node using this CouchDB is stopped. A
running node keeps serving cached documents and its change feeds can re-create
databases mid-wipe.

System DBs (`_users`, `_replicator`, `_global_changes` -- anything `_`-prefixed)
are kept: CouchDB needs them and Kazoo does not own them.

Target, first match wins:
  COUCHDB_URL    e.g. http://admin:password@couch.test:5984
  [couchdb3] in $KAZOO_CONFIG, else /etc/kazoo/config.ini (ip, port,
                 username, password) -- the same CouchDB Kazoo itself uses.

Every database is attempted even if some fail; failures are listed at the end
and the exit status is 1. Standard library only.
"""

import base64
import configparser
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_CONFIG = "/etc/kazoo/core/config.ini"
TIMEOUT = 60  # seconds per request; deleting a big Account DB is not instant


def die(msg):
    print(f"couchdb-wipe: {msg}", file=sys.stderr)
    sys.exit(1)


def unquote_ini(value):
    # Kazoo's ini quotes some values (ip = "127.0.0.1"); configparser keeps them.
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def target_from_url(url):
    """Split credentials out of the URL: urllib does not send userinfo itself."""
    parts = urllib.parse.urlsplit(url)
    if not parts.scheme or not parts.hostname:
        die(f"COUCHDB_URL is not an absolute URL: {url!r}")
    user = urllib.parse.unquote(parts.username) if parts.username else None
    password = urllib.parse.unquote(parts.password) if parts.password else ""
    netloc = parts.hostname if ":" not in parts.hostname else f"[{parts.hostname}]"
    if parts.port:
        netloc += f":{parts.port}"
    base = urllib.parse.urlunsplit((parts.scheme, netloc, parts.path.rstrip("/"), "", ""))
    return base, user, password


def target_from_config(path):
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        with open(path, encoding="utf-8") as fh:
            parser.read_file(fh)
    except OSError as err:
        die(f"cannot read {path}: {err.strerror} (set KAZOO_CONFIG or COUCHDB_URL)")
    if not parser.has_section("couchdb3"):
        die(f"no [couchdb3] section in {path} (set COUCHDB_URL to override)")
    sec = parser["couchdb3"]
    host = unquote_ini(sec.get("ip", "127.0.0.1"))
    port = unquote_ini(sec.get("port", "5984"))
    user = unquote_ini(sec["username"]) if "username" in sec else None
    password = unquote_ini(sec.get("password", ""))
    return f"http://{host}:{port}", user, password


def resolve_target():
    url = os.environ.get("COUCHDB_URL")
    if url:
        return target_from_url(url)
    return target_from_config(os.environ.get("KAZOO_CONFIG") or DEFAULT_CONFIG)


class Couch:
    def __init__(self, base, user, password):
        self.base = base
        self.headers = {"Accept": "application/json"}
        if user is not None:
            token = base64.b64encode(f"{user}:{password}".encode()).decode()
            self.headers["Authorization"] = f"Basic {token}"

    def request(self, method, path):
        req = urllib.request.Request(self.base + path, method=method, headers=self.headers)
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            return json.load(resp)


def describe(err):
    if isinstance(err, urllib.error.HTTPError):
        body = err.read().decode(errors="replace").strip()
        return f"HTTP {err.code} {body}"
    if isinstance(err, urllib.error.URLError):
        return str(err.reason)
    return str(err)


def main(argv):
    if len(argv) > 1:
        if argv[1] in ("-h", "--help"):
            print(__doc__.strip())
            return 0
        die(f"takes no arguments (got {' '.join(argv[1:])!r}); see --help")

    # Piped (CI logs), stdout is block-buffered and would land after stderr.
    sys.stdout.reconfigure(line_buffering=True)

    couch = Couch(*resolve_target())
    print(f"couchdb-wipe: target {couch.base}")

    try:
        dbs = couch.request("GET", "/_all_dbs")
    except Exception as err:  # noqa: BLE001 -- any failure here is fatal
        die(f"cannot list databases at {couch.base}: {describe(err)}")

    doomed = [db for db in dbs if not db.startswith("_")]
    kept = len(dbs) - len(doomed)
    print(f"couchdb-wipe: deleting {len(doomed)} database(s), keeping {kept} System DB(s)")

    failures = []
    for db in doomed:
        # Account DBs look like account/ab/cd/... -- the slashes must be encoded.
        try:
            couch.request("DELETE", "/" + urllib.parse.quote(db, safe=""))
            print(f"deleted {db}")
        except Exception as err:  # noqa: BLE001 -- keep going, report at the end
            failures.append((db, describe(err)))
            print(f"FAILED  {db}: {failures[-1][1]}", file=sys.stderr)

    if failures:
        print(f"couchdb-wipe: {len(failures)} of {len(doomed)} deletion(s) failed:", file=sys.stderr)
        for db, why in failures:
            print(f"  {db}: {why}", file=sys.stderr)
        return 1

    print(f"couchdb-wipe: done, {len(doomed)} database(s) deleted")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
