ARG BUILD_TYPE=gpu

FROM nvidia/cuda:12.8.1-devel-ubuntu24.04 AS base-gpu
FROM ubuntu:24.04 AS base-cpu
FROM base-${BUILD_TYPE} AS final
ARG BUILD_TYPE

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV COLORTERM=truecolor
ENV LANG=en_US.UTF-8
ENV BUILD_TYPE=${BUILD_TYPE}

# =============================================================================
# System packages
# =============================================================================
# Refresh NVIDIA repo GPG key (base image key may be expired)
RUN if [ "$BUILD_TYPE" = "gpu" ]; then \
    rm -f /etc/apt/sources.list.d/cuda*.list \
    && apt-key del 7fa2af80 2>/dev/null || true \
    && apt-get update -o Acquire::AllowInsecureRepositories=true \
    && apt-get install -y --allow-unauthenticated ca-certificates curl \
    && curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb -o /tmp/cuda-keyring.deb \
    && dpkg -i /tmp/cuda-keyring.deb \
    && rm /tmp/cuda-keyring.deb \
    && rm -rf /var/lib/apt/lists/*; \
    fi

RUN apt-get update && apt-get install -y \
    aria2 \
    build-essential \
    curl \
    ffmpeg \
    file \
    git \
    git-lfs \
    htop \
    iproute2 \
    jq \
    locales \
    ncurses-term \
    net-tools \
    openssh-server \
    procps \
    rsync \
    sudo \
    tmux \
    unzip \
    vim \
    wget \
    zip \
    zsh \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen

# =============================================================================
# SSH
# =============================================================================
RUN sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config

RUN chsh -s /bin/zsh root

WORKDIR /root

# =============================================================================
# Dev toolchain: Node.js, Go, uv, Python venv, PM2, lazygit
# =============================================================================
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://go.dev/dl/go1.24.2.linux-amd64.tar.gz | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:${PATH}"

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

RUN uv venv --python 3 --seed ~/.venv
ENV VIRTUAL_ENV="/root/.venv"
ENV PATH="/root/.venv/bin:${PATH}"

RUN npm i -g pm2

RUN LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*') \
    && curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" \
    && tar xf lazygit.tar.gz lazygit \
    && install lazygit /usr/local/bin/ \
    && rm lazygit lazygit.tar.gz

RUN FZF_VERSION=$(curl -s "https://api.github.com/repos/junegunn/fzf/releases/latest" | grep -Po '"tag_name": "v?\K[^"]*') \
    && curl -Lo fzf.tar.gz "https://github.com/junegunn/fzf/releases/latest/download/fzf-${FZF_VERSION}-linux_amd64.tar.gz" \
    && tar xf fzf.tar.gz fzf \
    && install fzf /usr/local/bin/ \
    && rm fzf fzf.tar.gz

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install kubectl /usr/local/bin/ \
    && rm kubectl

RUN K9S_VERSION=$(curl -s "https://api.github.com/repos/derailed/k9s/releases/latest" | grep -Po '"tag_name": "\K[^"]*') \
    && curl -Lo k9s.tar.gz "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz" \
    && tar xf k9s.tar.gz k9s \
    && install k9s /usr/local/bin/ \
    && rm k9s k9s.tar.gz

# =============================================================================
# PyTorch
# =============================================================================
RUN if [ "$BUILD_TYPE" = "gpu" ]; then \
    uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128; \
    else \
    uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu; \
    fi

# Hugging Face ecosystem
RUN uv pip install \
    "huggingface_hub[cli]" \
    transformers \
    datasets \
    accelerate \
    peft \
    diffusers \
    safetensors \
    tokenizers \
    sentencepiece

# ML tools & training
RUN uv pip install \
    tensorboard \
    wandb \
    scipy \
    scikit-learn

# GPU-only ML packages
RUN if [ "$BUILD_TYPE" = "gpu" ]; then \
    uv pip install bitsandbytes xformers; \
    fi

# =============================================================================
# ComfyUI (GPU only)
# =============================================================================
RUN if [ "$BUILD_TYPE" = "gpu" ]; then \
    git clone https://github.com/comfyanonymous/ComfyUI.git /opt/ComfyUI \
    && cd /opt/ComfyUI \
    && uv pip install -r requirements.txt \
    && git clone https://github.com/ltdrdata/ComfyUI-Manager.git /opt/ComfyUI/custom_nodes/ComfyUI-Manager; \
    fi

# Image & video processing (after ComfyUI to override its opencv-python with headless)
RUN uv pip install \
    opencv-python-headless \
    imageio \
    imageio-ffmpeg \
    pillow \
    tqdm \
    requests \
    pandas

# =============================================================================
# Monitoring: glances
# =============================================================================
RUN if [ "$BUILD_TYPE" = "gpu" ]; then \
    uv pip install "glances[gpu]"; \
    else \
    uv pip install glances; \
    fi

# =============================================================================
# code-server
# =============================================================================
RUN curl -fsSL https://code-server.dev/install.sh | sh

# =============================================================================
# Claude Code (installs to ~/.local/bin and ~/.claude, no custom dir support)
# =============================================================================
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/root/.local/bin:/root/.claude/bin:${PATH}"

# =============================================================================
# User config & environment
# =============================================================================
RUN curl -sSL dot.yiwei.dev | bash

# Welcome message
COPY motd.sh /opt/runpod/motd.sh
RUN chmod +x /opt/runpod/motd.sh

# Auto-attach to tmux "runpod" session on SSH login; exit SSH on detach
RUN echo 'if [ -n "$SSH_CONNECTION" ] && [ -z "$TMUX" ]; then' >> /root/.zprofile \
    && echo '    tmux new-session -A -s runpod 2>/dev/null' >> /root/.zprofile \
    && echo '    clear && exit' >> /root/.zprofile \
    && echo 'fi'  >> /root/.zprofile

# Show motd once inside tmux (via .zshrc since tmux shells are non-login)
RUN echo '[ -n "$TMUX" ] && [ -z "$MOTD_SHOWN" ] && export MOTD_SHOWN=1 && /opt/runpod/motd.sh' >> /root/.zshrc.local

# Source container env vars (written by entrypoint) in all zsh sessions
RUN echo '[ -f /opt/runpod/container.env ] && source /opt/runpod/container.env' >> /root/.zshenv

# =============================================================================
# Entrypoint
# =============================================================================
COPY entrypoint.sh /opt/runpod/entrypoint.sh
RUN chmod +x /opt/runpod/entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/opt/runpod/entrypoint.sh"]
