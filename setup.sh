#!/usr/bin/env bash
# wechat-article-reader - Linux/macOS Setup Script
# Usage: bash setup.sh

set -e

echo "=== wechat-article-reader Setup ==="
echo ""

# Check Python version
python3 --version 2>/dev/null || { echo "ERROR: Python 3 not found. Please install Python 3.8+."; exit 1; }

# Create virtual environment (recommended)
if [ ! -d ".venv" ]; then
    echo "[1/4] Creating virtual environment..."
    python3 -m venv .venv
    echo "  Virtual environment created at .venv/"
else
    echo "[1/4] Virtual environment already exists, skipping..."
fi

# Activate virtual environment
source .venv/bin/activate

# Install core dependency
echo "[2/4] Installing core dependency (curl_cffi)..."
pip install --quiet curl_cffi>=0.7.0
echo "  curl_cffi installed (Strategy 1 enabled)"

# Install optional dependency: nodriver
echo "[3/4] Installing optional dependency (nodriver)..."
pip install --quiet nodriver 2>/dev/null && echo "  nodriver installed (Strategy 2 enabled)" || echo "  nodriver skipped (Strategy 2 disabled, non-critical)"

# Check for Camoufox CLI tool
echo "[4/4] Checking Camoufox CLI tool..."
if command -v wechat-article-to-markdown &>/dev/null; then
    echo "  wechat-article-to-markdown found (Strategy 3 enabled)"
else
    echo "  wechat-article-to-markdown not found."
    echo "  To enable Strategy 3, run: uv tool install wechat-article-to-markdown"
    echo "  (Strategy 3 is the fallback, most articles work with Strategy 1)"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Usage:"
echo "  source .venv/bin/activate"
echo "  python wechat_fetcher.py \"https://mp.weixin.qq.com/s/xxx\" -o output/"
echo ""
echo "Quick test:"
echo "  python -c \"from curl_cffi import requests; print('curl_cffi OK')\""
