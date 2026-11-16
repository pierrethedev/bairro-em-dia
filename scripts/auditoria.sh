#!/bin/bash

# ==========================================
# BAIRRO EM DIA
# Auditoria de eventos do sistema
# ==========================================

set -uo pipefail

PROJECT_DIR="$HOME/bairro-em-dia"
LOG_DIR="$PROJECT_DIR/logs"
DATA=$(date '+%Y%m%d-%H%M%S')
REPORT="$LOG_DIR/auditoria-$DATA.log"

mkdir -p "$LOG_DIR"

exec > >(tee -a "$REPORT") 2>&1

echo "=========================================="
echo " BAIRRO EM DIA - AUDITORIA DO SISTEMA"
echo " Data: $(date '+%d/%m/%Y %H:%M:%S')"
echo "=========================================="

echo ""
echo "===== IDENTIFICACAO DO SERVIDOR ====="
hostnamectl --static
whoami

echo ""
echo "===== ESTADO DOS SERVICOS ====="

for service in ssh.socket nginx bairro-monitor.timer; do
    printf "%s: " "$service"
    systemctl is-active "$service" || true
done
echo ""
echo "===== EVENTOS DO SSH ====="
journalctl -u ssh.socket --since "24 hours ago" --no-pager -n 20

echo ""
echo "===== EVENTOS DO MONITORAMENTO ====="
journalctl -u bairro-monitor.service --since "24 hours ago" --no-pager -n 20

echo ""
echo "===== FALHAS ATUAIS DO SYSTEMD ====="

FAILED=$(systemctl --failed --no-legend)

if [ -z "$FAILED" ]; then
    echo "Nenhuma unidade com falha."
else
    echo "$FAILED"
fi

echo ""
echo "===== ERROS RECENTES DO SISTEMA ====="
journalctl -p err --since "24 hours ago" --no-pager -n 20
echo ""
echo "===== ESPACO DOS LOGS ====="
journalctl --disk-usage

echo ""
echo "===== RESULTADO DA AUDITORIA ====="

if [ -z "$(systemctl --failed --no-legend)" ]; then
    echo "STATUS: INFRAESTRUTURA SEM SERVICOS EM FALHA"
else
    echo "STATUS: EXISTEM SERVICOS EM FALHA"
fi

echo ""
echo "===== AUDITORIA CONCLUIDA ====="
echo "Relatorio salvo em: $REPORT"
