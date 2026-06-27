# WeChat Article Reader

Fetch WeChat Official Account (mp.weixin.qq.com) articles and convert to Markdown.

## When to Use

When the user provides a `mp.weixin.qq.com` URL or asks to read/fetch a WeChat article:

1. Run setup (first time only): `bash setup.sh`
2. Fetch: `python wechat_fetcher.py "URL" -o "output_dir"`
3. Read the generated .md file and present to user

## Setup (First Time)

```bash
bash setup.sh   # Creates .venv, installs curl_cffi + optional deps
```

After setup, always use the venv Python:

```bash
# Linux/macOS
source .venv/bin/activate
python wechat_fetcher.py "URL" -o output/

# Windows
.venv\Scripts\activate
python wechat_fetcher.py "URL" -o output/
```

## How It Works

Four-strategy fallback chain with heterogeneous tech stacks:

| # | Engine | Tech | Speed | Success Rate |
|---|--------|------|-------|-------------|
| 1 | curl_cffi | JA4/TLS/HTTP2 fingerprint spoofing (Chrome 126) | <1s | ~85% |
| 2 | nodriver | Chrome CDP headless (real browser, webdriver=False) | 6-15s | ~95% |
| 3 | Camoufox | Anti-detect Firefox Marionette | 15-30s | ~99% |
| 4 | Sogou cache | Search engine cached version | varies | ~60% |

Strategy 1 and 2 work out of the box after `setup.sh`. Strategy 3 requires separate install: `uv tool install wechat-article-to-markdown`. Strategy 4 uses built-in urllib (no deps).

## Output Format

The script prints a JSON result as the last line of stdout (prefix `RESULT_JSON:`):

```json
{
  "success": true,
  "strategy": "curl_cffi",
  "file": "output/Article Title.md",
  "article": {
    "title": "Article Title",
    "author": "Author Name",
    "time": "2026-06-27",
    "url": "https://mp.weixin.qq.com/s/xxx",
    "images_downloaded": 5
  }
}
```

On failure: `{"success": false, "strategy": "all_failed", "error": "description"}`

## Programmatic Usage

See `examples/basic_usage.py` for two integration patterns:
- **Subprocess mode** (recommended): isolated env, parse RESULT_JSON from stdout
- **Direct import mode**: faster, import functions from wechat_fetcher

## Project Structure

```
wechat_fetcher.py    # Core fetcher (4-strategy fallback)
requirements.txt     # Python dependencies
setup.sh / setup.bat # One-click setup (creates venv + installs deps)
SKILL.md             # Detailed technical spec (QoderWork skill format)
examples/            # Programmatic usage examples
```

## Key Notes

- Windows: script auto-fixes GBK encoding (sys.stdout.reconfigure utf-8)
- Images: downloaded to `output/images/` subdirectory (bypasses Referer check)
- URL cleaning: auto-strips tracking parameters (scene, sessionid, etc.)
- All strategies are automatic — just pass the URL, the script handles fallback
