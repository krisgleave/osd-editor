#!/usr/bin/env python3
"""Package an ad-hoc signed Apple Silicon release; does not notarize or publish."""
from pathlib import Path
import hashlib,plistlib,shutil,struct,subprocess,tempfile,zipfile
ROOT=Path(__file__).resolve().parents[1];VERSION='1.0.1';BUILD='106';dist=ROOT/'dist';dist.mkdir(exist_ok=True)
binary=ROOT/'build/OSDEditor'
if not binary.exists():raise SystemExit('Run python3 scripts/build.py first.')
with tempfile.TemporaryDirectory(prefix='osd-editor-package-') as tmp:
 tmp=Path(tmp);icons=tmp/'AppIcon.iconset';icons.mkdir()
 for n in [16,32,128,256,512]:
  for retina in [False,True]:
   pixels=n*(2 if retina else 1);name=f'icon_{n}x{n}'+('@2x' if retina else '')+'.png'
   subprocess.run(['sips','-z',str(pixels),str(pixels),str(ROOT/'assets/AppIcon.png'),'--out',str(icons/name)],check=True,stdout=subprocess.DEVNULL)
 app=tmp/'OSD Editor.app';mac=app/'Contents/MacOS';res=app/'Contents/Resources';mac.mkdir(parents=True);res.mkdir()
 # Store full-bleed opaque PNG representations directly, as in P1 Transfer.
 # macOS supplies the rounded mask; transparent rounded artwork can get a backplate.
 mapping={'icp4':'icon_16x16.png','icp5':'icon_32x32.png','ic07':'icon_128x128.png','ic08':'icon_256x256.png','ic09':'icon_512x512.png','ic10':'icon_512x512@2x.png','ic11':'icon_16x16@2x.png','ic12':'icon_32x32@2x.png','ic13':'icon_128x128@2x.png','ic14':'icon_256x256@2x.png'}
 chunks=[]
 for tag,name in mapping.items():
  data=(icons/name).read_bytes();chunks.append(tag.encode('ascii')+struct.pack('>I',len(data)+8)+data)
 body=b''.join(chunks)
 (res/'OSDEditorIcon.icns').write_bytes(b'icns'+struct.pack('>I',len(body)+8)+body)
 shutil.copyfile(binary,mac/'OSDEditor');(mac/'OSDEditor').chmod(0o755)
 for name in ['LICENSE','THIRD_PARTY_NOTICES.md']:shutil.copyfile(ROOT/name,res/('LICENSE.txt' if name=='LICENSE' else 'THIRD_PARTY_NOTICES.txt'))
 info={'CFBundleExecutable':'OSDEditor','CFBundleIdentifier':'com.kristalkstech.osdeditor','CFBundleName':'OSD Editor','CFBundleDisplayName':'OSD Editor','CFBundlePackageType':'APPL','CFBundleShortVersionString':VERSION,'CFBundleVersion':BUILD,'CFBundleIconFile':'OSDEditorIcon','LSMinimumSystemVersion':'27.0','NSHighResolutionCapable':True,'NSHumanReadableCopyright':'Copyright © 2026 Kris Gleave (KrisTalksTech). GPL-3.0-or-later.'}
 (app/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
 subprocess.run(['codesign','--force','--sign','-',str(app)],check=True);subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
 zip_path=dist/f'OSD-Editor-{VERSION}-Mac.zip'
 with zipfile.ZipFile(zip_path,'w',zipfile.ZIP_DEFLATED) as z:
  for f in app.rglob('*'):
   if f.is_file():z.write(f,f.relative_to(tmp))
  for name in ['README.md','LICENSE','THIRD_PARTY_NOTICES.md']:z.write(ROOT/name,name)
  for f in (ROOT/'docs').glob('*.md'):z.write(f,'docs/'+f.name)
source=dist/f'OSD-Editor-{VERSION}-source.zip'
with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED) as z:
 for f in sorted(ROOT.rglob('*')):
  if not f.is_file():continue
  relative=f.relative_to(ROOT)
  if any(part in {'.git','build','dist','.DS_Store','__pycache__'} for part in relative.parts):continue
  z.write(f,Path(f'osd-editor-{VERSION}')/relative)
assets=[zip_path,source]
(dist/'SHA256SUMS.txt').write_text(''.join(hashlib.sha256(f.read_bytes()).hexdigest()+'  '+f.name+'\n' for f in assets))
print('\n'.join(str(f) for f in assets+[dist/'SHA256SUMS.txt']))
