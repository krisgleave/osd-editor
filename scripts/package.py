#!/usr/bin/env python3
"""Package an ad-hoc signed Apple Silicon release; does not notarize or publish."""
from pathlib import Path
import hashlib,plistlib,shutil,subprocess,tempfile,zipfile
ROOT=Path(__file__).resolve().parents[1];VERSION='1.0';BUILD='104';dist=ROOT/'dist';dist.mkdir(exist_ok=True)
binary=ROOT/'build/OSDEditor'
if not binary.exists():raise SystemExit('Run python3 scripts/build.py first.')
with tempfile.TemporaryDirectory(prefix='osd-editor-package-') as tmp:
 tmp=Path(tmp);icons=tmp/'AppIcon.iconset';icons.mkdir()
 for n in [16,32,128,256,512]:
  for retina in [False,True]:
   pixels=n*(2 if retina else 1);name=f'icon_{n}x{n}'+('@2x' if retina else '')+'.png'
   subprocess.run(['sips','-z',str(pixels),str(pixels),str(ROOT/'assets/AppIcon.png'),'--out',str(icons/name)],check=True,stdout=subprocess.DEVNULL)
 app=tmp/'OSD Editor.app';mac=app/'Contents/MacOS';res=app/'Contents/Resources';mac.mkdir(parents=True);res.mkdir()
 subprocess.run(['iconutil','-c','icns',str(icons),'-o',str(res/'AppIcon.icns')],check=True)
 shutil.copyfile(binary,mac/'OSDEditor');(mac/'OSDEditor').chmod(0o755)
 for name in ['LICENSE','THIRD_PARTY_NOTICES.md']:shutil.copyfile(ROOT/name,res/('LICENSE.txt' if name=='LICENSE' else 'THIRD_PARTY_NOTICES.txt'))
 info={'CFBundleExecutable':'OSDEditor','CFBundleIdentifier':'com.kristalkstech.osdeditor','CFBundleName':'OSD Editor','CFBundleDisplayName':'OSD Editor','CFBundlePackageType':'APPL','CFBundleShortVersionString':VERSION,'CFBundleVersion':BUILD,'CFBundleIconFile':'AppIcon','LSMinimumSystemVersion':'27.0','NSHighResolutionCapable':True,'NSHumanReadableCopyright':'Copyright © 2026 Kris Gleave (KrisTalksTech). GPL-3.0-or-later.'}
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
