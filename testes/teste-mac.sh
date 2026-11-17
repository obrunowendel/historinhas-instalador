#!/usr/bin/env bash
# Roda o instalar.sh numa pasta de usuário temporária, a partir de um checkout local do sistema, sem perguntas.
# Uso: testes/teste-mac.sh <caminho do repositório do sistema>
set -euo pipefail
ORIGEM="$1"
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CASA="$(mktemp -d)"
trap 'rm -rf "$CASA"' EXIT
export PIP_CACHE_DIR="${PIP_CACHE_DIR:-$HOME/Library/Caches/pip}"
rodar() { HOME="$CASA" HISTORINHAS_ORIGEM="$ORIGEM" HISTORINHAS_SEM_PERGUNTAS=1 bash "$AQUI/instalar.sh"; }
erro() { echo "TESTE FALHOU: $1" >&2; exit 1; }

rodar > "$CASA/primeira.log" 2>&1 || { tail -20 "$CASA/primeira.log"; erro "primeira instalação"; }
rodar > "$CASA/segunda.log" 2>&1 || { tail -20 "$CASA/segunda.log"; erro "segunda instalação (idempotência)"; }

SIS="$CASA/Historinhas/sistema"
[ -x "$SIS/.venv/bin/python" ] || erro "venv não criada"
grep -q '"papel": "operador"' "$CASA/.config/historinhas/config.json" || erro "config.json não é de operador"
grep -q 'Edit(/regras/\*\*)' "$SIS/.claude/settings.local.json" || erro "negações do operador ausentes"
[ -d "$CASA/Historinhas/historias" ] || erro "pasta de histórias não criada"
saida="$(HOME="$CASA" "$SIS/historinhas" verificar --sem-rede || true)"
ruins="$(printf '%s\n' "$saida" | grep '^✗' | grep -v '^✗ chave ' || true)"
[ -z "$ruins" ] || { printf '%s\n' "$saida"; erro "verificar com falha fora das chaves"; }
HOME="$CASA" "$SIS/historinhas" versao | grep -q "papel: operador" || erro "versao não diz operador"
echo "teste do instalador no Mac: ok"
