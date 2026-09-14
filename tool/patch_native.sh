#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re
import shutil
import subprocess

manifest = Path('android/app/src/main/AndroidManifest.xml')
text = manifest.read_text()

perms = '''<uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />'''

if 'READ_MEDIA_IMAGES' not in text:
    text = text.replace(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    ' + perms,
    )

text = re.sub(
    r'android:label="[^"]*"',
    'android:label="Mariage Emmanuel &amp; Jennifer"',
    text,
    count=1,
)
manifest.write_text(text)

gradle = Path('android/app/build.gradle.kts')
text = gradle.read_text()
text = re.sub(
    r'namespace\s*=\s*"[^"]+"',
    'namespace = "fr.creemachanson.mariage"',
    text,
    count=1,
)
text = re.sub(
    r'applicationId\s*=\s*"[^"]+"',
    'applicationId = "fr.creemachanson.mariage"',
    text,
    count=1,
)
text = re.sub(
    r'compileSdk\s*=\s*[^\n]+',
    'compileSdk = 36',
    text,
    count=1,
)
text = re.sub(
    r'targetSdk\s*=\s*[^\n]+',
    'targetSdk = 36',
    text,
    count=1,
)
gradle.write_text(text)

for main_activity in Path('android/app/src/main/kotlin').rglob('MainActivity.kt'):
    text = main_activity.read_text()
    text = re.sub(
        r'^package\s+[^\n]+',
        'package fr.creemachanson.mariage',
        text,
        count=1,
        flags=re.MULTILINE,
    )
    main_activity.write_text(text)

source = Path('assets/app_icon.png')
if not source.exists():
    raise SystemExit(f'Icône Android manquante: {source}')

sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
}

for density, size in sizes.items():
    target = Path(f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
    target.parent.mkdir(parents=True, exist_ok=True)
    if shutil.which('convert'):
        subprocess.run(
            ['convert', str(source), '-resize', f'{size}x{size}', str(target)],
            check=True,
        )
    elif shutil.which('ffmpeg'):
        subprocess.run(
            ['ffmpeg', '-y', '-loglevel', 'error', '-i', str(source), '-vf', f'scale={size}:{size}', str(target)],
            check=True,
        )
    else:
        shutil.copyfile(source, target)

plist = Path('ios/Runner/Info.plist')
if plist.exists():
    text = plist.read_text()
    insert = '''
\t<key>NSPhotoLibraryUsageDescription</key>
\t<string>Cette application envoie uniquement les photos et vidéos prises pendant le mariage, avec votre autorisation.</string>
\t<key>PHPhotoLibraryPreventAutomaticLimitedAccessAlert</key>
\t<true/>
\t<key>UIBackgroundModes</key>
\t<array>
\t\t<string>fetch</string>
\t</array>
'''
    if 'NSPhotoLibraryUsageDescription' not in text:
        text = text.replace('</dict>', insert + '</dict>')
    plist.write_text(text)

pbx = Path('ios/Runner.xcodeproj/project.pbxproj')
if pbx.exists():
    text = pbx.read_text()
    text = re.sub(
        r'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;',
        'IPHONEOS_DEPLOYMENT_TARGET = 14.0;',
        text,
    )
    pbx.write_text(text)
PY
