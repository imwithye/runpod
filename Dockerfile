FROM nvidia/cuda:12.8.1-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV COLORTERM=truecolor
ENV LANG=C.UTF-8

# =============================================================================
# System packages
# =============================================================================
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    file \
    git \
    locales \
    ncurses-term \
    openssh-server \
    procps \
    sudo \
    tmux \
    vim \
    wget \
    zsh \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd

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

# =============================================================================
# ComfyUI
# =============================================================================
RUN uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# Hugging Face ecosystem
RUN uv pip install \
    huggingface_hub \
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
    bitsandbytes \
    xformers \
    tensorboard \
    wandb \
    scipy \
    scikit-learn

# Image & video processing
RUN uv pip install \
    opencv-python-headless \
    imageio \
    imageio-ffmpeg \
    pillow

RUN git clone https://github.com/comfyanonymous/ComfyUI.git /opt/ComfyUI \
    && cd /opt/ComfyUI \
    && uv pip install -r requirements.txt

RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git /opt/ComfyUI/custom_nodes/ComfyUI-Manager

# =============================================================================
# Monitoring: Netdata, glances
# =============================================================================
RUN curl -fsSL https://get.netdata.cloud/kickstart.sh > /tmp/netdata-kickstart.sh \
    && sh /tmp/netdata-kickstart.sh --non-interactive --dont-wait --dont-start-it --disable-telemetry \
    && rm /tmp/netdata-kickstart.sh

RUN uv pip install glances[gpu]

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
    && echo '    tmux new-session -A -s runpod' >> /root/.zprofile \
    && echo '    exit' >> /root/.zprofile \
    && echo 'fi'  >> /root/.zprofile

# Show motd once inside tmux (via .zshrc since tmux shells are non-login)
RUN echo '[ -n "$TMUX" ] && [ -z "$MOTD_SHOWN" ] && export MOTD_SHOWN=1 && /opt/runpod/motd.sh' >> /root/.zshrc.local

RUN echo "VIRTUAL_ENV=/root/.venv" >> /etc/environment \
    && echo "PATH=/root/.venv/bin:/root/.local/bin:/root/.claude/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" >> /etc/environment

# =============================================================================
# Entrypoint
# =============================================================================
COPY entrypoint.sh /opt/runpod/entrypoint.sh
RUN chmod +x /opt/runpod/entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/opt/runpod/entrypoint.sh"]
