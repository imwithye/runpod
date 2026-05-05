# Workspace Guidelines for AI Agents

## Disk Layout

```
/          — System root (ephemeral, lost on restart)
├── /opt/  — Pre-installed tools & repos
├── /root/ — Model downloads, caches (HF_HOME, pip/npm cache, etc.)
└── /workspace/  — Persistent volume (survives restarts)
```

## Keep Files Organized

Every operation should leave the workspace tidier than you found it. Before and after any task:

- Put outputs in the correct project subdirectory
- Never dump files flat — always use structured paths
- Clean up temp/intermediate files when done
- Name files descriptively (include step number, date, or config name)

## tmux Usage

You are running inside a tmux session. Use tmux for all background tasks:

```bash
# Start a background task in a new tmux session
tmux new-session -d -s task-<name> '<command>'

# Send keys to an existing session
tmux send-keys -t task-<name> '<command>' Enter

# Monitor output
tmux capture-pane -t task-<name> -p

# List sessions
tmux list-sessions
```

Do NOT use `nohup`, `&`, or `disown`. Always use tmux so tasks are observable and controllable.

## Pre-installed Tools

### ComfyUI

- **Install**: `install-comfyui` (idempotent)
- **Run**: `comfyui --port 8188 --listen 127.0.0.1`
- **Location**: `/opt/ComfyUI` (isolated `.venv`)

### AI Toolkit

- **Install**: `install-ai-toolkit` (idempotent)
- **Run**: `ai-toolkit`
- **Location**: `/opt/ai-toolkit` (isolated `.venv`)

### Installing Additional Tools

1. Clone to `/opt/<tool-name>`
2. Create venv: `uv venv --python 3 --seed .venv`
3. Install PyTorch+CUDA: `uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128`
4. Install deps: `uv pip install -r requirements.txt`
5. Add CLI wrapper to `/usr/local/bin/` if needed

Use `uv` (not pip). Keep each tool in its own venv.

## Other Notes

- Access services via SSH port forwarding (services bind to localhost only)
- Use `pm2 list` to check running services, `pm2 logs <name>` for logs
