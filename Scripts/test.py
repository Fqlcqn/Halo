#!/usr/bin/env python3
"""Harmless tests only: no live force quit, Trash, input injection, or app launch."""
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def run(*args, **kwargs): subprocess.run([str(a) for a in args], check=True, cwd=ROOT, **kwargs)
def main():
    with tempfile.TemporaryDirectory(prefix='halo-rebuild-tests-') as directory:
        tmp = Path(directory)
        clang = ['xcrun','clang','-fobjc-arc','-O2','-mmacosx-version-min=26.0','-I','Sources/Input','-I','Sources/Settings']
        run(*clang,'-framework','Foundation','Tests/HaloShortcutTests.m','Sources/Input/HaloShortcuts.m','-o',tmp/'shortcuts')
        run(tmp/'shortcuts',timeout=20)
        run(*clang,'-framework','AppKit','-framework','Carbon','-framework','ApplicationServices','-framework','QuartzCore',
            'Tests/HaloRuntimeTests.m','Sources/Input/HaloRuntime.m','Sources/Input/HaloShortcuts.m','Sources/Settings/HaloSettings.m','-o',tmp/'runtime')
        run(tmp/'runtime',timeout=20)
        run('xcrun','swiftc','-swift-version','6','-warnings-as-errors','Sources/Core/WheelGeometry.swift','Sources/Core/InteractionTiming.swift','Tests/GeometryTests.swift','-o',tmp/'geometry')
        run(tmp/'geometry',timeout=20)
        run('osacompile','-o',tmp/'EmptyTrash.scpt','Resources/EmptyTrash.applescript')
        run('osacompile','-o',tmp/'CloseFinderWindows.scpt','-e','tell application "Finder" to close every window')
        script = (ROOT/'Resources/EmptyTrash.applescript').read_text().replace('tell application "Finder"','set fakeWarning to true').replace('end tell','').replace('warns before emptying of trash','fakeWarning')
        for name,count,action,expected in [('empty',0,'error "must not execute" number -999','true'),('success',1,'set didRun to true','true'),('cancelled',1,'error "cancelled" number -128','false'),('denied',1,'error "not permitted" number -1743',None)]:
            simulated = script.replace('count of items of trash',str(count)).replace('        empty trash','        '+action)
            result = subprocess.run(['osascript','-e',simulated],text=True,capture_output=True,timeout=10)
            assert (result.returncode != 0 and '(-1743)' in result.stderr) if expected is None else result.returncode == 0 and result.stdout.strip() == expected, name
            print('PASS harmless Trash simulation:',name)
        for source in (ROOT/'Sources').rglob('*'):
            if source.is_file():
                text = source.read_text()
                assert '0x1000' not in text and 'dlsym(' not in text and 'mprotect(' not in text, f'Binary dependency: {source}'
        print('PASS no fixed-address hooks or binary patching in rebuilt sources')
if __name__ == '__main__': main()
