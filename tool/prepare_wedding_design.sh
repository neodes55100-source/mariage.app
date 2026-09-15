#!/usr/bin/env bash
set -euo pipefail
bash tool/decode_wedding_assets.sh
python3 tool/patch_wedding_design.py
