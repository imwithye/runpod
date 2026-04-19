#!/bin/bash
set -e

# Set up SSH public key (RunPod: PUBLIC_KEY, Vast.ai: SSH_PUBLIC_KEY)
SSH_KEY="${PUBLIC_KEY:-$SSH_PUBLIC_KEY}"
if [ -n "$SSH_KEY" ]; then
    mkdir -p /root/.ssh
    echo "$SSH_KEY" > /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
fi

# Set password if provided
if [ -n "$USER_PASSWORD" ]; then
    echo "root:$USER_PASSWORD" | chpasswd
fi

# Start SSH daemon and keep container alive
exec /usr/sbin/sshd -D
