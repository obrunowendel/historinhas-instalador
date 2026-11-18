#!/usr/bin/env bash
# Instalador do historinhas para Mac. Uso: curl -fsSL <endereço>/instalar.sh | bash
# Pode rodar de novo quantas vezes quiser: conserta o que faltar e nunca apaga o que você produziu.
#
# Variáveis de teste: HISTORINHAS_ORIGEM (caminho ou URL a clonar no lugar do GitHub) e HISTORINHAS_SEM_PERGUNTAS=1
# (não instala programas, não pede código nem chaves, não cria atalho e não abre o painel).
set -euo pipefail

ORIGEM="${HISTORINHAS_ORIGEM:-https://x-access-token@github.com/obrunowendel/historinhas.git}"
export GIT_TERMINAL_PROMPT=0
SEM_PERGUNTAS="${HISTORINHAS_SEM_PERGUNTAS:-}"
BASE="$HOME/Historinhas"
SIS="$BASE/sistema"
CHAVES="FAL_KEY HIGGSFIELD_API_KEY"  # imagem e vídeo; o resto roda pelo Claude Code

passo() { printf '\n==> %s\n' "$1"; }
falta() { printf 'FALTA: %s — %s\n' "$1" "$2" >&2; exit 3; }
tem() { command -v "$1" >/dev/null 2>&1; }
perguntar_oculto() {  # lê do teclado mesmo quando o script chega por "curl | bash"
  local resposta=""
  IFS= read -rs -p "$1" resposta < /dev/tty || true
  printf '\n' > /dev/tty
  printf '%s' "$resposta"
}

python_bom() {
  local py
  for py in python3.13 python3.12 python3 /opt/homebrew/bin/python3.12 /usr/local/bin/python3.12; do
    if tem "$py" && "$py" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)' 2>/dev/null; then
      command -v "$py"
      return 0
    fi
  done
  return 1
}

passo "Programas necessários"
if [ -z "$SEM_PERGUNTAS" ]; then
  if ! tem brew; then
    echo "Instalando o Homebrew (ele vai pedir a senha do Mac)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/tty
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  fi
  tem git || brew install git
  python_bom >/dev/null || brew install python@3.12
  tem ffmpeg || brew install ffmpeg
  [ -d "/Applications/Claude.app" ] || brew install --cask claude || echo "Instale o Claude Desktop em claude.ai/download"
fi
tem git || falta "git" "instale o Git e rode o instalador de novo"
tem ffmpeg || falta "ffmpeg" "instale o ffmpeg (brew install ffmpeg) e rode o instalador de novo"
PY="$(python_bom)" || falta "Python 3.12" "instale o Python 3.12 ou mais novo (brew install python@3.12)"

pedir_codigo() {
  passo "Acesso ao sistema"
  local token
  token="$(perguntar_oculto "Cole o código de acesso que o Bruno mandou e aperte Enter: ")"
  [ -n "$token" ] || falta "código de acesso" "peça o código ao Bruno e rode o instalador de novo"
  printf 'protocol=https\nhost=github.com\nusername=x-access-token\n\n' | git -c credential.helper=osxkeychain credential reject || true
  printf 'protocol=https\nhost=github.com\nusername=x-access-token\npassword=%s\n\n' "$token" \
    | git -c credential.helper=osxkeychain credential approve
}
DO_GITHUB=""
[[ "$ORIGEM" == https://*github.com/* ]] && DO_GITHUB=1
if [ -z "$SEM_PERGUNTAS" ] && [ -n "$DO_GITHUB" ] && [ ! -d "$SIS/.git" ]; then
  pedir_codigo
fi

passo "Sistema"
mkdir -p "$BASE"
if [ -d "$SIS/.git" ]; then
  if ! git -C "$SIS" fetch --quiet origin 2>/dev/null; then
    # código vencido ou revogado: pede o novo e tenta de novo
    [ -z "$SEM_PERGUNTAS" ] && [ -n "$DO_GITHUB" ] && pedir_codigo
    git -C "$SIS" fetch --quiet origin || falta "atualização" "não consegui baixar a versão nova: confira a internet e o código de acesso"
  fi
  git -C "$SIS" reset --hard --quiet '@{u}' && git -C "$SIS" clean -fdq
else
  git -c credential.helper=osxkeychain clone --quiet "$ORIGEM" "$SIS" \
    || falta "download do sistema" "o código de acesso foi recusado ou não há internet: confira e rode de novo"
fi
git -C "$SIS" config credential.helper osxkeychain

passo "Ambiente Python (pode levar alguns minutos na primeira vez)"
[ -x "$SIS/.venv/bin/python" ] || "$PY" -m venv "$SIS/.venv"
"$SIS/.venv/bin/python" -m pip install --quiet --disable-pip-version-check -r "$SIS/requirements.txt"

passo "Configuração deste computador"
"$SIS/.venv/bin/python" - "$SIS" "$BASE" <<'PYTHON'
import json, os, pathlib, sys
sis, base = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
cfg_dir = pathlib.Path(os.environ.get("HISTORINHAS_CONFIG") or pathlib.Path.home() / ".config" / "historinhas")
cfg_dir.mkdir(parents=True, exist_ok=True)
arq = cfg_dir / "config.json"
cfg = json.loads(arq.read_text(encoding="utf-8")) if arq.exists() else {}
cfg.setdefault("papel", "operador")
cfg.setdefault("dados", str(base))
cfg["sistema"] = str(sis)
arq.write_text(json.dumps(cfg, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
for pasta in ("historias", "midia", "licoes", "logs"):
    (base / pasta).mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(sis / "ferramentas"))
import papel
papel.gravar_settings_local(sis, cfg["papel"])
print(f"papel: {cfg['papel']} · dados: {cfg['dados']}")
PYTHON

if [ -z "$SEM_PERGUNTAS" ]; then
  passo "Chaves de API (cole cada uma e aperte Enter; Enter vazio pula e dá para colar depois no painel)"
  for nome in $CHAVES; do
    valor="$(perguntar_oculto "$nome: ")"
    [ -z "$valor" ] || printf '%s\n' "$valor" | "$SIS/historinhas" chaves --gravar "$nome"
  done
  unset valor

  passo "Atalho na Mesa"
  printf '#!/bin/bash\n"%s/historinhas" painel\n' "$SIS" > "$HOME/Desktop/Historinhas.command"
  chmod +x "$HOME/Desktop/Historinhas.command"
fi

passo "Conferência"
"$SIS/historinhas" verificar || true

if [ -z "$SEM_PERGUNTAS" ]; then
  "$SIS/historinhas" painel || true
fi

cat <<FIM

Pronto. Para trabalhar:
  1. Abra o Claude Desktop e entre na aba Code (a aba de chat comum não roda o sistema; precisa de assinatura Pro).
  2. Escolha a pasta: $SIS
  3. Peça em português: "decupa esta copy", "gera as imagens", "gera os takes".
O painel abre pelo atalho Historinhas na Mesa ou com: $SIS/historinhas painel
FIM
