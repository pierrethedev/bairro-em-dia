#!/bin/bash
set -euo pipefail

PROJECT_DIR="$HOME/bairro-em-dia"
BACKEND_DIR="$HOME/GS-C-CitizenTech"
API_DIR="$BACKEND_DIR/BairroEmDia.Api"
API_PROJECT="$API_DIR/BairroEmDia.Api.csproj"
PUBLISH_DIR="$API_DIR/publish"
LOG_DIR="$PROJECT_DIR/logs"
REPORT="$LOG_DIR/provision-app.log"
SERVICE_FILE="/etc/systemd/system/bairro-em-dia-api.service"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$REPORT") 2>&1

echo "=========================================="
echo " BAIRRO EM DIA - PROVISIONAMENTO DA API"
echo " Data: $(date)"
echo "=========================================="

# Verificar privilegios administrativos
if ! sudo -v; then
    echo "ERRO: permissao administrativa indisponivel."
    exit 1
fi

# Verificar estrutura do projeto
if [ ! -f "$API_PROJECT" ]; then
    echo "ERRO: projeto da API nao encontrado:"
    echo "$API_PROJECT"
    exit 1
fi

# Verificar .NET SDK
if ! command -v dotnet >/dev/null 2>&1; then
    echo "SDK .NET nao encontrado. Tentando instalar .NET 10..."
    sudo apt-get update
    sudo apt-get install -y dotnet-sdk-10.0
fi

DOTNET_BIN="$(command -v dotnet)"

if ! dotnet --list-sdks | grep -q '^10\.' ; then
    echo "ERRO: SDK .NET 10 nao encontrado."
    dotnet --list-sdks
    exit 1
fi

echo "[1/5] Dependencias verificadas."
echo "SDK .NET:"
dotnet --version

# Restaurar dependencias
echo "[2/5] Restaurando dependencias NuGet..."
dotnet restore "$API_PROJECT"

# Publicar aplicacao
echo "[3/5] Publicando API em Release..."
dotnet publish "$API_PROJECT" \
    -c Release \
    -o "$PUBLISH_DIR"

if [ ! -f "$PUBLISH_DIR/BairroEmDia.Api.dll" ]; then
    echo "ERRO: arquivo publicado da API nao encontrado."
    exit 1
fi

# Configurar servico systemd
echo "[4/5] Configurando servico systemd..."

sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Bairro em Dia - API ASP.NET Core
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$API_DIR
ExecStart=$DOTNET_BIN $PUBLISH_DIR/BairroEmDia.Api.dll
Environment=ASPNETCORE_ENVIRONMENT=Development
Environment=ASPNETCORE_URLS=http://0.0.0.0:5239
Environment=Frontend__Origins__0=http://127.0.0.1:8080
Environment=Frontend__Origins__1=http://localhost:8080
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable bairro-em-dia-api.service
sudo systemctl restart bairro-em-dia-api.service

# Validar servico
echo "[5/5] Validando API..."

if ! systemctl is-active --quiet bairro-em-dia-api.service; then
    echo "ERRO: servico da API nao esta ativo."
    sudo systemctl status bairro-em-dia-api.service --no-pager
    exit 1
fi

echo "Servico systemd ativo."
echo "Aguardando a API ficar pronta (limite de 30 segundos)..."

API_READY=false

for attempt in {1..15}; do
    if curl -fsS http://localhost:5239/api/ocorrencias > /dev/null; then
        API_READY=true
        break
    fi

    echo "Tentativa $attempt/15: API ainda inicializando..."
    sleep 2
done

if [ "$API_READY" = true ]; then
    echo "API respondeu corretamente ao teste HTTP."
else
    echo "ERRO: API nao respondeu apos 30 segundos."
    sudo journalctl -u bairro-em-dia-api.service -n 30 --no-pager
    exit 1
fi

echo ""
echo "=========================================="
echo " PROVISIONAMENTO DA API CONCLUIDO"
echo "=========================================="
echo "Servico: bairro-em-dia-api.service"
echo "Status: $(systemctl is-active bairro-em-dia-api.service)"
echo "API: http://localhost:5239"
echo "Log: $REPORT"
echo "=========================================="
