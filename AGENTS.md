# Workspace Guidelines for AI Agents

## /workspace Directory Purpose

`/workspace` is a **persistent volume** mounted to this Runpod/Vast.ai instance. It should only contain:

- **Intermediate products** — training checkpoints, generated samples, preprocessed data
- **Final products** — trained models (LoRA, checkpoints, etc.), inference outputs, exported assets

**Do NOT store** caches, temp files, pip/npm caches, open source models, or build artifacts here. Use `/tmp` or
tool-specific cache directories (e.g., `HF_HOME`, `COMFYUI_TEMP_DIR`) instead.

## Folder Organization

Keep things tidy. Never dump files flat in `/workspace`. Use structured subdirectories:

```
/workspace/
  training/
    <project-name>/
      config.yaml                  # training config
      checkpoints/
        checkpoint_500/            # organized by step
        checkpoint_1000/
        checkpoint_1500/
      logs/                        # tensorboard / training logs
      samples/                     # intermediate samples for review
      final/                       # final exported model
  inference/
    <project-name>/
      inputs/                      # input images / prompts
      outputs/                     # generated results
        batch_001/
        batch_002/
  models/                          # shared pre-trained models / LoRAs
```

This structure makes it easy to compare checkpoints, review progress, and clean up.

## Pre-installed Tools

### ComfyUI

- **Install**: `install-comfyui` (on-demand, idempotent — safe to re-run)
- **Run**: `comfyui --port 8188 --listen 127.0.0.1`
- **Location**: `/opt/ComfyUI` (with isolated `.venv`)
- If already installed, it auto-starts on port 8188 via pm2

### AI Toolkit

- **Install**: `install-ai-toolkit` (on-demand, idempotent — safe to re-run)
- **Run**: `ai-toolkit`
- **Location**: `/opt/ai-toolkit` (with isolated `.venv`)
- If already installed, its UI auto-starts on port 8675 via pm2

### Installing Additional Tools

Follow the same pattern as the existing install scripts:

1. Clone the repo to `/opt/<tool-name>`
2. Create an isolated venv: `uv venv --python 3 --seed .venv`
3. Install PyTorch with CUDA: `uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128`
4. Install tool-specific dependencies: `uv pip install -r requirements.txt`
5. Create a CLI wrapper in `/usr/local/bin/` if needed

Use `uv` (not pip) for all package management. Keep each tool in its own venv.

## Progress Reporting

When running training or inference jobs, report progress **every 2 minutes**. Each report
should include:

- **Current step / total steps** (and estimated time remaining)
- **Loss** (training loss, validation loss if available)
- **Key metrics** — learning rate, gradient norm, GPU memory usage, samples/sec
- **Any anomalies** — loss spikes, NaN values, OOM warnings

Example format:

```
[Step 1500/10000 | 15.0%] ETA: 42min
  loss: 0.0234 | lr: 1e-4 | grad_norm: 0.82
  GPU mem: 22.1/24.0 GB | speed: 3.2 it/s
```

## Other Notes

- Access services via SSH port forwarding (services bind to localhost only)
- Use `pm2 list` to check running services, `pm2 logs <name>` for logs
- The container env vars are saved to `/opt/runpod/container.env`
