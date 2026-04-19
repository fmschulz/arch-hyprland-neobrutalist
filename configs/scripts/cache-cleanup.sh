#!/bin/bash
# Clean application caches (browser, Electron apps, thumbnails)
# Preserves ML caches (huggingface, rattler, uv) for scientific computing

set -euo pipefail

echo "=== Cache Cleanup ==="
echo "Before: $(du -sh ~/.cache 2>/dev/null | cut -f1)"

# Browser caches
rm -rf ~/.cache/chromium/Default/Cache/* 2>/dev/null || true
rm -rf ~/.cache/chromium/Default/Code\ Cache/* 2>/dev/null || true
rm -rf ~/.cache/mozilla/firefox/*/cache2/* 2>/dev/null || true

# Electron app caches (Slack, VS Code)
rm -rf ~/.config/Slack/Cache/* 2>/dev/null || true
rm -rf ~/.config/Slack/Code\ Cache/* 2>/dev/null || true
rm -rf ~/.config/Slack/GPUCache/* 2>/dev/null || true
rm -rf ~/.config/Code/Cache/* 2>/dev/null || true
rm -rf ~/.config/Code/CachedData/* 2>/dev/null || true
rm -rf ~/.config/Code/GPUCache/* 2>/dev/null || true

# Thumbnails
rm -rf ~/.cache/thumbnails/* 2>/dev/null || true

# Old yay build files (>30 days)
find ~/.cache/yay -maxdepth 1 -type d -mtime +30 -exec rm -rf {} + 2>/dev/null || true

# NOTE: Preserving ML caches (huggingface, rattler, uv) for scientific computing

echo "After: $(du -sh ~/.cache 2>/dev/null | cut -f1)"
