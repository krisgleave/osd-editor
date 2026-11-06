#!/usr/bin/env python3
"""Build OSD Editor with macOS system frameworks. No third-party Python packages."""
from pathlib import Path
import argparse,subprocess,sys
p=argparse.ArgumentParser();p.add_argument('--tests',action='store_true');p.add_argument('--deployment-target',default='27.0');args=p.parse_args()
root=Path(__file__).resolve().parents[1];build=root/'build';build.mkdir(exist_ok=True)
files=sorted((root/'src').glob('*.swift'))
if args.tests:files=[f for f in files if f.name!='main.swift']+[root/'tests/main.swift']
binary=build/('OSDEditorTests' if args.tests else 'OSDEditor')
cmd=['xcrun','swiftc','-swift-version','5',('-Onone' if args.tests else '-O'),'-target',f'arm64-apple-macos{args.deployment_target}','-module-cache-path',str(build/'module-cache')]+[str(f) for f in files]+['-o',str(binary)]
for framework in ['Cocoa','AVFoundation','CoreImage','QuartzCore','CoreText']:cmd+=['-framework',framework]
log=build/('test-build.log' if args.tests else 'build.log')
with log.open('w') as stream:result=subprocess.run(cmd,stdout=stream,stderr=subprocess.STDOUT)
if result.returncode:print(log.read_text(),file=sys.stderr);sys.exit(result.returncode)
print(binary)
