#!/usr/bin/env bash
set -euo pipefail
mkdir -p assets/wedding
base64 -d assets/wedding/rose_top.webp.b64 > assets/wedding/rose_top.webp
base64 -d assets/wedding/rose_bottom.webp.b64 > assets/wedding/rose_bottom.webp
