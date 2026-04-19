#!/bin/bash
# RunPod welcome message

echo ""
echo "=============================== RunPod ================================="

# System info
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
GPU_MEM=$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | awk -F', ' '{printf "%dMi / %dMi", $1, $2}')
CPU_LOAD=$(cat /proc/loadavg | awk '{printf "%.1f %.1f %.1f", $1, $2, $3}')
MEM_INFO=$(free -h | awk '/Mem:/ {printf "%s / %s", $3, $2}')
DISK_INFO=$(df -h / | awk 'NR==2 {printf "%s / %s", $3, $2}')

printf "  %-12s %s\n" "GPU:" "${GPU_NAME:-N/A} (${GPU_MEM:-N/A})"
printf "  %-12s %s\n" "CPU Load:" "$CPU_LOAD"
printf "  %-12s %s\n" "Memory:" "$MEM_INFO"
printf "  %-12s %s\n" "Disk:" "$DISK_INFO"

echo ""
echo "-------------------------------- Services ------------------------------"
pm2 jlist 2>/dev/null | python3 -c "
import sys, json
try:
    procs = json.load(sys.stdin)
    for p in procs:
        name = p.get('name', '?')
        status = p.get('pm2_env', {}).get('status', '?')
        icon = '\033[32m●\033[0m' if status == 'online' else '\033[31m●\033[0m'
        print(f'  {icon} {name:<24s} {status}')
except:
    print('  pm2 not available')
" 2>/dev/null
echo ""
echo "  pm2 logs <name>      View logs"
echo "  pm2 restart <name>   Restart service"
echo "  glances              System monitor"
echo "========================================================================"
echo ""
