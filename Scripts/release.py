#!/usr/bin/env python3
"""Record/check a built artifact and make recoverable source-only snapshots."""
import argparse
import datetime
import hashlib
import json
import plistlib
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT/'Build/Release/Halo.app'
RECORD = ROOT/'Build/Release/build-manifest.json'

def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def sources():
    result = []
    for folder in ['Sources','Resources','Configuration','Scripts','Tests','Docs','Halo.xcodeproj']:
        result += [p for p in (ROOT/folder).rglob('*') if p.is_file() and not any(x in p.parts for x in ['__pycache__','xcuserdata']) and p.name != '.DS_Store']
    result += [ROOT/name for name in ['README.md','CHANGELOG.md','Makefile','AGENTS.md','.gitignore','LICENSE','SECURITY.md','CONTRIBUTING.md']]
    return sorted(result)
def source_hashes(): return {str(p.relative_to(ROOT)):digest(p) for p in sources()}
def app_hashes(): return {str(p.relative_to(APP)):digest(p) for p in sorted(APP.rglob('*')) if p.is_file()}
def verify_app():
    subprocess.run(['codesign','--verify','--deep','--strict',str(APP)],check=True)
    info = plistlib.loads((APP/'Contents/Info.plist').read_bytes())
    assert info['CFBundleIdentifier'] == 'com.maneesh.halo.production'
    binary = APP/'Contents/MacOS'/info['CFBundleExecutable']
    dependencies = subprocess.check_output(['otool','-L',str(binary)],text=True)
    assert all(x not in dependencies for x in ['HaloLatency','Reference/','Baseline/'])
    architectures = subprocess.check_output(['lipo','-archs',str(binary)],text=True).strip().split()
    assert set(architectures) == {'arm64','x86_64'}
    assert not (APP/'Contents/Resources/Working-Halo.mov').exists()
    assert (APP/'Contents/Resources/LICENSE').read_bytes() == (ROOT/'LICENSE').read_bytes()
    return info, architectures
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('command',choices=['record-build','check','snapshot'])
    command = parser.parse_args().command
    if command == 'snapshot':
        now = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        folder = ROOT/'Backups'; folder.mkdir(exist_ok=True)
        path = folder/f'Halo-source-{now}.zip'
        with zipfile.ZipFile(path,'x',compression=zipfile.ZIP_DEFLATED) as archive:
            for source in sources(): archive.write(source,'Halo/'+str(source.relative_to(ROOT)))
            archive.writestr('Halo/SOURCE-MANIFEST.json',json.dumps(source_hashes(),indent=2)+'\n')
        with zipfile.ZipFile(path) as archive: assert archive.testzip() is None
        print('Verified source-only snapshot:',path)
        return
    info, architectures = verify_app()
    if command == 'record-build':
        record = dict(created_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                      version=info['CFBundleShortVersionString'],build=info['CFBundleVersion'],
                      identity=info['CFBundleIdentifier'],architectures=architectures,
                      signing='ad-hoc; not a public distribution signature',
                      source_files=source_hashes(),app_files=app_hashes())
        RECORD.write_text(json.dumps(record,indent=2)+'\n')
        print('Verified universal app and recorded build provenance:',APP)
    else:
        record = json.loads(RECORD.read_text())
        assert record['source_files'] == source_hashes(), 'Source snapshot changed since make release; rebuild before testing.'
        assert record['app_files'] == app_hashes(), 'App contents changed since the recorded build.'
        print('PASS: signed app contents and complete source snapshot match the release record.')
if __name__ == '__main__': main()
