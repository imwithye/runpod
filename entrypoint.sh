#!/bin/bash
set -e

# Set up SSH public key if provided via RunPod env
if [ -n "$PUBLIC_KEY" ]; then
    mkdir -p /home/yiwei/.ssh
    echo "$PUBLIC_KEY" > /home/yiwei/.ssh/authorized_keys
    chmod 700 /home/yiwei/.ssh
    chmod 600 /home/yiwei/.ssh/authorized_keys
fi

# Set password if provided via RunPod env
if [ -n "$USER_PASSWORD" ]; then
    echo "yiwei:$USER_PASSWORD" | sudo chpasswd
fi

# Start SSH daemon and keep container alive
exec sudo /usr/sbin/sshd -D
