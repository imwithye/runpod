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

# =============================================================================
# SSH
# =============================================================================
SSH_KEY="${PUBLIC_KEY:-$SSH_PUBLIC_KEY}"
if [ -n "$SSH_KEY" ]; then
    mkdir -p /root/.ssh
    echo "$SSH_KEY" > /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
fi

if [ -n "$USER_PASSWORD" ]; then
    echo "root:$USER_PASSWORD" | chpasswd
fi

# =============================================================================
# Export container env vars for SSH sessions
# =============================================================================
env | grep -vE '^(HOME=|USER=|SHELL=|TERM=|SHLVL=|PWD=|_=|HOSTNAME=)' \
    | sed 's/"/\\"/g; s/\(.*\)=\(.*\)/export \1="\2"/' \
    > /opt/runpod/container.env

# =============================================================================
# Workspace persistence — Claude Code
# =============================================================================
WORKSPACE=/workspace
mkdir -p $WORKSPACE
ln -sfn $WORKSPACE /root/workspace

# ~/.claude/ (credentials, projects, todos)
if [ -d "$HOME/.claude" ] && [ ! -L "$HOME/.claude" ]; then
    if [ -z "$(ls -A $WORKSPACE/.claude 2>/dev/null)" ]; then
        mkdir -p $WORKSPACE/.claude
        mv $HOME/.claude/* $WORKSPACE/.claude/ 2>/dev/null || true
        mv $HOME/.claude/.* $WORKSPACE/.claude/ 2>/dev/null || true
    fi
    rm -rf $HOME/.claude
fi
safe_symlink $WORKSPACE/.claude $HOME/.claude

# ~/.claude.json (MCP servers, project trust, onboarding state)
if [ -f "$HOME/.claude.json" ] && [ ! -L "$HOME/.claude.json" ]; then
    if [ ! -f "$WORKSPACE/.claude.json" ]; then
        mv "$HOME/.claude.json" "$WORKSPACE/.claude.json"
    else
        rm -f "$HOME/.claude.json"
    fi
fi
if [ ! -f "$WORKSPACE/.claude.json" ]; then
    echo '{"hasCompletedOnboarding":true,"theme":"auto"}' > "$WORKSPACE/.claude.json"
fi
ln -sf "$WORKSPACE/.claude.json" "$HOME/.claude.json"

# =============================================================================
# Workspace persistence — ComfyUI
# =============================================================================
safe_symlink $WORKSPACE/comfyui/user /opt/ComfyUI/user
safe_symlink $WORKSPACE/comfyui/input /opt/ComfyUI/input
safe_symlink $WORKSPACE/comfyui/output /opt/ComfyUI/output

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

# =============================================================================
# Start services (localhost only, access via SSH port forwarding)
# =============================================================================
pm2 delete comfyui-8188 >/dev/null 2>&1 || true
pm2 start "python main.py --port 8188 --listen 127.0.0.1" \
    --name comfyui-8188 \
    --cwd /opt/ComfyUI

pm2 delete code-server-8080 >/dev/null 2>&1 || true
pm2 start "code-server --bind-addr 127.0.0.1:8080 --auth none /workspace" \
    --name code-server-8080

exec /usr/sbin/sshd -D
