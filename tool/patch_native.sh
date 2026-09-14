#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re

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
text = re.sub(r'android:label="[^"]*"', 'android:label="Mariage E & J"', text, count=1)
manifest.write_text(text)

plist = Path('ios/Runner/Info.plist')
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
text = pbx.read_text()
text = re.sub(r'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;', 'IPHONEOS_DEPLOYMENT_TARGET = 14.0;', text)
pbx.write_text(text)

PY
