#!/usr/bin/env python3
"""
Приводит папку mods сервера к сборке Aura-Pack на GitHub.

На сервере остаются:
  * моды из manifest.json, кроме клиентских (environment=client в fabric.mod.json
    или имя из clientOnly в server-mods.json);
  * чисто серверные моды из serverOnly (их нет в сборке, скрипт их не трогает).
Всё остальное переносится в бэкап (не удаляется). Недостающие и изменённые
моды скачиваются с GitHub и проверяются по SHA-256.

  python3 sync-server-mods.py --mods ~/aura-template/mods            # применить
  python3 sync-server-mods.py --mods ~/aura-template/mods --dry-run  # только показать
"""
import argparse
import fnmatch
import hashlib
import json
import os
import shutil
import sys
import time
import urllib.parse
import urllib.request
import zipfile

REPO = "qutlawsoasis-debug/Aura-Pack"
BRANCH = "main"
RAW = f"https://raw.githubusercontent.com/{REPO}/{BRANCH}"


def fetch(path, timeout=60):
    url = f"{RAW}/{'/'.join(urllib.parse.quote(s, safe='') for s in path.split('/'))}?t={int(time.time())}"
    req = urllib.request.Request(url, headers={"User-Agent": "AuraServerSync", "Cache-Control": "no-cache"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def environment(jar_path):
    try:
        with zipfile.ZipFile(jar_path) as z:
            meta = json.loads(z.read("fabric.mod.json").decode("utf-8", "replace"), strict=False)
            return str(meta.get("environment", "*"))
    except Exception:
        return "*"


def matches(name, patterns):
    return any(fnmatch.fnmatch(name.lower(), p.lower()) for p in patterns)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mods", default=os.path.expanduser("~/aura-template/mods"))
    ap.add_argument("--cache", default=os.path.expanduser("~/aura-template/.pack-cache"))
    ap.add_argument("--backup-root", default=os.path.expanduser("~/backups"))
    ap.add_argument("--rules", help="локальный server-mods.json вместо версии с GitHub")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    manifest = json.loads(fetch("manifest.json"))
    if args.rules:
        with open(args.rules, encoding="utf-8") as f:
            rules = json.load(f)
    else:
        rules = json.loads(fetch("server-mods.json"))
    client_only, server_only = rules.get("clientOnly", []), rules.get("serverOnly", [])
    print(f"[sync] pack {manifest.get('packVersion')} (MC {manifest.get('minecraft')})")

    os.makedirs(args.cache, exist_ok=True)
    desired = {}  # имя jar -> sha256
    skipped_client = []
    for f in manifest["files"]:
        p = f["path"]
        if not (p.startswith("mods/") and p.endswith(".jar") and p.count("/") == 1):
            continue
        name, sha = p[5:], f["sha256"]
        if matches(name, client_only):
            skipped_client.append(name)
            continue
        cached = os.path.join(args.cache, f"{sha}.jar")
        if not os.path.exists(cached):
            data = fetch(p, timeout=300)
            if hashlib.sha256(data).hexdigest() != sha:
                sys.exit(f"[sync] SHA-256 mismatch while downloading {name}, aborting")
            with open(cached + ".part", "wb") as out:
                out.write(data)
            os.replace(cached + ".part", cached)
        if environment(cached) == "client":
            skipped_client.append(name)
            continue
        desired[name] = sha

    present = {n: sha256_file(os.path.join(args.mods, n))
               for n in os.listdir(args.mods) if n.endswith(".jar")}

    to_remove = sorted(n for n, h in present.items()
                       if not matches(n, server_only) and desired.get(n) != h)
    to_add = sorted(n for n, h in desired.items() if present.get(n) != h)
    kept_server_only = sorted(n for n in present if matches(n, server_only))

    print(f"[sync] desired {len(desired)}, client-only skipped {len(skipped_client)}, server-only kept {len(kept_server_only)}")
    for n in to_remove:
        print(f"  - {n}")
    for n in to_add:
        print(f"  + {n}")
    if not to_remove and not to_add:
        print("[sync] already in sync")
        return

    if args.dry_run:
        print("[sync] dry run, nothing changed")
        return

    if to_remove:
        backup = os.path.join(args.backup_root, time.strftime("mods-%Y%m%d-%H%M%S"))
        os.makedirs(backup, exist_ok=True)
        for n in to_remove:
            shutil.move(os.path.join(args.mods, n), os.path.join(backup, n))
        print(f"[sync] moved {len(to_remove)} jar(s) to {backup}")

    for n in to_add:
        tmp = os.path.join(args.mods, n + ".part")
        shutil.copyfile(os.path.join(args.cache, f"{desired[n]}.jar"), tmp)
        os.replace(tmp, os.path.join(args.mods, n))
    print(f"[sync] installed {len(to_add)} jar(s)")


if __name__ == "__main__":
    main()
