#!/bin/bash

set -euo pipefail

PROJECT_DIR="$HOME/bairro-em-dia"
LOG_DIR="$PROJECT_DIR/logs"
BACKUP_DIR="$PROJECT_DIR/backups"
REPORT="$LOG_DIR/provision-infra.log"

WEB_DIR="/var/www/bairro-em-dia"
NGINX_SITE="/etc/nginx/sites-available/bairro-em-dia"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

exec > >(tee -a "$REPORT") 2>&1

echo "=========================================="
echo " BAIRRO EM DIA - PROVISIONAMENTO"
echo " Data: $(date)"
echo "=========================================="

if ! sudo -v; then
    echo "ERRO: permissao administrativa indisponivel."
    exit 1
fi

echo "[1/6] Backup do Netplan..."

sudo cp -a /etc/netplan \
    "$BACKUP_DIR/netplan-$(date +%Y%m%d-%H%M%S)"

echo "[2/6] Configurando hostname..."

sudo hostnamectl set-hostname bairro-em-dia

echo "Hostname: $(hostname)"

echo "[3/6] Configurando firewall..."

sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable

echo "Firewall configurado."

echo "[4/6] Instalando e configurando Nginx..."

if ! command -v nginx >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y nginx
else
    echo "Nginx ja esta instalado."
fi

sudo mkdir -p "$WEB_DIR"

sudo tee "$WEB_DIR/index.html" > /dev/null <<'HTML'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bairro em Dia</title>
</head>
<body>
    <h1>Bairro em Dia</h1>
    <h2>Infraestrutura Linux operacional</h2>
    <p>Servidor web Nginx em funcionamento.</p>
    <p>Ambiente preparado para receber a aplicacao CitizenTech.</p>
</body>
</html>
HTML

sudo tee "$NGINX_SITE" > /dev/null <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    root /var/www/bairro-em-dia;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX

sudo ln -sfn "$NGINX_SITE" \
    /etc/nginx/sites-enabled/bairro-em-dia

if [ -e /etc/nginx/sites-enabled/default ] || \
   [ -L /etc/nginx/sites-enabled/default ]; then
    sudo rm /etc/nginx/sites-enabled/default
fi

sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl reload nginx

echo "Nginx configurado e iniciado."

echo "[5/6] Validando infraestrutura..."

echo "Hostname:"
hostnamectl --static

echo""
echo "Interface de rede:"
INTERFACE=$(ip route | awk '/default/ {print $5; exit}')

if [ -n "$INTERFACE" ]; then
    echo "Interface: $INTERFACE"
    ip -br addr show "$INTERFACE"
else
    echo "ERRO: nenhuma interface de rede encontrada."
    exit 1
fi

echo ""
echo "Gateway:"
GATEWAY=$(ip route | awk '/default/ {print $3; exit}')
echo "${GATEWAY:-Nao identificado}"

echo ""
echo "Servidores DNS:"
resolvectl dns

echo ""
echo "Teste de resolucao DNS:"
if resolvectl query google.com; then
    echo "DNS funcionando."
else
    echo "ERRO: falha na resolucao DNS."
    exit 1
fi

echo ""
echo "Firewall:"
sudo ufw status verbose

echo ""
echo "Estado do Nginx:"
systemctl is-active nginx

echo ""
echo "Teste HTTP:"
if curl -fsS http://localhost > /dev/null; then
    echo "HTTP funcionando corretamente."
else
    echo "ERRO: teste HTTP falhou."
    exit 1
fi

echo ""
echo "[6/6] Provisionamento concluido."
echo "PROVISIONAMENTO CONCLUIDO"
