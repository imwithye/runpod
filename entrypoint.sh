#!/bin/bash
set -e

safe_symlink() {
    local src=$1
    local dst=$2
    mkdir -p "$src"
    if [ -L "$dst" ]; then
        if [ "$(readlink "$dst")" = "$src" ]; then
            return 0
        fi
        rm "$dst"
    elif [ -e "$dst" ]; then
        rm -rf "$dst"
    fi
    ln -s "$src" "$dst"
}

# Set up SSH public key (RunPod: PUBLIC_KEY, Vast.ai: SSH_PUBLIC_KEY)
SSH_KEY="${PUBLIC_KEY:-$SSH_PUBLIC_KEY}"
if [ -n "$SSH_KEY" ]; then
    mkdir -p /root/.ssh
    echo "$SSH_KEY" > /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
fi

# Set password if provided
if [ -n "$USER_PASSWORD" ]; then
    echo "root:$USER_PASSWORD" | chpasswd
fi

# ---------- /workspace persistence ----------
WORKSPACE=/workspace
mkdir -p $WORKSPACE

# Claude Code: ~/.claude/ directory (credentials, projects, todos)
if [ -d "$HOME/.claude" ] && [ ! -L "$HOME/.claude" ]; then
    if [ -z "$(ls -A $WORKSPACE/claude 2>/dev/null)" ]; then
        mkdir -p $WORKSPACE/claude
        mv $HOME/.claude/* $WORKSPACE/claude/ 2>/dev/null || true
        mv $HOME/.claude/.* $WORKSPACE/claude/ 2>/dev/null || true
    fi
    rm -rf $HOME/.claude
fi
safe_symlink $WORKSPACE/claude $HOME/.claude

# Claude Code: ~/.claude.json file (MCP servers, project trust, onboarding state)
if [ -f "$HOME/.claude.json" ] && [ ! -L "$HOME/.claude.json" ]; then
    if [ ! -f "$WORKSPACE/claude.json" ]; then
        mv "$HOME/.claude.json" "$WORKSPACE/claude.json"
    else
        rm -f "$HOME/.claude.json"
    fi
fi
if [ ! -f "$WORKSPACE/claude.json" ]; then
    echo '{"hasCompletedOnboarding":true,"theme":"auto"}' > "$WORKSPACE/claude.json"
fi
ln -sf "$WORKSPACE/claude.json" "$HOME/.claude.json"

# ComfyUI user data (settings, saved workflows)
safe_symlink $WORKSPACE/comfyui/user /opt/ComfyUI/user

# ComfyUI input/output folders
safe_symlink $WORKSPACE/comfyui/input /opt/ComfyUI/input
safe_symlink $WORKSPACE/comfyui/output /opt/ComfyUI/output

# ComfyUI models
mkdir -p $WORKSPACE/comfyui/models/{checkpoints,loras,vae,clip,controlnet,upscale_models,embeddings}

cat > /opt/ComfyUI/extra_model_paths.yaml <<EOF
workspace:
    base_path: $WORKSPACE/comfyui/models
    checkpoints: checkpoints/
    loras: loras/
    vae: vae/
    clip: clip/
    controlnet: controlnet/
    upscale_models: upscale_models/
    embeddings: embeddings/
EOF

# ---------- Start ComfyUI via PM2 ----------
pm2 delete comfyui >/dev/null 2>&1 || true
pm2 start "python main.py --port 8188 --listen 0.0.0.0" \
    --name comfyui \
    --cwd /opt/ComfyUI

# Start SSH daemon and keep container alive
exec /usr/sbin/sshd -D
