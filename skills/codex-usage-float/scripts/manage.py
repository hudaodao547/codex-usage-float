#!/usr/bin/env python3
"""Build and install Codex Usage Float without downloading dependencies."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import shutil
import subprocess
import sys

SKILL = Path(__file__).resolve().parent.parent
NAME = 'Codex用量悬浮窗.app'
BUNDLE_ID = 'io.github.codex-usage-float'
VERSION = '0.1.0'

def run(args):
    subprocess.run([str(a) for a in args], check=True)

def build(output, universal):
    if platform.system() != 'Darwin':
        raise RuntimeError('此应用仅支持 macOS。')
    if not shutil.which('swiftc'):
        raise RuntimeError('请先安装 Apple Command Line Tools（xcode-select --install）。')
    output = output.expanduser().resolve()
    app = output / NAME
    contents = app / 'Contents'
    binary = contents / 'MacOS' / 'UsageFloat'
    binary.parent.mkdir(parents=True, exist_ok=True)
    cache = output / '.module-cache'
    arches = ['arm64', 'x86_64'] if universal else [platform.machine()]
    if any(a not in ('arm64','x86_64') for a in arches):
        raise RuntimeError('仅支持 Apple Silicon 和 Intel Mac。')
    parts = []
    for arch in arches:
        part = output / ('UsageFloat-' + arch)
        run(['swiftc', SKILL/'assets/UsageFloat.swift', '-target', arch+'-apple-macosx13.0',
             '-o', part, '-framework', 'Cocoa', '-module-cache-path', cache])
        parts.append(part)
    if len(parts) == 2:
        run(['lipo','-create',*parts,'-output',binary])
    else:
        shutil.copy2(parts[0],binary)
    info = {'CFBundleName':'Codex用量悬浮窗','CFBundleDisplayName':'Codex用量悬浮窗',
            'CFBundleIdentifier':BUNDLE_ID,'CFBundleExecutable':'UsageFloat',
            'CFBundlePackageType':'APPL','CFBundleShortVersionString':VERSION,
            'CFBundleVersion':'1','LSMinimumSystemVersion':'13.0','LSUIElement':True,
            'NSHighResolutionCapable':True}
    (contents/'Info.plist').write_bytes(plistlib.dumps(info))
    run(['codesign','--force','--sign','-',app])
    run(['codesign','--verify','--deep','--strict',app])
    zipfile = output / ('codex-usage-float-v'+VERSION+'-macos-'+('universal' if universal else arches[0])+'.zip')
    run(['ditto','-c','-k','--sequesterRsrc','--keepParent',app,zipfile])
    digest=hashlib.sha256(zipfile.read_bytes()).hexdigest()
    zipfile.with_suffix('.zip.sha256').write_text(digest+'  '+zipfile.name+'\n')
    print(json.dumps({'app':str(app),'zip':str(zipfile),'sha256':digest},ensure_ascii=False,indent=2))

def install(app, destination, replace):
    app=app.expanduser().resolve()
    destination=destination.expanduser().resolve()
    if not (app/'Contents/MacOS/UsageFloat').is_file():
        raise RuntimeError('未找到构建好的应用，请先运行 build。')
    with (app/'Contents/Info.plist').open('rb') as f:
        if plistlib.load(f).get('CFBundleIdentifier') != BUNDLE_ID:
            raise RuntimeError('应用标识不符，拒绝安装。')
    run(['codesign','--verify','--deep','--strict',app])
    target=destination/NAME
    if target.exists():
        if not replace:
            raise RuntimeError('目标已存在。先退出旧应用；确认更新后使用 --replace。')
        with (target/'Contents/Info.plist').open('rb') as f:
            if plistlib.load(f).get('CFBundleIdentifier') != BUNDLE_ID:
                raise RuntimeError('同名应用的标识不同，不会覆盖。请改用其他安装目录。')
    check=subprocess.run(['pgrep','-x','UsageFloat'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    if check.returncode==0:
        raise RuntimeError('检测到用量悬浮窗正在运行，请通过其“··· → 退出悬浮窗”退出后重试。')
    if app==target:
        raise RuntimeError('源应用和安装位置相同，无需复制。')
    destination.mkdir(parents=True,exist_ok=True)
    run(['ditto',app,target])
    print('已安装：'+str(target)+'\n可在访达中双击打开；脚本不会自动启动或更改安全设置。')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='command',required=True)
    b=sub.add_parser('build');b.add_argument('--output',type=Path,default=Path('dist'));b.add_argument('--universal',action='store_true')
    i=sub.add_parser('install');i.add_argument('--app',type=Path,required=True);i.add_argument('--destination',type=Path,default=Path.home()/'Applications');i.add_argument('--replace',action='store_true')
    sub.add_parser('check')
    a=parser.parse_args()
    if a.command=='build':build(a.output,a.universal)
    elif a.command=='install':install(a.app,a.destination,a.replace)
    else:
        print(json.dumps({'system':platform.system(),'architecture':platform.machine(),
                          'swiftc':shutil.which('swiftc'),'codexOnPath':shutil.which('codex'),
                          'desktopAppFound':any(Path(p).exists() for p in ['/Applications/ChatGPT.app','/Applications/Codex.app']),
                          'credentialsRead':False},ensure_ascii=False,indent=2))

if __name__=='__main__':
    try:main()
    except (RuntimeError,subprocess.CalledProcessError,OSError,ValueError) as e:
        print('错误：'+str(e),file=sys.stderr);sys.exit(1)
