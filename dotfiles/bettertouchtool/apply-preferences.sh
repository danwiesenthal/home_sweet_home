#!/usr/bin/env bash
# Apply BetterTouchTool app-level preferences (not preset triggers — those live in keyboard.bttpreset).
# Quit BTT before running; relaunch after.
#
# Add new preferences here as they're discovered. To find a key after toggling it in the GUI:
#   defaults read com.hegenberg.BetterTouchTool | grep -iE 'keyword'

set -euo pipefail

DOMAIN=com.hegenberg.BetterTouchTool

# Use BTT's classic window snapping instead of integrating with macOS Sequoia's system snapping.
defaults write "$DOMAIN" BSTSequoiaUseClassicSnapping -int 1

# Don't restore a window's pre-snap size when dragged away from a snapped position.
defaults write "$DOMAIN" snapBack -bool false

echo "Applied. Restart BetterTouchTool for changes to take effect."
