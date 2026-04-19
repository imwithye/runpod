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
    fzf \
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

RUN UV_INSTALL_DIR=/opt/uv curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/opt/uv:${PATH}"

RUN uv venv --python 3 /opt/venv
ENV VIRTUAL_ENV="/opt/venv"
ENV PATH="/opt/venv/bin:${PATH}"

RUN npm i -g pm2

RUN LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*') \
    && curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" \
    && tar xf lazygit.tar.gz lazygit \
    && install lazygit /usr/local/bin/ \
    && rm lazygit lazygit.tar.gz

# =============================================================================
# ComfyUI
# =============================================================================
RUN uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

RUN git clone https://github.com/comfyanonymous/ComfyUI.git /opt/ComfyUI \
    && cd /opt/ComfyUI \
    && uv pip install -r requirements.txt

RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git /opt/ComfyUI/custom_nodes/ComfyUI-Manager

# =============================================================================
# Claude Code (installs to ~/.local/bin and ~/.claude, no custom dir support)
# =============================================================================
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/root/.local/bin:/root/.claude/bin:${PATH}"

# =============================================================================
# User config & environment
# =============================================================================
RUN curl -sSL dot.yiwei.dev | bash

RUN echo "VIRTUAL_ENV=/opt/venv" >> /etc/environment \
    && echo "PATH=/opt/venv/bin:/opt/uv:/root/.local/bin:/root/.claude/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" >> /etc/environment

# =============================================================================
# Entrypoint
# =============================================================================
COPY entrypoint.sh /opt/runpod/entrypoint.sh
RUN chmod +x /opt/runpod/entrypoint.sh

EXPOSE 22 8188

ENTRYPOINT ["/opt/runpod/entrypoint.sh"]
