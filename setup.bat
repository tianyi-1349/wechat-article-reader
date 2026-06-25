@echo off
REM wechat-article-reader - Windows Setup Script
REM Usage: setup.bat

echo === wechat-article-reader Setup ===
echo.

REM Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python not found. Please install Python 3.8+
    exit /b 1
)

REM Create virtual environment
if not exist ".venv" (
    echo [1/4] Creating virtual environment...
    python -m venv .venv
    echo   Virtual environment created at .venv\
) else (
    echo [1/4] Virtual environment already exists, skipping...
)

REM Activate virtual environment
call .venv\Scripts\activate.bat

REM Install core dependency
echo [2/4] Installing core dependency (curl_cffi)...
pip install --quiet curl_cffi>=0.7.0
echo   curl_cffi installed (Strategy 1 enabled)

REM Install optional dependency: nodriver
echo [3/4] Installing optional dependency (nodriver)...
pip install --quiet nodriver 2>nul
if errorlevel 1 (
    echo   nodriver skipped (Strategy 2 disabled, non-critical)
) else (
    echo   nodriver installed (Strategy 2 enabled)
)

REM Check for Camoufox CLI tool
echo [4/4] Checking Camoufox CLI tool...
where wechat-article-to-markdown >nul 2>&1
if errorlevel 1 (
    echo   wechat-article-to-markdown not found.
    echo   To enable Strategy 3, run: uv tool install wechat-article-to-markdown
    echo   (Strategy 3 is the fallback, most articles work with Strategy 1)
) else (
    echo   wechat-article-to-markdown found (Strategy 3 enabled)
)

echo.
echo === Setup Complete ===
echo.
echo Usage:
echo   .venv\Scripts\activate
echo   set PYTHONIOENCODING=utf-8
echo   set PYTHONUTF8=1
echo   python wechat_fetcher.py "https://mp.weixin.qq.com/s/xxx" -o output
echo.
echo Quick test:
echo   python -c "from curl_cffi import requests; print('curl_cffi OK')"
