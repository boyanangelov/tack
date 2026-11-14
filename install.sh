#!/bin/bash
# Builds Tack, installs it to ~/Applications and starts it.
set -euo pipefail
cd "$(dirname "$0")"
pkill -x Tack 2>/dev/null || true
./build.sh --install
open ~/Applications/Tack.app
