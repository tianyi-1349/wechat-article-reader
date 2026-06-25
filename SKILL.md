# 微信公众号文章智能读取方案

> 本文档面向 AI 编码助手（Claude Code、Codex 等），提供完整的微信公众号文章抓取技术方案。
> 版本：v4.0.0 | 最后更新：2026-06-25

---

## 一、安装与集成（AI 助手必读）

### 1.1 GitHub 仓库结构

本方案以 GitHub 仓库形式分发，仓库地址：

```
https://github.com/tianyi-1349/wechat-article-reader
```

仓库目录结构：

```
wechat-article-reader/
├── SKILL.md                  # AI 助手入口文件（本文件）
├── wechat_fetcher.py         # 主脚本（四级降级策略完整实现）
├── requirements.txt          # Python 依赖清单
├── setup.sh                  # Linux/macOS 一键安装脚本
├── setup.bat                 # Windows 一键安装脚本
├── examples/
│   └── basic_usage.py        # 程序化调用示例
└── README.md                 # 人类可读说明
```

### 1.2 快速安装

**方式一：一键安装脚本（推荐）**

```bash
# Linux / macOS
git clone https://github.com/tianyi-1349/wechat-article-reader.git
cd wechat-article-reader
bash setup.sh

# Windows
git clone https://github.com/tianyi-1349/wechat-article-reader.git
cd wechat-article-reader
setup.bat
```

**方式二：手动安装**

```bash
# 1. 克隆仓库
git clone https://github.com/tianyi-1349/wechat-article-reader.git
cd wechat-article-reader

# 2. 安装核心依赖（策略1: curl_cffi 指纹伪装）
pip install curl_cffi

# 3. 安装可选依赖（策略2: nodriver 无头浏览器）
pip install nodriver

# 4. 安装可选依赖（策略3: Camoufox 反检测浏览器）
uv tool install wechat-article-to-markdown
```

**方式三：仅安装核心依赖（最小化安装）**

```bash
pip install curl_cffi
# 仅策略1可用，其余策略自动跳过。大多数公开文章策略1即可成功。
```

### 1.3 依赖清单（requirements.txt）

```
# 核心（策略1）
curl_cffi>=0.7.0

# 可选 - 策略2（nodriver 无头 Chrome CDP）
# pip install nodriver

# 可选 - 策略3（Camoufox，通过外部 CLI 工具）
# uv tool install wechat-article-to-markdown

# 无额外依赖 - 策略4（搜索引擎缓存，使用内置 urllib）
```

### 1.4 AI 助手集成指引

#### Claude Code 集成

Claude Code 通过 `CLAUDE.md` 文件发现和使用本技能：

```markdown
# 在你的项目 CLAUDE.md 中添加：

## 微信公众号文章读取

当用户需要读取 mp.weixin.qq.com 文章时：
1. 进入 wechat-article-reader 目录
2. 阅读 SKILL.md 了解完整方案
3. 运行: python wechat_fetcher.py "URL" -o "输出目录"
4. 解析 stdout 最后的 RESULT_JSON: 前缀获取结构化结果
```

#### Codex 集成

Codex 通过项目级指令或对话上下文使用：

```markdown
# 在 Codex 对话中直接说：

请读取 wechat-article-reader/SKILL.md，
然后用 wechat_fetcher.py 抓取这个微信文章：
https://mp.weixin.qq.com/s/xxxxx
输出到 output/ 目录
```

#### 通用集成模式（任何 AI 助手）

所有 AI 编码助手的集成流程一致：

```
1. 读取 SKILL.md → 理解方案原理和四级降级策略
2. 确认依赖已安装 → pip list | grep curl_cffi
3. 执行命令 → python wechat_fetcher.py "URL" -o "output"
4. 解析结果 → stdout 末尾 RESULT_JSON:{...} 包含结构化数据
5. 错误处理 → 检查每级策略的失败日志，确认依赖是否缺失
```

### 1.5 Windows 特殊注意事项

**GBK 编码问题**：Windows 上 Python CLI 工具含 emoji 输出会报 `UnicodeEncodeError`。

解决方案（三选一）：

```bash
# 方案A：设置环境变量（推荐）
set PYTHONIOENCODING=utf-8
set PYTHONUTF8=1
python wechat_fetcher.py "URL" -o "output"

# 方案B：PowerShell
$env:PYTHONIOENCODING="utf-8"
$env:PYTHONUTF8="1"
python wechat_fetcher.py "URL" -o "output"

# 方案C：脚本内置修复（已包含在 wechat_fetcher.py 中）
# sys.stdout.reconfigure(encoding="utf-8", errors="replace")
```

**Camoufox 策略的额外修复**：如果安装了 `wechat-article-to-markdown`，需手动修补其 GBK 编码问题（见文档末尾"已知问题"章节）。

---

## 二、核心原理

### 2.1 微信反爬机制

微信公众号文章对直接 HTTP 请求返回「环境安全验证」页面。安全检测分两层：

1. **第一层**：检查 User-Agent 中的客户端标识（MicroMessenger 版本、平台标识）
2. **第二层**：检查 TLS 指纹（JA4/JA3）是否与声称的客户端匹配

普通 HTTP 请求（requests、urllib）的 TLS 指纹暴露为 Python 特征，与声称的 Chrome UA 不匹配，触发验证页。

### 2.2 解决方案

使用 `curl_cffi` 库（基于 curl-impersonate）将 TLS 指纹伪装为 Chrome 126（`impersonate="chrome126"`），同时伪造 HTTP/2 指纹和 UA，实现全维度伪装。对于进一步增强检测的文章，使用真实浏览器（nodriver/Camoufox）作为后备。

---

## 三、四级降级策略（引擎异构设计）

每级策略使用根本不同的技术栈，确保 WAF 升级无法同时封锁所有路径：

```
策略1: curl_cffi 全指纹伪装（HTTP层，JA4/TLS/HTTP2+UA，伪装 Chrome 126，秒级完成）
  ↓ curl_cffi 不可用时降级为 urllib（仅 UA 伪装）
  ↓ 内容验证失败时自动切换
策略2: nodriver 无头 Chrome CDP（Chromium CDP层，navigator.webdriver=False，6-15秒）
  ↓ 真实浏览器指纹，协议级消除 WebDriver 标记
  ↓ 失败时自动切换
策略3: Camoufox 反检测浏览器（Firefox Marionette层，最可靠，15-30秒）
  ↓ 失败时自动切换
策略4: 搜索引擎缓存（搜狗微信搜索，内容可能不完整）
```

**引擎异构性**：策略1=HTTP库 → 策略2=Chromium CDP → 策略3=Firefox Marionette，三种完全不同的网络栈和浏览器指纹，WAF 无法一刀切封锁。

---

## 四、完整 Python 脚本（wechat_fetcher.py）

```python
#!/usr/bin/env python3
"""
微信公众号文章智能抓取工具 v4.0
策略链（4级降级）：
  1. curl_cffi 全指纹伪装（JA4+TLS+HTTP/2+UA）
  2. nodriver 无头 Chrome CDP（真实浏览器指纹，消除 WebDriver 检测）
  3. Camoufox 反检测浏览器兜底（需 wechat-article-to-markdown）
  4. 搜索引擎缓存备选

v4.0 变更: 新增 nodriver 策略层，HTTP 伪装失败后自动升级真实浏览器抓取
依赖: pip install curl_cffi nodriver  (均可选，缺失时自动跳过)

用法：python wechat_fetcher.py "https://mp.weixin.qq.com/s/xxx" [--output 输出目录]
"""

import sys
import os
import re
import json
import time
import argparse
import subprocess
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError
from urllib.parse import urlparse, quote

# curl_cffi: JA4/TLS 指纹伪装（可选依赖，缺失时降级为 urllib）
try:
    from curl_cffi import requests as curl_requests
    HAS_CURL_CFFI = True
except ImportError:
    HAS_CURL_CFFI = False

# nodriver: 无头 Chrome CDP 驱动（可选依赖，缺失时跳过策略2）
try:
    import nodriver as uc
    HAS_NODRIVER = True
except ImportError:
    HAS_NODRIVER = False

# 修复 Windows GBK 编码
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

# ── 常量 ──────────────────────────────────────────────
WECHAT_UA = (
    "Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 "
    "Chrome/126.0.6478.71 XWEB/4262 MMWEBSDK/20240501 "
    "Mobile Safari/537.36 MicroMessenger/8.0.50.2701(0x28003253)"
)

NORMAL_UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/126.0.0.0 Safari/537.36"
)

# ── 工具函数 ──────────────────────────────────────────

def normalize_url(url: str) -> str:
    """清理微信URL，去除追踪参数"""
    # 保留核心参数，去掉 scene、subscene、sessionid 等追踪参数
    patterns = [
        r'(&|\?)(scene|subscene|sessionid|clicktime|ascene|devicetype|version|lang|nettype|abtest_cookie|exportkey|pass_ticket|wx_header|plat_id|mpshare|from|isappinstalled)=[^&]*',
    ]
    cleaned = url
    for p in patterns:
        cleaned = re.sub(p, '', cleaned)
    return cleaned.rstrip('&')


def _has_real_content(html: str) -> bool:
    """判断HTML是否为真实文章内容（而非验证页/拦截页）"""
    return (
        "js_content" in html
        and "环境异常" not in html
        and "请完成下方验证" not in html
        and "操作过于频繁" not in html
        and len(html) > 5000  # 验证页通常很短
    )


def fetch_with_ua(url: str, ua: str, timeout: int = 20) -> tuple:
    """用指定UA请求URL，返回 (html, status_code, has_content)

    v3.0: 优先使用 curl_cffi（JA4/TLS/HTTP2 指纹伪装为 Chrome 126），
          不可用时降级为 urllib（仅 UA 伪装，TLS 指纹暴露）。
    """
    if HAS_CURL_CFFI:
        try:
            resp = curl_requests.get(
                url,
                impersonate="chrome126",
                headers={"User-Agent": ua, "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8"},
                timeout=timeout,
            )
            html = resp.text
            return html, resp.status_code, _has_real_content(html)
        except Exception:
            pass  # 降级到 urllib

    # urllib 降级路径（无 TLS 指纹伪装）
    try:
        req = Request(url, headers={"User-Agent": ua, "Accept-Language": "zh-CN,zh;q=0.9"})
        resp = urlopen(req, timeout=timeout)
        html = resp.read().decode("utf-8", errors="replace")
        return html, resp.status, _has_real_content(html)
    except (URLError, HTTPError) as e:
        return "", getattr(e, "code", 0), False


def extract_article_from_html(html: str) -> dict:
    """从HTML中提取文章标题和正文（简化版）"""
    result = {"title": "", "author": "", "publish_time": "", "body_html": "", "images": []}

    # 标题（多种匹配模式 + og:title 兜底）
    for pattern in [
        r'<h1[^>]*class="rich_media_title"[^>]*>(.*?)</h1>',
        r'<h1[^>]*>(.*?)</h1>',
    ]:
        m = re.search(pattern, html, re.S)
        if m:
            title = re.sub(r'<[^>]+>', '', m.group(1)).strip()
            if title:
                result["title"] = title
                break
    if not result["title"]:
        m = re.search(r'<meta\s+property="og:title"\s+content="([^"]+)"', html)
        if m:
            result["title"] = m.group(1).strip()

    # 作者/公众号名
    m = re.search(r'<a[^>]*id="js_name"[^>]*>(.*?)</a>', html, re.S)
    if m:
        result["author"] = re.sub(r'<[^>]+>', '', m.group(1)).strip()

    # 发布时间（从JS变量中提取）
    m = re.search(r'var\s+ct\s*=\s*"(\d+)"', html)
    if m:
        ts = int(m.group(1))
        result["publish_time"] = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(ts))

    # 正文
    m = re.search(r'<div[^>]*id="js_content"[^>]*>(.*?)</div>\s*(?:<script|<div[^>]*class="(?!js_content))', html, re.S)
    if m:
        result["body_html"] = m.group(1)

    # 图片（data-src 懒加载，支持多种微信图片域名）
    for img_m in re.finditer(r'data-src="(https?://(?:mmbiz|mmecoa|mmebiz)\.qpic\.cn/[^"]+)"', html):
        url = img_m.group(1).replace('&amp;', '&')
        if url not in result["images"]:
            result["images"].append(url)

    # 视频URL提取
    result["videos"] = []
    # 腾讯视频 iframe
    for vid_m in re.finditer(r'data-src="(https?://v\.qq\.com/[^"]+)"', html):
        result["videos"].append({"type": "qq_video", "url": vid_m.group(1)})
    # 内嵌视频 mpvideo
    for vid_m in re.finditer(r'data-src="(https?://mp\.weixin\.qq\.com/mp/videoplayer[^"]+)"', html):
        result["videos"].append({"type": "mp_video", "url": vid_m.group(1)})
    # 通用 video/iframe
    for vid_m in re.finditer(r'<iframe[^>]*src="(https?://[^"]+)"', html):
        result["videos"].append({"type": "iframe", "url": vid_m.group(1)})

    return result


def download_images(article: dict, output_dir: Path) -> dict:
    """下载微信文章图片到本地，绕过 mmbiz.qpic.cn 防盗链（Referer 校验）

    微信图片服务器要求 Referer 为 https://mp.weixin.qq.com/，否则返回 403。
    本函数用 urllib 带 Referer 逐张下载，保存到 output_dir/images/，
    并替换 article["body_html"] 中的远程 URL 为本地相对路径。

    Args:
        article: extract_article_from_html() 返回的文章字典
        output_dir: 输出目录（Markdown 所在目录）

    Returns:
        article 字典（已修改 body_html 和 images）
    """
    images = article.get("images", [])
    if not images:
        return article

    img_dir = output_dir / "images"
    img_dir.mkdir(parents=True, exist_ok=True)

    downloaded = 0
    for i, url in enumerate(images):
        # 推断扩展名：优先 wx_fmt 参数，其次 URL 路径，默认 png
        ext = "png"
        fmt_m = re.search(r'[?&]wx_fmt=(\w+)', url)
        if fmt_m:
            ext = fmt_m.group(1)
        else:
            path_ext = urlparse(url).path.rsplit('.', 1)[-1].lower()
            if path_ext in ('png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'bmp'):
                ext = path_ext

        local_name = f"img_{i + 1:03d}.{ext}"
        local_path = img_dir / local_name

        try:
            req = Request(url, headers={
                "Referer": "https://mp.weixin.qq.com/",
                "User-Agent": NORMAL_UA,
            })
            with urlopen(req, timeout=15) as resp:
                data = resp.read()
                if len(data) > 500:  # 过滤掉错误页面/占位图
                    local_path.write_bytes(data)
                    # 替换 body_html 中的远程 URL 为本地相对路径
                    safe_url = url.replace('&', '&amp;')
                    article["body_html"] = article["body_html"].replace(
                        safe_url, f"images/{local_name}"
                    )
                    # 也替换未编码版本
                    article["body_html"] = article["body_html"].replace(
                        url, f"images/{local_name}"
                    )
                    downloaded += 1
        except Exception:
            pass  # 单张图片失败不影响整体，保留远程 URL 作为兜底

    if downloaded > 0:
        print(f"  图片下载: {downloaded}/{len(images)} 张已保存到 {img_dir}")

    return article


def html_to_markdown_simple(article: dict) -> str:
    """HTML→Markdown 转换（保留标题层级、粗体、列表、代码块）"""
    lines = []
    lines.append(f"# {article['title']}")
    lines.append("")
    if article["author"]:
        lines.append(f"> 公众号: {article['author']}")
    if article["publish_time"]:
        lines.append(f"> 发布时间: {article['publish_time']}")
    lines.append("")
    lines.append("---")
    lines.append("")

    body = article["body_html"]

    # 代码块优先处理（防止内部标签被转换）
    code_blocks = {}
    def save_code_block(m):
        key = f"__CODE_BLOCK_{len(code_blocks)}__"
        code = m.group(1)
        code = re.sub(r'<[^>]+>', '', code)
        code = code.replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>').replace('&nbsp;', ' ').replace('&quot;', '"')
        code = code.strip()
        code_blocks[key] = f"\n```\n{code}\n```\n"
        return key
    body = re.sub(r'<(?:pre|code)[^>]*>(.*?)</(?:pre|code)>', save_code_block, body, flags=re.S)

    # 标题
    body = re.sub(r'<h2[^>]*>(.*?)</h2>', lambda m: '\n\n## ' + re.sub(r'<[^>]+>', '', m.group(1)).strip() + '\n\n', body, flags=re.S)
    body = re.sub(r'<h3[^>]*>(.*?)</h3>', lambda m: '\n\n### ' + re.sub(r'<[^>]+>', '', m.group(1)).strip() + '\n\n', body, flags=re.S)
    body = re.sub(r'<h4[^>]*>(.*?)</h4>', lambda m: '\n\n#### ' + re.sub(r'<[^>]+>', '', m.group(1)).strip() + '\n\n', body, flags=re.S)

    # 列表
    body = re.sub(r'<li[^>]*>(.*?)</li>', lambda m: '- ' + re.sub(r'<[^>]+>', '', m.group(1)).strip() + '\n', body, flags=re.S)

    # 引用块
    body = re.sub(r'<blockquote[^>]*>(.*?)</blockquote>', lambda m: '\n> ' + re.sub(r'<[^>]+>', '', m.group(1)).strip().replace('\n', '\n> ') + '\n', body, flags=re.S)

    # 分隔线
    body = re.sub(r'<hr[^>]*/?\s*>', '\n\n---\n\n', body)

    # 段落分隔
    body = re.sub(r'<br\s*/?>', '\n', body)
    body = re.sub(r'</p>', '\n\n', body)
    body = re.sub(r'</section>', '\n', body)
    body = re.sub(r'</div>', '\n', body)

    # 图片占位
    body = re.sub(r'<img[^>]*data-src="([^"]+)"[^>]*/?\s*>', lambda m: '\n![Image](' + m.group(1).replace('&amp;', '&') + ')\n', body)

    # 粗体、斜体
    body = re.sub(r'<(?:strong|b)>(.*?)</(?:strong|b)>', r'**\1**', body, flags=re.S)
    body = re.sub(r'<(?:em|i)>(.*?)</(?:em|i)>', r'*\1*', body, flags=re.S)

    # 去除剩余标签
    body = re.sub(r'<[^>]+>', '', body)

    # HTML实体
    body = body.replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>')
    body = body.replace('&nbsp;', ' ').replace('&quot;', '"')

    # 还原代码块
    for key, val in code_blocks.items():
        body = body.replace(key, val)

    # 清理多余空行
    body = re.sub(r'\n{3,}', '\n\n', body)

    lines.append(body.strip())

    # 视频信息
    if article.get("videos"):
        lines.append("")
        lines.append("---")
        lines.append("")
        lines.append("## 多媒体内容")
        lines.append("")
        for i, v in enumerate(article["videos"], 1):
            v_url = v['url'].replace('&amp;', '&')
            lines.append(f"- 视频{i} ({v['type']}): {v_url}")

    return "\n".join(lines)


# ── 策略引擎 ──────────────────────────────────────────

def strategy_ua(url: str, output_dir: Path) -> dict:
    """策略1: 全指纹伪装（curl_cffi JA4/TLS/HTTP2 + UA，或 urllib 降级）"""
    engine = "curl_cffi (JA4+TLS+HTTP2+UA 全伪装)" if HAS_CURL_CFFI else "urllib (仅 UA 伪装)"
    print(f"[策略1] 尝试全指纹伪装 — 引擎: {engine}")
    html, status, ok = fetch_with_ua(url, WECHAT_UA)
    if ok:
        article = extract_article_from_html(html)
        if article["body_html"]:
            article = download_images(article, output_dir)
            md = html_to_markdown_simple(article)
            out_file = output_dir / f"{article['title'] or 'article'}.md"
            out_file.write_text(md, encoding="utf-8")
            print(f"[策略1] 成功! 标题: {article['title']}")
            print(f"  作者: {article['author']}, 时间: {article['publish_time']}")
            print(f"  图片: {len(article['images'])}张, 视频: {len(article.get('videos', []))}个")
            print(f"  输出: {out_file}")
            return {"success": True, "strategy": "ua", "file": str(out_file), "article": article}
    print(f"[策略1] 失败 (HTTP {status}), 降级到 nodriver...")
    return {"success": False}


def _run_nodriver_fetch(url: str, wait: int = 5) -> dict:
    """nodriver 异步抓取核心逻辑（独立函数，方便 async 调用）"""
    import asyncio

    async def _fetch():
        browser = await uc.start(headless=True)
        try:
            page = await browser.get(url)
            # 等待文章正文容器出现（微信文章的核心 DOM 节点）
            if wait > 0:
                await asyncio.sleep(wait)
            try:
                await page.wait_for("#js_content", timeout=10)
            except Exception:
                pass  # 即使等不到也继续，可能页面结构不同
            html = await page.get_content()
            return {"html": html, "success": True}
        finally:
            try:
                await browser.stop()
            except Exception:
                pass

    # 处理已有事件循环的情况（如在 Jupyter/async 环境中）
    try:
        loop = asyncio.get_running_loop()
        import concurrent.futures
        with concurrent.futures.ThreadPoolExecutor() as pool:
            future = pool.submit(asyncio.run, _fetch())
            return future.result(timeout=60)
    except RuntimeError:
        return asyncio.run(_fetch())


def strategy_nodriver(url: str, output_dir: Path) -> dict:
    """策略2: nodriver 无头 Chrome CDP（真实浏览器指纹，navigator.webdriver=False）"""
    if not HAS_NODRIVER:
        print("[策略2] nodriver 未安装, 跳过")
        return {"success": False}

    print("[策略2] 启动 nodriver (Chrome CDP, headless)...")
    try:
        result = _run_nodriver_fetch(url, wait=5)
        if not result.get("success"):
            print("[策略2] nodriver 抓取失败")
            return {"success": False}

        html = result["html"]
        if not _has_real_content(html):
            print(f"[策略2] 页面无有效内容 (长度 {len(html)})")
            return {"success": False}

        article = extract_article_from_html(html)
        if not article["body_html"]:
            print("[策略2] 提取正文失败")
            return {"success": False}

        article = download_images(article, output_dir)
        md = html_to_markdown_simple(article)
        md += "\n\n> 获取方式: nodriver (Chrome CDP headless)"
        out_file = output_dir / f"{article['title'] or 'article'}.md"
        out_file.write_text(md, encoding="utf-8")
        print(f"[策略2] 成功! 标题: {article['title']}")
        print(f"  作者: {article['author']}, 时间: {article['publish_time']}")
        print(f"  图片: {len(article['images'])}张, 视频: {len(article.get('videos', []))}个")
        print(f"  输出: {out_file}")
        return {"success": True, "strategy": "nodriver", "file": str(out_file), "article": article}
    except Exception as e:
        print(f"[策略2] 异常: {e}")
    return {"success": False}


def strategy_camoufox(url: str, output_dir: Path) -> dict:
    """策略3: Camoufox反检测浏览器（最可靠，需安装 wechat-article-to-markdown）"""
    print("[策略3] 启动 Camoufox 反检测浏览器...")
    try:
        env = os.environ.copy()
        env["PYTHONIOENCODING"] = "utf-8"
        env["PYTHONUTF8"] = "1"
        result = subprocess.run(
            ["wechat-article-to-markdown", url],
            capture_output=True, text=True, timeout=120, env=env,
            encoding="utf-8", errors="replace",
            cwd=str(output_dir)
        )
        if result.returncode == 0:
            print("[策略3] 抓取成功!")
            # 工具硬编码输出到 output/ 子目录（忽略 -o 参数）
            tool_out = output_dir / "output"
            search_dir = tool_out if tool_out.is_dir() else output_dir
            for f in search_dir.rglob("*.md"):
                return {"success": True, "strategy": "camoufox", "file": str(f)}
        print(f"[策略3] 命令执行失败: {result.stderr[:200]}")
    except FileNotFoundError:
        print("[策略3] wechat-article-to-markdown 未安装, 跳过")
    except subprocess.TimeoutExpired:
        print("[策略3] 超时（120秒）")
    except Exception as e:
        print(f"[策略3] 异常: {e}")
    return {"success": False}


def strategy_search_cache(url: str, output_dir: Path) -> dict:
    """策略4: 搜索引擎缓存（最后手段，内容可能不完整）"""
    print("[策略4] 尝试搜索引擎缓存...")
    # 尝试通过搜狗微信搜索缓存
    search_url = f"https://weixin.sogou.com/weixin?type=2&query={url}"
    html, status, ok = fetch_with_ua(search_url, NORMAL_UA, timeout=10)
    if ok:
        # 提取搜索结果中的缓存链接
        m = re.search(r'href="(https?://mp\.weixin\.qq\.com/s/[^"]+)"', html)
        if m:
            cache_url = m.group(1)
            html2, status2, ok2 = fetch_with_ua(cache_url, WECHAT_UA)
            if ok2:
                article = extract_article_from_html(html2)
                if article["body_html"]:
                    article = download_images(article, output_dir)
                    md = html_to_markdown_simple(article)
                    md += "\n\n> 注意: 此内容通过搜索引擎缓存获取，可能不完整"
                    out_file = output_dir / f"{article['title'] or 'article'}.md"
                    out_file.write_text(md, encoding="utf-8")
                    print(f"[策略4] 缓存获取成功: {article['title']}")
                    return {"success": True, "strategy": "search_cache", "file": str(out_file)}
    print("[策略4] 搜索引擎缓存未命中")
    return {"success": False}


# ── 主入口 ────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="微信公众号文章智能抓取工具 v4.0")
    parser.add_argument("url", help="微信文章URL")
    parser.add_argument("-o", "--output", default=None, help="输出目录（默认当前目录）")
    args = parser.parse_args()

    url = normalize_url(args.url)
    output_dir = Path(args.output) if args.output else Path(".")
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"=== 微信公众号文章智能抓取 v4.0 ===")
    print(f"URL: {url}")
    print(f"输出: {output_dir.absolute()}")
    print()

    # 按优先级依次尝试（4级降级链）
    strategies = [
        strategy_ua,
        strategy_nodriver,
        strategy_camoufox,
        strategy_search_cache,
    ]

    for strategy in strategies:
        result = strategy(url, output_dir)
        if result.get("success"):
            print()
            print(f"=== 完成! 使用策略: {result['strategy']} ===")
            print(f"文件: {result['file']}")
            # 输出JSON供调用方解析
            print(f"RESULT_JSON:{json.dumps(result, ensure_ascii=False)}")
            return 0

    print()
    print("=== 所有策略均失败 ===")
    print("建议:")
    print("  1. 确认URL是否为有效的公开微信文章链接")
    print("  2. 安装 wechat-article-to-markdown: uv tool install wechat-article-to-markdown")
    print("  3. 检查网络连接是否正常")
    print("  4. 如持续失败，可能是微信升级了反爬策略，等待工具更新")
    return 1


if __name__ == "__main__":
    sys.exit(main())
```

---

## 五、使用方法

### 5.1 命令行调用

```bash
# 基本用法
python wechat_fetcher.py "https://mp.weixin.qq.com/s/xxx"

# 指定输出目录
python wechat_fetcher.py "https://mp.weixin.qq.com/s/xxx" -o "C:\Articles"

# Windows 环境（确保 UTF-8）
set PYTHONIOENCODING=utf-8
set PYTHONUTF8=1
python wechat_fetcher.py "https://mp.weixin.qq.com/s/xxx" -o "output"
```

### 5.2 程序化调用

```python
from wechat_fetcher import normalize_url, strategy_ua, strategy_nodriver
from pathlib import Path

url = normalize_url("https://mp.weixin.qq.com/s/xxx")
output_dir = Path("output")
output_dir.mkdir(exist_ok=True)

# 直接调用某个策略
result = strategy_ua(url, output_dir)
if result["success"]:
    print(f"成功: {result['file']}")
else:
    # 降级到下一个策略
    result = strategy_nodriver(url, output_dir)
```

### 5.3 输出格式

脚本输出 Markdown 文件 + JSON 结果：

```
output/
├── 文章标题.md          # Markdown 正文
└── images/             # 下载的图片（自动替换正文中的链接）
    ├── img_001.png
    ├── img_002.jpg
    └── ...
```

JSON 结果（stdout 最后一行，`RESULT_JSON:` 前缀）：

```json
{
  "success": true,
  "strategy": "ua",
  "file": "output/文章标题.md",
  "article": {
    "title": "文章标题",
    "author": "公众号名称",
    "publish_time": "2026-06-25 10:30:00",
    "body_html": "...",
    "images": ["https://...", "..."],
    "videos": []
  }
}
```

---

## 六、关键技术细节

### 6.1 微信图片防盗链

微信图片服务器（`mmbiz.qpic.cn`、`mmecoa.qpic.cn`、`mmebiz.qpic.cn`）要求 `Referer: https://mp.weixin.qq.com/`，否则返回 403。

**解决方案**：`download_images()` 函数带 Referer 头逐张下载，并替换正文中的远程 URL 为本地相对路径。

### 6.2 懒加载图片提取

微信文章图片使用 `data-src` 属性懒加载，而非标准 `src`。正则匹配：

```python
r'data-src="(https?://(?:mmbiz|mmecoa|mmebiz)\.qpic\.cn/[^"]+)"'
```

### 6.3 URL 参数清理

微信文章 URL 包含大量追踪参数（scene、subscene、sessionid 等），需清理后使用：

```python
patterns = [
    r'(&|\?)(scene|subscene|sessionid|clicktime|ascene|devicetype|version|lang|nettype|abtest_cookie|exportkey|pass_ticket|wx_header|plat_id|mpshare|from|isappinstalled)=[^&]*',
]
```

### 6.4 内容验证（区分真实文章 vs 验证页）

```python
def _has_real_content(html: str) -> bool:
    return (
        "js_content" in html           # 核心 DOM 节点
        and "环境异常" not in html      # 验证页特征
        and "请完成下方验证" not in html
        and "操作过于频繁" not in html
        and len(html) > 5000            # 验证页通常很短
    )
```

---

## 七、已知问题与修复

### 7.1 UBO 扩展下载失败（Camoufox）

网络问题导致 uBlock Origin 下载失败（HTTP 451），留下空 UBO/ 目录。

```bash
rmdir "C:\Users\<user>\AppData\Local\camoufox\camoufox\Cache\addons\UBO"
```

### 7.2 nodriver Python 3.14 兼容性

`nodriver/cdp/network.py` 中存在 Latin-1 编码的 `±Inf` 字符，需 binary replace 修补。

### 7.3 部分文章 UA 伪装失效

少数文章启用了增强检测，curl_cffi 全指纹伪装仍会触发验证页，此时自动降级到 nodriver 或 Camoufox。

---

## 八、限制

- 仅支持公开 `mp.weixin.qq.com` 链接（需登录/付费的文章无法抓取）
- SVG 渲染的代码块无法提取为源码
- 视频仅提取 URL，无法直接下载视频文件
- 图片防盗链：需下载到本地或加 Referer 头
- UA 伪装对部分增强检测的文章可能失效
- nodriver 需本地安装 Chrome/Chromium
- Camoufox 首次运行需下载浏览器（~150MB）

---

## 九、验证标准

成功的文章抓取应满足：

- [ ] 输出 `.md` 含完整标题、作者、时间、原文链接
- [ ] 正文无截断、无验证页残留
- [ ] 图片链接完整（含 data-src 懒加载图片）
- [ ] 视频链接已记录
- [ ] 代码块格式保留

---

## 十、与其他平台的差异

| 平台 | 方案 | 原理 |
|---|---|---|
| **WorkBuddy** | 腾讯内部 API | 生态特权，走微信授权接口 |
| **DeepSeek** | 搜索引擎缓存 | 搜狗/Bing 已索引的副本 |
| **QoderWork** | 本地反检测 | 用户 IP + curl_cffi/nodriver/Camoufox |

---

## 十一、故障排查

### 所有策略均失败

1. 确认 URL 是否为有效的公开微信文章链接（在浏览器中能否正常打开）
2. 检查 `curl_cffi` 是否安装（`pip list | grep curl_cffi`）
3. 检查网络连接是否正常（能否访问 `mp.weixin.qq.com`）
4. 查看控制台输出，确认每级策略的失败原因
5. 如持续失败，可能是微信升级了反爬策略，等待工具更新

### 图片下载失败

- 检查 `Referer` 头是否正确（必须为 `https://mp.weixin.qq.com/`）
- 部分图片可能已过期或被删除，保留远程 URL 作为兜底

### 编码错误

- Windows 上确保设置 `PYTHONIOENCODING=utf-8` 和 `PYTHONUTF8=1`
- 或在脚本开头添加 `sys.stdout.reconfigure(encoding="utf-8", errors="replace")`

---

## 十二、参考资料

- **curl_cffi 文档**：https://github.com/yifeikong/curl_cffi
- **nodriver 文档**：https://github.com/ultrafunkamsterdam/nodriver
- **Camoufox**：https://github.com/daijro/camoufox
- **微信反爬机制分析**：TLS 指纹（JA4/JA3）+ UA 双重校验

---

**文档版本**：v4.0.0  
**最后更新**：2026-06-25  
**维护者**：QoderWork  
**许可**：仅供技术研究与合法使用
