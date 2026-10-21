<#
FraOS — FASE 2 del runbook (docs/INSTALL.md): svuota il Crucial (E:) sull'HDD.

Copia E:\claude (= ~/.claude) ed E:\ollama_models in D:\_BACKUP-PREWIPE\E, verifica, poi
ripunta i symlink di Claude Code e OLLAMA_MODELS sulla copia. Non cancella NIENTE su E::
il Crucial lo formatta l'installer di Windows nella FASE 4.

Si ferma al primo problema (processi aperti, spazio, robocopy, conteggi): ogni passo parte
solo se il precedente e' verde.

Uso, da una PowerShell **come amministratore** (mklink e setx /M lo richiedono), con
Claude Code, le sessioni Telegram e Ollama CHIUSI:
    powershell -ExecutionPolicy Bypass -File tools\fase2-svuota-crucial.ps1

-SoloCopia: copia e verifica soltanto, senza toccare link e variabili (serve per le prove).
#>
param(
  [string]$Sorgente = 'E:',
  [string]$Backup   = 'D:\_BACKUP-PREWIPE',
  [switch]$SoloCopia
)
$ErrorActionPreference = 'Stop'
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin -and -not $SoloCopia) { throw 'Serve una PowerShell come amministratore (mklink e setx /M)' }
$dest = Join-Path $Backup 'E'
New-Item -ItemType Directory -Force $dest | Out-Null
Start-Transcript -Path (Join-Path $Backup 'fase2.log') -Append | Out-Null

function Copia($da, $a, [string[]]$extra) {
  New-Item -ItemType Directory -Force $a | Out-Null        # robocopy NON crea la cartella del log
  robocopy $da $a /E /COPY:DAT /DCOPY:DAT /XJ /R:1 /W:1 /MT:8 @extra /NP /LOG:"$a.log" | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy $da -> codice $LASTEXITCODE, leggi $a.log" }
  # conteggio indipendente da robocopy (i link sono esclusi da entrambe le parti)
  $n1 = Get-ChildItem $da -Recurse -File -Force -Attributes !ReparsePoint | Where-Object { $_.FullName -notmatch '\\\.studio_links\\' } | Measure-Object Length -Sum
  $n2 = Get-ChildItem $a  -Recurse -File -Force -Attributes !ReparsePoint | Measure-Object Length -Sum
  "{0}: origine {1} file / {2:N2} GB - copia {3} file / {4:N2} GB" -f $da, $n1.Count, ($n1.Sum/1GB), $n2.Count, ($n2.Sum/1GB)
  if ($n2.Count -lt $n1.Count -or $n2.Sum -lt $n1.Sum) { throw "copia di $da INCOMPLETA: fermati e leggi $a.log" }
}

# --- 0. controlli preliminari -------------------------------------------------
$aperti = Get-Process claude, bun, ollama* -ErrorAction SilentlyContinue
if ($aperti -and -not $SoloCopia) { throw "Chiudi prima questi processi: $(($aperti.Name | Sort-Object -Unique) -join ', ')" }
$serve = (Get-ChildItem "$Sorgente\claude", "$Sorgente\ollama_models\blobs", "$Sorgente\ollama_models\manifests" -Recurse -File -Force -Attributes !ReparsePoint | Measure-Object Length -Sum).Sum
$libero = (Get-PSDrive ($Backup.Substring(0,1))).Free
"spazio: servono {0:N1} GB, liberi {1:N1} GB" -f ($serve/1GB), ($libero/1GB)
if ($libero -lt $serve + 10GB) { throw 'spazio insufficiente sul disco di backup' }

# --- 1. copia e verifica -----------------------------------------------------
Copia "$Sorgente\claude"        "$dest\claude"
Copia "$Sorgente\ollama_models" "$dest\ollama_models" @('/XD', '.studio_links')   # symlink di Unsloth Studio
if (-not (Test-Path "$dest\claude\.claude\settings.json")) { throw "manca $dest\claude\.claude\settings.json: copia di .claude assente" }

if ($SoloCopia) { 'SoloCopia: link e variabili non toccati.'; Stop-Transcript | Out-Null; return }

# --- 2. symlink di Claude Code sulla copia ----------------------------------------
# rmdir e del su un symlink tolgono SOLO il link. NON Remove-Item: su Windows PowerShell 5.1,
# con una cartella-symlink, puo' cancellare il contenuto del bersaglio.
$H = $env:USERPROFILE
foreach ($l in @(@{n='.claude'; dir=$true}, @{n='.claude.json'; dir=$false})) {
  $p = Join-Path $H $l.n
  $item = Get-Item $p -Force -ErrorAction SilentlyContinue
  if ($item -and $item.LinkType -ne 'SymbolicLink') { throw "$p non e' un symlink: non lo tocco" }
  if ($item) { if ($l.dir) { cmd /c rmdir "$p" } else { cmd /c del "$p" } }
  $t = "$dest\claude\$($l.n)"
  if ($l.dir) { cmd /c mklink /D "$p" "$t" | Out-Null } else { cmd /c mklink "$p" "$t" | Out-Null }
  "{0} -> {1}" -f $p, (Get-Item $p -Force).Target
}

# --- 3. Ollama punta alla copia (variabile di SISTEMA, come quella vecchia) ---------
setx /M OLLAMA_MODELS "$dest\ollama_models" | Out-Null
"OLLAMA_MODELS (sistema) = " + [Environment]::GetEnvironmentVariable('OLLAMA_MODELS', 'Machine')

''
'FASE 2 completata. E: NON e'' stato toccato: lo formatta l''installer di Windows nella FASE 4.'
'Ora: riapri Claude Code (deve vedere memoria e skill) e riavvia Ollama dalla tray.'
Stop-Transcript | Out-Null
