#!/bin/bash

# ==========================================
# BAIRRO EM DIA
# Monitoramento de recursos do servidor
# ==========================================

set -euo pipefail

PROJECT_DIR="$HOME/bairro-em-dia"
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/monitoramento.log"

CPU_LIMIT=85
MEMORY_LIMIT=85
DISK_LIMIT=80

mkdir -p "$LOG_DIR"

# Capturar uso da CPU
read -r cpu user nice system idle iowait irq softirq steal rest < /proc/stat
TOTAL1=$((user + nice + system + idle + iowait + irq + softirq + steal))
IDLE1=$((idle + iowait))

sleep 1

read -r cpu user nice system idle iowait irq softirq steal rest < /proc/stat
TOTAL2=$((user + nice + system + idle + iowait + irq + softirq + steal))
IDLE2=$((idle + iowait))

TOTAL_DIFF=$((TOTAL2 - TOTAL1))
IDLE_DIFF=$((IDLE2 - IDLE1))

CPU_USAGE=$(awk -v total="$TOTAL_DIFF" -v idle="$IDLE_DIFF" \
    'BEGIN {
        if (total > 0) printf "%.1f", (total-idle)/total*100;
        else print "0.0"
    }')

# Capturar uso da memória
MEMORY_USAGE=$(free | awk '/Mem:/ {
    if ($2 > 0) printf "%.1f", ($2-$7)/$2*100;
    else print "0.0"
}')

# Capturar uso do disco raiz
DISK_USAGE=$(df -P / | awk 'NR==2 {
    gsub("%", "", $5);
    print $5
}')

# Registrar resultados
{
    echo "=========================================="
    echo "BAIRRO EM DIA - MONITORAMENTO"
    echo "Data: $(date '+%d/%m/%Y %H:%M:%S')"
    echo "=========================================="

    printf "CPU: %s%%\n" "$CPU_USAGE"
    printf "Memoria: %s%%\n" "$MEMORY_USAGE"
    printf "Disco: %s%%\n" "$DISK_USAGE"

    echo ""
    echo "===== ALERTAS ====="

    ALERT=0

    if awk -v value="$CPU_USAGE" -v limit="$CPU_LIMIT" \
        'BEGIN {exit !(value >= limit)}'; then
        echo "ALERTA: CPU acima de ${CPU_LIMIT}%!"
        ALERT=1
    fi

    if awk -v value="$MEMORY_USAGE" -v limit="$MEMORY_LIMIT" \
        'BEGIN {exit !(value >= limit)}'; then
        echo "ALERTA: Memoria acima de ${MEMORY_LIMIT}%!"
        ALERT=1
    fi

    if [ "$DISK_USAGE" -ge "$DISK_LIMIT" ]; then
        echo "ALERTA: Disco acima de ${DISK_LIMIT}%!"
        ALERT=1
    fi

    if [ "$ALERT" -eq 0 ]; then
        echo "Nenhum alerta. Todos os recursos estao dentro dos limites."
    fi

    echo ""
} | tee -a "$LOG_FILE"
