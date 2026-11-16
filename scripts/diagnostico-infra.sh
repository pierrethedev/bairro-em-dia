#!/bin/bash

# ==========================================
# BAIRRO EM DIA
# Diagnostico da infraestrutura
# ==========================================

set -uo pipefail

PROJECT_DIR="$HOME/bairro-em-dia"
LOG_DIR="$PROJECT_DIR/logs"
REPORT="$LOG_DIR/infra-report.txt"

mkdir -p "$LOG_DIR"

echo "Iniciando diagnostico da infraestrutura..."

{
    echo "======================================"
    echo " BAIRRO EM DIA - DIAGNOSTICO"
    echo "======================================"
    echo "Data: $(date)"

    echo ""
    echo "===== USUARIO ====="
    whoami

    echo ""
    echo "===== HOSTNAME ====="
    hostnamectl

    echo ""
    echo "===== SISTEMA OPERACIONAL ====="
    cat /etc/os-release

    echo ""
    echo "===== MEMORIA ====="
    free -h

    echo ""
    echo "===== ARMAZENAMENTO ====="
    df -h /

    echo ""
    echo "===== PROCESSADOR ====="
    lscpu | grep -E "Model name|CPU\(s\)"

    echo "===== REDE ====="

    INTERFACE=$(ip route | awk '/default/ {print $5; exit}')

    if [ -n "$INTERFACE" ]; then
        echo "Interface ativa: $INTERFACE"
        ip -br addr show "$INTERFACE"
    else
        echo "Nenhuma interface com rota padrao encontrada."
    fi

    echo ""
    echo "===== GATEWAY ====="
    ip route | grep '^default' || true

    echo ""
    echo "===== SERVIDORES DNS ====="
    resolvectl dns

    echo ""
    echo "===== TESTE DE RESOLUCAO DNS ====="
    if resolvectl query google.com; then
        echo "Resolucao DNS funcionando."
    else
        echo "ALERTA: falha na resolucao DNS."
    fi
    echo ""
    echo "===== SERVICOS ====="

    for service in ssh.socket nginx postgresql; do
        echo -n "$service: "
        systemctl is-active "$service" || true
    done

    echo ""
    echo "===== FINALIZACAO ====="
    echo "Diagnostico concluido."

} | tee "$REPORT"

echo ""
echo "Relatorio salvo em: $REPORT"
