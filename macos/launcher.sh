#!/bin/sh
# Main executable of Motherload.app (installed as Contents/MacOS/Motherload).
# Starts the bundled Ruffle player on the bundled SWF. Extra arguments are passed
# through to Ruffle, e.g.: open -a Motherload --args --fullscreen
CONTENTS="$(cd "$(dirname "$0")/.." && pwd -P)"
DATA="$HOME/Library/Application Support/Motherload"
mkdir -p "$DATA"

exec "$CONTENTS/MacOS/ruffle" \
    --config "$DATA" \
    --save-directory "$DATA/SharedObjects" \
    --cache-directory "$HOME/Library/Caches/Motherload" \
    --filesystem-access-mode deny \
    --no-gui \
    "$@" \
    "$CONTENTS/Resources/game.swf"
