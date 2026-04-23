#!/bin/bash
set -e

INSTALL_DIR=/opt/ComfyUI

if [ -d "$INSTALL_DIR/.venv" ]; then
    echo "ComfyUI is already installed at $INSTALL_DIR"
    exit 0
fi

echo "Installing ComfyUI..."

git clone https://github.com/comfyanonymous/ComfyUI.git "$INSTALL_DIR" 2>/dev/null || true
cd "$INSTALL_DIR"

uv venv --python 3 --seed .venv
VIRTUAL_ENV="$INSTALL_DIR/.venv" uv pip install \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
VIRTUAL_ENV="$INSTALL_DIR/.venv" uv pip install -r requirements.txt

git clone https://github.com/ltdrdata/ComfyUI-Manager.git \
    "$INSTALL_DIR/custom_nodes/ComfyUI-Manager" 2>/dev/null || true

echo "ComfyUI installed successfully."
