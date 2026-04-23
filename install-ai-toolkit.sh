#!/bin/bash
set -e

INSTALL_DIR=/opt/ai-toolkit

if [ -d "$INSTALL_DIR/.venv" ]; then
    echo "AI Toolkit is already installed at $INSTALL_DIR"
    exit 0
fi

echo "Installing AI Toolkit..."

git clone https://github.com/ostris/ai-toolkit.git "$INSTALL_DIR" 2>/dev/null || true
cd "$INSTALL_DIR"
git submodule update --init --recursive

uv venv --python 3 --seed .venv
VIRTUAL_ENV="$INSTALL_DIR/.venv" uv pip install \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
VIRTUAL_ENV="$INSTALL_DIR/.venv" uv pip install -r requirements.txt

cd "$INSTALL_DIR/ui" && npm install && npm run build

echo "AI Toolkit installed successfully."
