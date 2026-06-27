# AGENTS.md — WeChat Article Reader

## Project Overview

Python tool to fetch WeChat Official Account (mp.weixin.qq.com) articles and convert to Markdown. Implements a 4-strategy fallback chain with heterogeneous anti-detection engines.

## Quick Start

```bash
# First-time setup (creates .venv, installs deps)
bash setup.sh        # Linux/macOS
setup.bat            # Windows

# Fetch an article
python wechat_fetcher.py "https://mp.weixin.qq.com/s/xxx" -o output/
```

## Architecture

```
wechat_fetcher.py
├── Strategy 1: curl_cffi (JA4/TLS/HTTP2 spoof → Chrome 126) — default, <1s
├── Strategy 2: nodriver (Chrome CDP headless, webdriver=False) — 6-15s
├── Strategy 3: Camoufox (Firefox Marionette anti-detect) — 15-30s
└── Strategy 4: Sogou search engine cache — fallback, varies
```

Strategies auto-fallback. Each uses a fundamentally different network stack (HTTP lib → Chromium CDP → Firefox Marionette), so WAF cannot block all paths simultaneously.

## Conventions

- **Language**: Python 3.8+, comments and docstrings in Chinese
- **Encoding**: Always UTF-8. Windows GBK fix is built into the script (sys.stdout.reconfigure)
- **Dependencies**: curl_cffi (required), nodriver (optional), wechat-article-to-markdown (optional, separate install via `uv tool install`)
- **Output**: Markdown file + images/ subdirectory. JSON result on stdout (last line, `RESULT_JSON:` prefix)
- **Virtual env**: Always use .venv (created by setup.sh/setup.bat)

## File Map

| File | Purpose |
|------|--------|
| `wechat_fetcher.py` | Core fetcher — all 4 strategies, HTML→MD conversion, image download |
| `requirements.txt` | pip dependencies (curl_cffi required, nodriver optional) |
| `setup.sh` / `setup.bat` | One-click venv creation + dependency installation |
| `SKILL.md` | Full technical specification (QoderWork skill format, 32KB) |
| `examples/basic_usage.py` | Programmatic integration: subprocess mode + direct import mode |

## Integration Pattern

When calling from code or another agent:

```bash
# Run fetcher, capture output
python wechat_fetcher.py "URL" -o "output_dir"

# Parse last line of stdout for structured result
# Format: RESULT_JSON:{"success":true,"strategy":"curl_cffi","file":"output/Title.md","article":{...}}
```

See `examples/basic_usage.py` for Python wrapper functions.

## Testing

```bash
# Verify curl_cffi is working
python -c "from curl_cffi import requests; print('OK')"

# Test with a real URL
python wechat_fetcher.py "https://mp.weixin.qq.com/s/test_article" -o test_output/
ls test_output/  # Should contain .md file + images/ directory
```

## Limitations

- Only supports public mp.weixin.qq.com links (no paywalled/login-required articles)
- SVG-rendered code blocks cannot be extracted as source code
- Video URLs are extracted but not downloaded
- Image Referer validation requires local download (handled automatically)
