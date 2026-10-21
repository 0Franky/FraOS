<#
FraOS — FASE 3 del runbook (docs/INSTALL.md): backup del vecchio Windows (C:) sull'HDD.

Fa le parti automatizzabili, nell'ordine giusto:
  docker    dump logici dei Postgres, elenco e inspect dei container, POI stop e tar di
            tutti i volumi (dentro ci sono anche le chiavi di Vault)
  wsl       wsl --shutdown + export della distro Ubuntu (~19 GB)
  home      tutta C:\Users\frhae tranne le cache, AppData\Roaming, C:\RustDeskServer,
            C:\tmp, hosts, profili Wi-Fi
  inventari winget export
Restano A MANO (runbook 3.4, 3.6, 3.7, 3.8): password dei browser, push dei repo, archivio
cifrato dei segreti, verifica finale.

Si ferma al primo problema. Ogni copia viene riverificata rilanciando robocopy in prova (/L)
con le stesse esclusioni: se resta anche un solo file da copiare, si ferma. Rilanciarlo e'
sicuro: robocopy copia solo cio' che manca o e' cambiato.

Uso, da una PowerShell COME AMMINISTRATORE, con le app chiuse (browser, Telegram, VS Code,
Discord...: tengono file aperti in AppData\Roaming). Claude Code puo' restare aperto: la sua
cartella e' gia' su D: e qui non viene toccata.
    powershell -ExecutionPolicy Bypass -File tools\fase3-backup-windows.ps1
    powershell -ExecutionPolicy Bypass -File tools\fase3-backup-windows.ps1 -Passi home,inventari
#>
param(
  [string]$Backup = 'D:\_BACKUP-PREWIPE',
  [ValidateSet('docker', 'wsl', 'home', 'inventari')]
  [string[]]$Passi = @('docker', 'wsl', 'home', 'inventari'),
  [string]$Home_ = $env:USERPROFILE          # parametri usati solo dalle prove
)
$ErrorActionPreference = 'Stop'
$C = Join-Path $Backup 'C'
New-Item -ItemType Directory -Force $C | Out-Null
# Qui finiscono dump SQL, chiavi Wi-Fi in chiaro e volumi di Vault: la cartella NON deve ereditare
# "Authenticated Users: Modify" dalla radice di D:, che darebbe accesso anche agli utenti locali
# della sandbox di Codex. Solo l'utente, SYSTEM e gli amministratori (il Windows nuovo ci arriva
# da amministratore; Linux con ntfs3 ignora queste ACL).
icacls $Backup /inheritance:r /grant:r "$($env:USERNAME):(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' /C /Q | Out-Null   # SENZA /T: sui file toglierebbe i permessi ereditati senza concederne altri (provato)
if ($LASTEXITCODE -ne 0) { throw "icacls su $Backup fallito (codice $LASTEXITCODE)" }
Start-Transcript -Path (Join-Path $Backup 'fase3.log') -Append | Out-Null

function Copia($da, $a, [string[]]$extra) {
  New-Item -ItemType Directory -Force $a | Out-Null        # robocopy NON crea la cartella del log
  robocopy $da $a /E /COPY:DAT /DCOPY:DAT /XJ /R:1 /W:1 /MT:8 @extra /NP /LOG:"$a.log" | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy $da -> codice $LASTEXITCODE, leggi $a.log (file in uso? chiudi l'app e rilancia)" }
  # verifica: stessa copia in prova. Ogni riga e' un file che manca ancora nella copia
  $manca = @(robocopy $da $a /E /XJ /L /R:0 /W:0 @extra /NJH /NJS /NDL /NC /NS /FP | Where-Object { $_.Trim() })
  if ($manca.Count -gt 0) { throw "copia di $da INCOMPLETA, mancano $($manca.Count) file (es. $($manca[0].Trim()))" }
  "OK  $da -> $a"
}

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# --- docker ----------------------------------------------------------------------
if ($Passi -contains 'docker') {
  $D = Join-Path $C 'docker'; New-Item -ItemType Directory -Force $D | Out-Null
  docker ps -a --format '{{.Names}}|{{.Image}}|{{.Status}}|{{.Mounts}}' | Out-File -Encoding utf8 "$D\container.txt"
  docker inspect $(docker ps -aq) | Out-File -Encoding utf8 "$D\inspect.json"     # quale volume va a quale container
  # dump logici: reggono un cambio di versione di Postgres. Utenti letti da POSTGRES_USER (2026-10-21)
  foreach ($db in @(@{c='netview-db'; u='supabase_admin'}, @{c='willhouse-postgres'; u='postgres'})) {
    $f = "$D\$($db.c).sql"
    cmd /c "docker exec $($db.c) pg_dumpall -U $($db.u) > `"$f`""
    if ($LASTEXITCODE -ne 0 -or (Get-Item $f).Length -lt 1KB) { throw "dump di $($db.c) fallito o vuoto: $f" }
    "OK  dump $($db.c): {0:N1} MB" -f ((Get-Item $f).Length / 1MB)
  }
  docker stop $(docker ps -q) | Out-Null
  foreach ($v in (docker volume ls -q)) {
    docker run --rm -v "$($v):/v:ro" -v "$($D):/b" alpine tar czf "/b/volume-$v.tgz" -C /v .
    if ($LASTEXITCODE -ne 0) { throw "tar del volume $v fallito" }
  }
  "OK  volumi archiviati: " + @(Get-ChildItem "$D\volume-*.tgz").Count + " su " + @(docker volume ls -q).Count
}

# --- wsl ----------------------------------------------------------------------------
if ($Passi -contains 'wsl') {
  wsl --shutdown
  wsl --export Ubuntu "$C\wsl-ubuntu.tar"
  if ($LASTEXITCODE -ne 0) { throw 'wsl --export fallito' }
  "OK  WSL Ubuntu: {0:N1} GB" -f ((Get-Item "$C\wsl-ubuntu.tar").Length / 1GB)
}

# --- home ---------------------------------------------------------------------------
if ($Passi -contains 'home') {
  # cache e toolchain riscaricabili; .claude e .claude.json sono symlink: /XJ li salta (sono gia' su D:)
  Copia $Home_ "$C\home" @('/XD', 'AppData', '.gradle', '.cache', '.rustup', '.cargo', '.bun', 'scoop',
    'npm-cache', 'unsloth_compiled_cache', 'avd', '.venv_t5_510', '.venv_t5_530', '.venv_t5_550',
    'OneDrive', 'node_modules', '/XF', 'NTUSER.DAT*', 'ntuser.dat*', 'UsrClass.dat*')
  Copia "$Home_\AppData\Roaming" "$C\AppData-Roaming" @('/XD', 'Cache', 'Code Cache', 'GPUCache',
    'CachedData', 'CachedExtensionVSIXs', 'Service Worker', 'logs')
  foreach ($x in 'C:\RustDeskServer', 'C:\tmp') { if (Test-Path $x) { Copia $x "$C\root-$(Split-Path $x -Leaf)" } }
  Copy-Item C:\Windows\System32\drivers\etc\hosts "$C\hosts"
  if ($admin) {
    New-Item -ItemType Directory -Force "$C\wifi" | Out-Null
    netsh wlan export profile key=clear folder="$C\wifi" | Out-Null    # chiavi in chiaro: vanno nell'archivio cifrato
    "OK  hosts + profili Wi-Fi: " + @(Get-ChildItem "$C\wifi" -Filter *.xml).Count
  } else { 'ATTENZIONE: profili Wi-Fi NON esportati, serve una PowerShell come amministratore' }
}

# --- inventari ----------------------------------------------------------------------
if ($Passi -contains 'inventari') {
  winget export -o "$Backup\winget.json" --accept-source-agreements | Out-Null
  "OK  winget.json"
}

''
"FASE 3, parti automatiche completate: $($Passi -join ', ')."
'Restano a mano (docs/INSTALL.md): 3.4 password dei browser, 3.6 push dei repo, 3.7 archivio cifrato, 3.8 verifica.'
Stop-Transcript | Out-Null
