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

# Create user yiwei with sudo
RUN useradd -m -s /bin/bash yiwei \
    && echo "yiwei ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# SSH config: allow pubkey auth, disable password auth
RUN sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

USER yiwei
WORKDIR /home/yiwei

# Install Homebrew
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"

# Install dev toolchain via Homebrew
RUN brew install node go python uv

# Install Claude Code (official binary)
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/yiwei/.local/bin:/home/yiwei/.claude/bin:${PATH}"

# Install PyTorch (CUDA 12.8)
RUN uv pip install --system \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# Install ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /home/yiwei/ComfyUI \
    && cd /home/yiwei/ComfyUI \
    && uv pip install --system -r requirements.txt

# Install ComfyUI-Manager
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git /home/yiwei/ComfyUI/custom_nodes/ComfyUI-Manager

# Install dotfiles
RUN curl -sSL dot.yiwei.dev | bash

# Entrypoint
USER root
RUN mkdir -p /home/yiwei/.runpod
COPY --chown=yiwei:yiwei entrypoint.sh /home/yiwei/.runpod/entrypoint.sh
RUN chmod +x /home/yiwei/.runpod/entrypoint.sh

EXPOSE 22 8188

ENTRYPOINT ["/home/yiwei/.runpod/entrypoint.sh"]
