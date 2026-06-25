# wechat-article-reader

Fetch WeChat Official Account (微信公众号) articles from `mp.weixin.qq.com` and convert to Markdown.

## Why This Tool?

WeChat articles are protected by a two-layer anti-scraping system:
1. **User-Agent check** — verifies the client identity (MicroMessenger version)
2. **TLS fingerprint check** — verifies JA4/JA3 fingerprint matches the claimed client

Standard HTTP libraries (requests, urllib) expose Python's TLS fingerprint, which doesn't match the claimed Chrome UA, triggering a verification page. This tool solves it with full fingerprint spoofing.

## Quick Start

```bash
# Clone
git clone https://github.com/tianyi-1349/wechat-article-reader.git
cd wechat-article-reader

# Install
bash setup.sh        # Linux/macOS
setup.bat            # Windows

# Fetch an article
python wechat_fetcher.py "https://mp.weixin.qq.com/s/xxxxx" -o output/
```

## Four-Strategy Fallback Chain

| Strategy | Technology | Speed | Reliability |
|---|---|---|---|
| 1 | curl_cffi (JA4/TLS/HTTP2 spoofing) | <1s | ~85% |
| 2 | nodriver (Chrome CDP headless) | 6-15s | ~95% |
| 3 | Camoufox (anti-detect Firefox) | 15-30s | ~99% |
| 4 | Search engine cache (Sogou) | varies | ~60% |

Strategies use heterogeneous technology stacks (HTTP lib → Chromium CDP → Firefox Marionette), making it impossible for WAF to block all paths simultaneously.

## For AI Assistants (Claude Code / Codex)

Read `SKILL.md` for the complete technical specification. Quick integration:

```bash
# 1. Read the skill document
cat SKILL.md

# 2. Run the fetcher
python wechat_fetcher.py "URL" -o "output_dir"

# 3. Parse the JSON result from stdout (last line, RESULT_JSON: prefix)
```

## Dependencies

- **Required**: `curl_cffi` (Strategy 1)
- **Optional**: `nodriver` (Strategy 2), `wechat-article-to-markdown` (Strategy 3)
- **No deps**: Strategy 4 (uses built-in urllib)

## Output

```
output/
├── Article Title.md    # Markdown with title, author, time, body
└── images/             # Downloaded images (bypasses Referer check)
    ├── img_001.png
    └── img_002.jpg
```

## License

For technical research and legitimate use only.
