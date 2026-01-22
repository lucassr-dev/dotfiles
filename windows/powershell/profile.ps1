# PowerShell profile gerenciado pelo dev-env-setup (Windows + WSL)
# Usa Starship por padrão, com alternância opcional via $env:DEV_PROMPT_PROVIDER (starship | oh-my-posh)

function Initialize-StarshipPrompt {
    if (Get-Command starship -ErrorAction SilentlyContinue) {
        Invoke-Expression (& starship init powershell)
        return $true
    }
    return $false
}

# Observação: os arquivos fullstack-dev.omp.json e dev-env-theme.omp.json NÃO são criados pelo script.
# Copie manualmente seus temas Oh My Posh para esses caminhos caso queira usá-los.
function Initialize-OhMyPoshPrompt {
    if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
        return $false
    }

    $themeCandidates = @(
        @{
            Path = $env:DEV_OMP_THEME
            Note = "Tema definido em DEV_OMP_THEME (caminho completo)"
        },
        @{
            Path = "$env:USERPROFILE\.config\omp\fullstack-dev.omp.json"
            Note = "Tema personalizado em %USERPROFILE%\.config\omp"
        },
        @{
            Path = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\dev-env-theme.omp.json"
            Note = "Tema dev-env (copie aqui se quiser usá-lo)"
        }
    )

    foreach ($candidate in $themeCandidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate.Path) -and (Test-Path $candidate.Path)) {
            oh-my-posh init pwsh --config $candidate.Path | Invoke-Expression
            return $true
        }
        Write-Verbose "Tema Oh My Posh não encontrado: $($candidate.Note) -> $($candidate.Path)"
    }

    if ($env:POSH_THEMES_PATH) {
        $defaultTheme = Join-Path $env:POSH_THEMES_PATH "jandedobbeleer.omp.json"
        if (Test-Path $defaultTheme) {
            oh-my-posh init pwsh --config $defaultTheme | Invoke-Expression
            return $true
        }
    }

    return $false
}

function Set-DevPromptTheme {
    param(
        [ValidateSet("starship", "oh-my-posh")]
        [string]$Name,
        [switch]$Persist
    )

    $env:DEV_PROMPT_PROVIDER = $Name
    if ($Persist) {
        [Environment]::SetEnvironmentVariable("DEV_PROMPT_PROVIDER", $Name, "User")
    }
    Write-Host "Prompt configurado para '$Name'. Reinicie o terminal para aplicar completamente." -ForegroundColor Green
}

<# ------------------------------ Prompt Setup ------------------------------ #>
$promptPreference = $env:DEV_PROMPT_PROVIDER
if ([string]::IsNullOrWhiteSpace($promptPreference)) {
    $promptPreference = "starship"
}
$promptPreference = $promptPreference.ToLowerInvariant()

switch ($promptPreference) {
    "oh-my-posh" {
        if (-not (Initialize-OhMyPoshPrompt)) {
            Write-Warning "Oh My Posh indisponível. Tentando Starship..."
            if (-not (Initialize-StarshipPrompt)) {
                Write-Warning "Starship também indisponível. Usando prompt padrão do PowerShell."
            }
        }
    }
    default {
        if (-not (Initialize-StarshipPrompt)) {
            Write-Warning "Starship indisponível. Tentando Oh My Posh..."
            if (-not (Initialize-OhMyPoshPrompt)) {
                Write-Warning "Oh My Posh também indisponível. Usando prompt padrão do PowerShell."
            }
        }
    }
}

<# --------------------------- PSReadLine Setup ----------------------------- #>
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module -Name PSReadLine
    Set-PSReadLineOption -EditMode Emacs
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function Complete
    Set-PSReadLineKeyHandler -Key Ctrl+f -Function ForwardWord
} else {
    Write-Verbose "PSReadLine não encontrado; pulando configuração de edição/predição."
}

<# ------------------------ Package Manager Hooks --------------------------- #>
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path $ChocolateyProfile) {
    Import-Module $ChocolateyProfile
}

if (Get-Module -ListAvailable -Name Microsoft.WinGet.CommandNotFound) {
    Import-Module Microsoft.WinGet.CommandNotFound
}

<# ----------------------- Runtime & Tool Activation ------------------------ #>
if (Get-Command mise -ErrorAction SilentlyContinue) {
    mise activate pwsh | Invoke-Expression
}

if (Get-Command direnv -ErrorAction SilentlyContinue) {
    direnv hook pwsh | Invoke-Expression
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell) })
}

if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module Terminal-Icons
}

if (Get-Module -ListAvailable -Name z) {
    Import-Module z
}

<# ---------------------------- Helper Functions ---------------------------- #>
function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function ls {
    if (Test-Command "eza") {
        eza --icons @args
    } else {
        Get-ChildItem @args
    }
}

function ll {
    if (Test-Command "eza") {
        eza --icons -l --git @args
    } else {
        Get-ChildItem -Force @args
    }
}

function la {
    if (Test-Command "eza") {
        eza --icons -la @args
    } else {
        Get-ChildItem -Force @args
    }
}

function cat {
    if (Test-Command "bat") {
        bat --paging=never @args
    } else {
        Get-Content @args
    }
}

Set-Alias -Name g -Value git
Set-Alias -Name lg -Value lazygit
Set-Alias -Name vim -Value nvim

function mkcd {
    param([string]$Path)
    if (-not $Path) {
        Write-Warning "Usage: mkcd <directory>"
        return
    }
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    Set-Location $Path
}

<# ----------------------------- Git Helpers -------------------------------- #>
function gs { git status @args }
function ga { git add @args }
function gc { git commit -m @args }
function gp { git push @args }
function gl { git log --oneline --graph @args }
function gco { git checkout @args }
function gb { git branch @args }

<# --------------------------- Node / React --------------------------------- #>
function ni { npm install @args }
function nr { npm run @args }
function ns { npm start @args }
function nt { npm test @args }
function nb { npm run build @args }
function nx { npx @args }

<# ------------------------------ Python ------------------------------------ #>
function py { python @args }
function pip3 { python -m pip @args }
function venv { python -m venv @args }
function activate { .\venv\Scripts\Activate.ps1 }

<# ---------------------------- PHP / Laravel ------------------------------- #>
function art { php artisan @args }
function serve { php artisan serve @args }
function migrate { php artisan migrate @args }
function tinker { php artisan tinker @args }

<# ------------------------------- Docker ----------------------------------- #>
function dps { docker ps @args }
function dimg { docker images @args }
function drun { docker run @args }
function dexec { docker exec -it @args }
function dcompose { docker-compose @args }
function dup { docker-compose up -d @args }
function ddown { docker-compose down @args }

<# -------------------------- Navegação Rápida ------------------------------ #>
function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }

<# ------------------------- Servidores Locais ------------------------------ #>
function dev-react { npm start }
function dev-next { npm run dev }
function dev-laravel { php artisan serve }
function dev-django { python manage.py runserver }

<# --------------------------- Projetos Rápidos ----------------------------- #>
function create-react { npx create-react-app @args }
function create-next { npx create-next-app@latest @args }
function create-laravel { composer create-project laravel/laravel @args }

<# ----------------------------- Ambiente ---------------------------------- #>
function env-node { $env:NODE_ENV = "development" }
function env-prod { $env:NODE_ENV = "production" }

<# ------------------------------ Boas-vindas -------------------------------- #>
Write-Host (Get-Location) -ForegroundColor Yellow
Write-Host "Perfil PowerShell carregado." -ForegroundColor DarkGray
