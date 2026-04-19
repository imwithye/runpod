#!/bin/bash
set -e

# Set up SSH public key (RunPod: PUBLIC_KEY, Vast.ai: SSH_PUBLIC_KEY)
SSH_KEY="${PUBLIC_KEY:-$SSH_PUBLIC_KEY}"
if [ -n "$SSH_KEY" ]; then
    mkdir -p /home/yiwei/.ssh
    echo "$SSH_KEY" > /home/yiwei/.ssh/authorized_keys
    chmod 700 /home/yiwei/.ssh
    chmod 600 /home/yiwei/.ssh/authorized_keys
fi

# Set password if provided via RunPod env
if [ -n "$USER_PASSWORD" ]; then
    echo "yiwei:$USER_PASSWORD" | sudo chpasswd
fi

# Start SSH daemon and keep container alive
exec sudo /usr/sbin/sshd -D
