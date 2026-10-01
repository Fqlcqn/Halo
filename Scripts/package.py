#!/usr/bin/env python3
"""Create public artifacts from explicit source inputs, never private workspace data."""
import json
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path
from release import APP, ROOT, digest, sources, source_hashes
from deploy import hashes, verify_release

def main():
    record = verify_release()
    destination = ROOT / 'Dist'
    destination.mkdir(exist_ok=True)
    version = record['version']
    # Stage first, then replace artifacts only after archive/signature verification.
    with tempfile.TemporaryDirectory(prefix='halo-package-') as directory:
        stage = Path(directory)
        payload = stage / 'download'; payload.mkdir()
        subprocess.run(['ditto', str(APP), str(payload / 'Halo.app')], check=True)
        for name in ['LICENSE', 'README.md', 'SECURITY.md']:
            shutil.copy2(ROOT / name, payload / name)
        binary = stage / f'Halo-{version}-macOS.zip'
        subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', str(payload), str(binary)], check=True)
        extracted = stage / 'verified'
        subprocess.run(['ditto', '-x', '-k', str(binary), str(extracted)], check=True)
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(extracted / 'Halo.app')], check=True)
        assert hashes(extracted / 'Halo.app') == record['app_files']
        source = stage / f'Halo-{version}-source.zip'
        with zipfile.ZipFile(source, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            for path in sources(): archive.write(path, 'Halo/' + str(path.relative_to(ROOT)))
            archive.writestr('Halo/SOURCE-MANIFEST.json', json.dumps(source_hashes(), indent=2) + '\n')
        with zipfile.ZipFile(source) as archive:
            assert archive.testzip() is None
            assert not any(part in {'Reference', 'Backups', 'Deployments', '.git', 'Build'}
                           for name in archive.namelist() for part in name.split('/'))
        for archive in [binary, source]: shutil.copy2(archive, destination / archive.name)
        (destination / 'SHA256SUMS').write_text(''.join(f'{digest(p)}  {p.name}\n' for p in [binary, source]))
    print(f'Verified public app/source archives and SHA256SUMS: {destination}')

if __name__ == '__main__': main()
