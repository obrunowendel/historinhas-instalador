# historinhas — instalador

Instala o historinhas no Windows ou no Mac com um comando. Você precisa do código de acesso que o Bruno manda.

**Windows** (abra o PowerShell):

```powershell
irm https://raw.githubusercontent.com/obrunowendel/historinhas-instalador/main/instalar.ps1 | iex
```

**Mac** (abra o Terminal):

```bash
curl -fsSL https://raw.githubusercontent.com/obrunowendel/historinhas-instalador/main/instalar.sh | bash
```

O instalador:

1. instala o que faltar: Git, Python 3.12, ffmpeg e o Claude Desktop (Windows pelo winget, Mac pelo Homebrew);
2. pede o código de acesso e baixa o sistema para `Historinhas/sistema`, na pasta do seu usuário;
3. prepara o ambiente Python e as pastas onde fica o que você produz;
4. pede as chaves de API (dá para pular e colar depois no painel);
5. cria o atalho "Historinhas" na Área de Trabalho, confere tudo e abre o painel.

Pode rodar de novo quando quiser: ele conserta o que faltar e não apaga nada do que você produziu.

Depois, no Claude Desktop: aba **Code** → escolher a pasta `Historinhas/sistema`. Precisa de assinatura Pro ou superior.
