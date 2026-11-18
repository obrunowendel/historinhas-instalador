# Instalador do historinhas para Windows. Uso, no PowerShell: irm <endereço>/instalar.ps1 | iex
# Pode rodar de novo quantas vezes quiser: conserta o que faltar e nunca apaga o que você produziu.
#
# Variáveis de teste: HISTORINHAS_ORIGEM (caminho ou URL a clonar no lugar do GitHub) e HISTORINHAS_SEM_PERGUNTAS=1
# (não instala programas, não pede código nem chaves, não cria atalho e não abre o painel).
$ErrorActionPreference = "Continue"  # com "Stop", o PowerShell 5.1 trata saída de erro de programa externo como falha
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Origem = if ($env:HISTORINHAS_ORIGEM) { $env:HISTORINHAS_ORIGEM } else { "https://x-access-token@github.com/obrunowendel/historinhas.git" }
$env:GIT_TERMINAL_PROMPT = "0"
$env:GCM_INTERACTIVE = "never"
$SemPerguntas = [bool]$env:HISTORINHAS_SEM_PERGUNTAS
$env:PYTHONUTF8 = "1"  # sem isso o Python escreve acento na página de código do Windows e o console mostra errado
$Base = Join-Path $HOME "Historinhas"
$Sis = Join-Path $Base "sistema"
$Chaves = @("FAL_KEY", "HIGGSFIELD_API_KEY")  # imagem e vídeo; o resto roda pelo Claude Code

function Passo($texto) { Write-Host "`n==> $texto" -ForegroundColor Cyan }
# Com "irm | iex", exit fecharia a janela de quem instala: a falta vira exceção, tratada no fim.
function Falta($coisa, $como) { throw "FALTA: $coisa — $como" }
function Tem($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Recarregar-Path {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}
function Ler-Oculto($pergunta) {
  $seguro = Read-Host -Prompt $pergunta -AsSecureString
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($seguro)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}
function Winget($id) {
  winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
}
function Python-Bom {
  $codigo = "import sys; print(sys.executable if sys.version_info >= (3, 12) else '')"
  if (Tem "py") {
    foreach ($versao in @("-3.13", "-3.12")) {
      $exe = (& py $versao -c $codigo 2>$null | Out-String).Trim()
      if ($LASTEXITCODE -eq 0 -and $exe -and (Test-Path $exe)) { return $exe }
    }
  }
  if (Tem "python") {
    $exe = (& python -c $codigo 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -eq 0 -and $exe -and (Test-Path $exe)) { return $exe }
  }
  return $null
}

function Pedir-Codigo {
  Passo "Acesso ao sistema"
  $token = Ler-Oculto "Cole o código de acesso que o Bruno mandou e aperte Enter"
  if (-not $token) { Falta "código de acesso" "peça o código ao Bruno e rode o instalador de novo" }
  "protocol=https`nhost=github.com`nusername=x-access-token`n" | git credential reject 2>$null
  "protocol=https`nhost=github.com`nusername=x-access-token`npassword=$token`n" | git credential approve
}

function Instalar {
Passo "Programas necessários"
if (-not $SemPerguntas) {
  if (-not (Tem "winget")) { Falta "winget" "atualize o Windows (Instalador de Aplicativo na Microsoft Store) e rode de novo" }
  if (-not (Tem "git")) { Winget "Git.Git" }
  Recarregar-Path
  if (-not (Python-Bom)) { Winget "Python.Python.3.12" }
  if (-not (Tem "ffmpeg")) { Winget "Gyan.FFmpeg" }
  $claude = winget list --id Anthropic.Claude -e 2>$null | Select-String "Anthropic.Claude"
  if (-not $claude) { try { Winget "Anthropic.Claude" } catch { Write-Host "Instale o Claude Desktop em claude.ai/download" } }
  Recarregar-Path
}
if (-not (Tem "git")) { Falta "git" "instale o Git for Windows e rode o instalador de novo" }
if (-not (Tem "ffmpeg")) { Falta "ffmpeg" "instale o ffmpeg (winget install Gyan.FFmpeg) e rode o instalador de novo" }
$Py = Python-Bom
if (-not $Py) { Falta "Python 3.12" "instale o Python 3.12 (winget install Python.Python.3.12) e rode de novo" }

$DoGithub = $Origem -match "^https://([^/@]+@)?github\.com/"
if (-not $SemPerguntas -and $DoGithub -and -not (Test-Path (Join-Path $Sis ".git"))) { Pedir-Codigo }

Passo "Sistema"
New-Item -ItemType Directory -Force -Path $Base | Out-Null
if (Test-Path (Join-Path $Sis ".git")) {
  git -C $Sis fetch --quiet origin 2>$null
  if ($LASTEXITCODE -ne 0 -and -not $SemPerguntas -and $DoGithub) {
    Pedir-Codigo  # código vencido ou revogado: pede o novo e tenta de novo
    git -C $Sis fetch --quiet origin
  }
  if ($LASTEXITCODE -ne 0) { Falta "atualização" "não consegui baixar a versão nova: confira a internet e o código de acesso" }
  git -C $Sis reset --hard --quiet "@{u}"
  git -C $Sis clean -fdq
} else {
  git clone --quiet $Origem $Sis
  if ($LASTEXITCODE -ne 0) { Falta "download do sistema" "o código de acesso foi recusado ou não há internet: confira e rode de novo" }
}

Passo "Ambiente Python (pode levar alguns minutos na primeira vez)"
$VenvPy = Join-Path $Sis ".venv\Scripts\python.exe"
if (-not (Test-Path $VenvPy)) { & $Py -m venv (Join-Path $Sis ".venv") }
& $VenvPy -m pip install --quiet --disable-pip-version-check -r (Join-Path $Sis "requirements.txt")
if ($LASTEXITCODE -ne 0) { Falta "pacotes do Python" "a instalação dos pacotes falhou: confira a internet e rode de novo" }

Passo "Configuração deste computador"
$config = @'
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
'@
$tmp = Join-Path $env:TEMP "historinhas-config.py"
Set-Content -Path $tmp -Value $config -Encoding UTF8
& $VenvPy $tmp $Sis $Base
Remove-Item $tmp

$Cli = Join-Path $Sis "historinhas.cmd"
if (-not $SemPerguntas) {
  Passo "Chaves de API (cole cada uma e aperte Enter; Enter vazio pula e dá para colar depois no painel)"
  foreach ($nome in $Chaves) {
    $valor = Ler-Oculto $nome
    if ($valor) { $valor | & $VenvPy (Join-Path $Sis "ferramentas\historinhas.py") chaves --gravar $nome }
  }
  Remove-Variable valor -ErrorAction SilentlyContinue

  Passo "Atalho na Área de Trabalho"
  $atalho = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path ([Environment]::GetFolderPath("Desktop")) "Historinhas.lnk"))
  $atalho.TargetPath = $Cli
  $atalho.Arguments = "painel"
  $atalho.WorkingDirectory = $Sis
  $atalho.Save()
}

Passo "Conferência"
& $Cli verificar
$global:LASTEXITCODE = 0  # o que o verificar reprova já está na tela (chave que falta se cola depois); não é falha da instalação

if (-not $SemPerguntas) { & $Cli painel }

Write-Host @"

Pronto. Para trabalhar:
  1. Abra o Claude Desktop e entre na aba Code (a aba de chat comum não roda o sistema; precisa de assinatura Pro).
  2. Escolha a pasta: $Sis
  3. Peça em português: "decupa esta copy", "gera as imagens", "gera os takes".
O painel abre pelo atalho Historinhas na Área de Trabalho.
"@
}

try {
  Instalar
} catch {
  Write-Host "`n$($_.Exception.Message)" -ForegroundColor Red
  if ($SemPerguntas) { exit 3 }  # só no teste automático: lá o código de saída é o que reprova
}
