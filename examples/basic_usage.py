#!/usr/bin/env python3
"""
wechat-article-reader - Programmatic Usage Examples

Demonstrates how to call wechat_fetcher.py from Python code.
"""

import sys
import os
import json
import subprocess
from pathlib import Path

# Ensure UTF-8 on Windows
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def fetch_article(url: str, output_dir: str = "output") -> dict:
    """
    Fetch a WeChat article and return structured result.

    Args:
        url: WeChat article URL (mp.weixin.qq.com)
        output_dir: Output directory for Markdown and images

    Returns:
        dict with keys: success, strategy, file, article (if successful)
    """
    script_dir = Path(__file__).parent
    fetcher = script_dir / "wechat_fetcher.py"
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    env["PYTHONIOENCODING"] = "utf-8"
    env["PYTHONUTF8"] = "1"

    result = subprocess.run(
        [sys.executable, str(fetcher), url, "-o", str(output_path)],
        capture_output=True,
        text=True,
        timeout=120,
        env=env,
        encoding="utf-8",
        errors="replace",
    )

    # Parse RESULT_JSON from stdout
    for line in result.stdout.splitlines():
        if line.startswith("RESULT_JSON:"):
            return json.loads(line[len("RESULT_JSON:"):])

    return {"success": False, "error": result.stderr[:500] if result.stderr else "Unknown error"}


def fetch_with_fallback(url: str, output_dir: str = "output") -> dict:
    """
    Fetch article using direct Python import (no subprocess).
    Requires wechat_fetcher.py to be in the same directory.
    """
    # Add script directory to path
    script_dir = str(Path(__file__).parent)
    if script_dir not in sys.path:
        sys.path.insert(0, script_dir)

    from wechat_fetcher import (
        normalize_url,
        strategy_ua,
        strategy_nodriver,
        strategy_camoufox,
        strategy_search_cache,
    )

    clean_url = normalize_url(url)
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)

    # Try strategies in order
    for strategy_fn in [strategy_ua, strategy_nodriver, strategy_camoufox, strategy_search_cache]:
        result = strategy_fn(clean_url, out)
        if result.get("success"):
            return result

    return {"success": False, "error": "All strategies failed"}


# ── Example Usage ──────────────────────────────────────

if __name__ == "__main__":
    # Example 1: Subprocess mode (recommended - isolated environment)
    print("=== Example 1: Subprocess Mode ===")
    result = fetch_article(
        url="https://mp.weixin.qq.com/s/example_article_id",
        output_dir="output",
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))

    # Example 2: Direct import mode (faster, shared environment)
    # print("\n=== Example 2: Direct Import Mode ===")
    # result = fetch_with_fallback(
    #     url="https://mp.weixin.qq.com/s/example_article_id",
    #     output_dir="output",
    # )
    # print(json.dumps(result, ensure_ascii=False, indent=2))
