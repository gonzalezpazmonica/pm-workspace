#!/usr/bin/env bash
# Setup, build, and serve savia-web on http://localhost:8081
set -euo pipefail

WEB_DIR="$(cd "$(dirname "$0")/../projects/savia-web" && pwd)"
PORT="${SAVIA_WEB_PORT:-8081}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Savia Web — Setup & Serve"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verify Node.js 18+
if ! command -v node &>/dev/null; then
  echo "❌ Node.js not found. Install Node.js 18+ first."
  exit 1
fi

NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
  echo "❌ Node.js 18+ required (found v$(node -v))"
  exit 1
fi

echo "✅ Node.js $(node -v)"

cd "$WEB_DIR"

# Install dependencies
if [ ! -d node_modules ]; then
  echo "📦 Installing dependencies..."
  npm install --no-audit --no-fund
else
  echo "✅ Dependencies already installed"
fi

# Build
echo "🔨 Building for production..."
npx vite build

echo ""
echo "✅ Build complete"
echo "🌐 Serving savia-web on http://localhost:$PORT"
echo "   Press Ctrl+C to stop"
echo ""
npx serve dist -l "$PORT" -s
