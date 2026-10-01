#!/usr/bin/env python3
"""Install only the verified Halo build; preserve replaced copies for recovery."""
import argparse
import datetime
import hashlib
import json
import plistlib
import shutil
import subprocess
import tempfile
from pathlib import Path
from release import APP, RECORD, ROOT, digest, source_hashes

DESTINATION = Path('/Applications/Halo.app')
OLD_NAME = Path('/Applications/Halo Production.app')
IDENTITY = 'com.maneesh.halo.production'
BACKUPS = ROOT / 'Backups/Installed'
RECEIPTS = ROOT / 'Deployments'

def run(*args): subprocess.run(args, check=True)
def hashes(app):
    return {str(p.relative_to(app)): digest(p) for p in sorted(app.rglob('*')) if p.is_file()}
def identity(app):
    return plistlib.loads((app / 'Contents/Info.plist').read_bytes())['CFBundleIdentifier']
def verify_release():
    record = json.loads(RECORD.read_text())
    run('codesign', '--verify', '--deep', '--strict', str(APP))
    if identity(APP) != IDENTITY or record['app_files'] != hashes(APP):
        raise RuntimeError('Release app differs from its manifest; run make release.')
    if record['source_files'] != source_hashes():
        raise RuntimeError('Sources changed since release; run make release.')
    return record
def backup(app, stamp):
    # Resolve and validate the exact bundle before any recovery/removal operation.
    if app.is_symlink() or identity(app) not in {IDENTITY, 'com.maneesh.halo'}:
        raise RuntimeError(f'Refusing to replace an unfamiliar bundle: {app}')
    BACKUPS.mkdir(parents=True, exist_ok=True)
    target = BACKUPS / f'{app.stem}-previous-{stamp}.app'
    if target.exists(): raise RuntimeError(f'Backup already exists: {target}')
    run('ditto', str(app), str(target))
    if hashes(app) != hashes(target): raise RuntimeError('Backup verification failed.')
    return target
def install():
    record = verify_release()
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    previous_backup = backup(DESTINATION, stamp) if DESTINATION.exists() else None
    old_backup = backup(OLD_NAME, stamp) if OLD_NAME.exists() else None
    with tempfile.TemporaryDirectory(prefix='.halo-install-', dir='/Applications') as directory:
        stage = Path(directory) / 'Halo.app'
        previous = Path(directory) / 'Previous.app'
        run('ditto', str(APP), str(stage))
        run('codesign', '--verify', '--deep', '--strict', str(stage))
        if hashes(stage) != record['app_files']: raise RuntimeError('Staging verification failed.')
        if DESTINATION.exists(): DESTINATION.rename(previous)
        try:
            stage.rename(DESTINATION)
            run('codesign', '--verify', '--deep', '--strict', str(DESTINATION))
            if hashes(DESTINATION) != record['app_files']:
                raise RuntimeError('Installed files differ from release.')
        except Exception:
            if DESTINATION.exists(): DESTINATION.rename(Path(directory) / 'Failed.app')
            if previous.exists(): previous.rename(DESTINATION)
            raise
    # Only remove the superseded name after the new app and its backup verify.
    if old_backup:
        if hashes(OLD_NAME) != hashes(old_backup): raise RuntimeError('Old app changed during install; retained it.')
        shutil.rmtree(OLD_NAME)
    RECEIPTS.mkdir(exist_ok=True)
    receipt = RECEIPTS / f'{stamp}-halo.json'
    receipt.write_text(json.dumps(dict(
        destination=str(DESTINATION), version=record['version'], build=record['build'],
        release_manifest_sha256=digest(RECORD), app_files=record['app_files'],
        backups=[str(p) for p in [previous_backup, old_backup] if p]), indent=2) + '\n')
    print(f'Installed and verified: {DESTINATION}\nReceipt: {receipt}')
    for path in [previous_backup, old_backup]:
        if path: print(f'Recoverable previous app: {path}')
def status():
    record = verify_release()
    if not DESTINATION.is_dir() or identity(DESTINATION) != IDENTITY:
        raise RuntimeError('Halo is not installed. Run make install.')
    run('codesign', '--verify', '--deep', '--strict', str(DESTINATION))
    if hashes(DESTINATION) != record['app_files']: raise RuntimeError('Installed app is stale.')
    receipts = sorted(RECEIPTS.glob('*-halo.json'))
    if not receipts or json.loads(receipts[-1].read_text())['app_files'] != record['app_files']:
        raise RuntimeError('No matching installation receipt.')
    print(f'PASS: {DESTINATION} matches release {record["version"]} ({record["build"]}).')
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['install', 'status'])
    args = parser.parse_args()
    try: {'install': install, 'status': status}[args.command]()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(f'ERROR: {error}')
