FROM nvidia/cuda:12.8.1-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV COLORTERM=truecolor
ENV LANG=C.UTF-8

# System dependencies + SSH
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
    wget \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd

# SSH config
RUN sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

WORKDIR /root

# Install Homebrew (manual clone to support root)
RUN git clone https://github.com/Homebrew/brew /home/linuxbrew/.linuxbrew/Homebrew \
    && mkdir -p /home/linuxbrew/.linuxbrew/bin \
    && ln -s ../Homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
ENV HOMEBREW_NO_AUTO_UPDATE=1
ENV HOMEBREW_NO_INSTALL_CLEANUP=1
ENV HOMEBREW_NO_ENV_HINTS=1

# Install dev toolchain via Homebrew
RUN brew install node go python uv

# Install Claude Code (official binary)
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/root/.local/bin:/root/.claude/bin:${PATH}"

# Create global venv and activate by default
RUN uv venv /root/.venv
ENV VIRTUAL_ENV="/root/.venv"
ENV PATH="/root/.venv/bin:${PATH}"

# Install PyTorch (CUDA 12.8)
RUN uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# Install ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /root/ComfyUI \
    && cd /root/ComfyUI \
    && uv pip install -r requirements.txt

# Install ComfyUI-Manager
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git /root/ComfyUI/custom_nodes/ComfyUI-Manager

# Install dotfiles
RUN curl -sSL dot.yiwei.dev | bash

# Entrypoint
COPY entrypoint.sh /root/.runpod/entrypoint.sh
RUN chmod +x /root/.runpod/entrypoint.sh

EXPOSE 22 8188

ENTRYPOINT ["/root/.runpod/entrypoint.sh"]
