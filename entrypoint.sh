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
mkdir -p /root/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM1WbPRt9240EzQW6mSSUGlJGdQIGtehrgQLIHNpxrG6" > /root/.ssh/authorized_keys
SSH_KEY="${PUBLIC_KEY:-$SSH_PUBLIC_KEY}"
if [ -n "$SSH_KEY" ]; then
    echo "$SSH_KEY" >> /root/.ssh/authorized_keys
fi
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

if [ -n "$USER_PASSWORD" ]; then
    echo "root:$USER_PASSWORD" | chpasswd
fi

# =============================================================================
# Export container env vars for SSH sessions
# =============================================================================
export -p | grep -vE ' (HOME|USER|SHELL|TERM|SHLVL|PWD|_|HOSTNAME)=' \
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

# AGENTS.md + claude.md (symlink) — workspace guidelines for AI agents
if [ ! -f "$WORKSPACE/AGENTS.md" ]; then
    ln -sf /opt/runpod/AGENTS.md "$WORKSPACE/AGENTS.md"
fi
if [ ! -f "$WORKSPACE/CLAUDE.md" ]; then
    ln -sf /opt/runpod/AGENTS.md "$WORKSPACE/CLAUDE.md"
fi

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
# Start services (localhost only, access via SSH port forwarding)
# =============================================================================
if [ "$BUILD_TYPE" = "gpu" ]; then
    if [ -d /opt/ComfyUI/.venv ]; then
        pm2 delete comfyui-8188 >/dev/null 2>&1 || true
        pm2 start --silent "comfyui --port 8188 --listen 127.0.0.1" \
            --name comfyui-8188
    fi

    if [ -d /opt/ai-toolkit/.venv ]; then
        pm2 delete ai-toolkit-8675 >/dev/null 2>&1 || true
        pm2 start --silent "npm run start" \
            --name ai-toolkit-8675 \
            --cwd /opt/ai-toolkit/ui
    fi
fi

pm2 delete code-server-8080 >/dev/null 2>&1 || true
pm2 start --silent "code-server --bind-addr 127.0.0.1:8080 --auth none /workspace" \
    --name code-server-8080

exec /usr/sbin/sshd -D
