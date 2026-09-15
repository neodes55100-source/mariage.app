#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import json
import re
import shutil
import subprocess

source = Path('assets/app_icon.png')
if not source.exists():
    raise SystemExit(f'Icône de l’application manquante: {source}')

# --- Android ---------------------------------------------------------------
manifest = Path('android/app/src/main/AndroidManifest.xml')
if manifest.exists():
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
    if gradle.exists():
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

# --- iOS -------------------------------------------------------------------
plist = Path('ios/Runner/Info.plist')
if plist.exists():
    text = plist.read_text()

    text = re.sub(
        r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)',
        r'\1Mariage Emmanuel &amp; Jennifer\2',
        text,
        count=1,
    )

    additions = []
    if 'NSPhotoLibraryUsageDescription' not in text:
        additions.extend([
            '\t<key>NSPhotoLibraryUsageDescription</key>',
            '\t<string>Cette application accède à vos photos et vidéos afin de partager les souvenirs du mariage avec votre autorisation.</string>',
        ])
    if 'PHPhotoLibraryPreventAutomaticLimitedAccessAlert' not in text:
        additions.extend([
            '\t<key>PHPhotoLibraryPreventAutomaticLimitedAccessAlert</key>',
            '\t<true/>',
        ])
    if 'UIBackgroundModes' not in text:
        additions.extend([
            '\t<key>UIBackgroundModes</key>',
            '\t<array>',
            '\t\t<string>fetch</string>',
            '\t</array>',
        ])

    if additions:
        text = text.replace('</dict>', '\n'.join(additions) + '\n</dict>')

    plist.write_text(text)

pbx = Path('ios/Runner.xcodeproj/project.pbxproj')
if pbx.exists():
    text = pbx.read_text()
    text = re.sub(
        r'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;',
        'IPHONEOS_DEPLOYMENT_TARGET = 14.0;',
        text,
    )

    out = []
    for line in text.splitlines():
        if 'PRODUCT_BUNDLE_IDENTIFIER = ' in line:
            indent = line[:len(line) - len(line.lstrip())]
            if '.RunnerTests;' in line:
                line = f'{indent}PRODUCT_BUNDLE_IDENTIFIER = fr.creemachanson.mariage.RunnerTests;'
            else:
                line = f'{indent}PRODUCT_BUNDLE_IDENTIFIER = fr.creemachanson.mariage;'
        out.append(line)
    pbx.write_text('\n'.join(out) + '\n')

# Reprend la même icône que la version Android pour l’App Store/iPhone.
contents = Path('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json')
if contents.exists():
    data = json.loads(contents.read_text())
    appicon_dir = contents.parent

    for image in data.get('images', []):
        filename = image.get('filename')
        size_raw = image.get('size')
        scale_raw = image.get('scale')
        if not filename or not size_raw or not scale_raw:
            continue

        points = float(str(size_raw).split('x')[0])
        scale = float(str(scale_raw).replace('x', ''))
        pixels = max(1, int(round(points * scale)))
        target = appicon_dir / filename

        if shutil.which('sips'):
            subprocess.run(
                ['sips', '-z', str(pixels), str(pixels), str(source), '--out', str(target)],
                check=True,
                stdout=subprocess.DEVNULL,
            )
        elif shutil.which('convert'):
            subprocess.run(
                ['convert', str(source), '-resize', f'{pixels}x{pixels}', str(target)],
                check=True,
            )
        else:
            shutil.copyfile(source, target)
PY
