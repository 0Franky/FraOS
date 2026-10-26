<#
FraOS — FASE 4.4 del runbook (docs/INSTALL.md): regolazioni del Windows NUOVO sul Crucial.

  1. HDD: lo rimette in linea se Windows l'ha messo offline e gli da' la lettera D:
     (MAI inizializza ne' formatta: se il disco non ha la sua partizione NTFS, si ferma)
  2. permessi: l'utente nuovo ha un SID diverso da quello vecchio, e D:\Users\frhae e
     D:\_BACKUP-PREWIPE davano accesso solo al vecchio (piu' gli amministratori, che senza UAC
     elevato non contano). Aggiunge l'utente nuovo SOLO sulla radice: i file che ereditano
     si aggiornano da soli (con /T i file restano senza permessi, provato nella FASE 3)
  3. BitLocker: Windows 11 cifra C: da solo. Lo decifra e impedisce che ricominci: con la
     cifratura attiva, i cambi di Secure Boot/MOK della FASE 5 chiedono la chiave di ripristino
  4. cartelle utente (Desktop, Documenti, ...) sulle esistenti in D:\Users\frhae
  5. Claude Code: symlink .claude e .claude.json sulla copia in D:\_BACKUP-PREWIPE\E\claude,
     e OLLAMA_MODELS, come sul Windows vecchio dopo la FASE 2

Si ferma al primo problema. Rilanciarlo e' sicuro: ogni passo gia' fatto viene saltato.
Uso, dal Windows NUOVO, chiavetta dell'installer TOLTA, PowerShell COME AMMINISTRATORE:
    powershell -ExecutionPolicy Bypass -File D:\Users\frhae\gitProjects\_current\FraOS\tools\fase4-windows-nuovo.ps1
#>
$ErrorActionPreference = 'Stop'
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { throw 'Serve una PowerShell come amministratore' }
$B = 'D:\_BACKUP-PREWIPE'

# --- 1. HDD in linea e con la lettera D: ---------------------------------------------
$hdd = @(Get-Disk | Where-Object { $_.Size -gt 900GB -and $_.BusType -ne 'USB' })
if ($hdd.Count -ne 1) { throw "trovati $($hdd.Count) dischi interni oltre 900 GB: l'HDD e' collegato? (Get-Disk)" }
$hdd = $hdd[0]
if ($hdd.PartitionStyle -eq 'RAW') { throw "l'HDD risulta RAW (senza partizioni): FERMATI, non inizializzarlo" }
if ($hdd.IsOffline)  { Set-Disk -Number $hdd.Number -IsOffline $false;  'HDD rimesso in linea' }
if ($hdd.IsReadOnly) { Set-Disk -Number $hdd.Number -IsReadOnly $false; 'HDD tolto dalla sola lettura' }
$part = Get-Partition -DiskNumber $hdd.Number | Sort-Object Size -Descending | Select-Object -First 1
if ((Get-Volume -Partition $part).FileSystem -ne 'NTFS') { throw "la partizione piu' grande dell'HDD non e' NTFS: FERMATI" }
if ($part.DriveLetter -ne 'D') {
  $occupata = Get-Volume -DriveLetter D -ErrorAction SilentlyContinue
  if ($occupata) { throw "D: e' gia' usata da '$($occupata.FileSystemLabel)' ($($occupata.DriveType)): togli la chiavetta e rilancia" }
  if ($part.DriveLetter) { Remove-PartitionAccessPath -DiskNumber $hdd.Number -PartitionNumber $part.PartitionNumber -AccessPath "$($part.DriveLetter):\" }
  Set-Partition -DiskNumber $hdd.Number -PartitionNumber $part.PartitionNumber -NewDriveLetter D
}
if (-not (Test-Path "$B\E\claude\.claude\settings.json")) { throw "D: non e' l'HDD giusto: manca $B\E\claude\.claude\settings.json" }
'OK  HDD su D: ({0:N0} GB liberi)' -f ((Get-PSDrive D).Free / 1GB)

# --- 2. permessi per l'utente nuovo --------------------------------------------------------
'permessi: Windows li propaga a tutti i file sotto D:\Users\frhae, puo'' volerci qualche minuto...'
foreach ($p in 'D:\Users\frhae', $B) {
  icacls $p /grant "$($env:USERNAME):(OI)(CI)F" /C /Q | Out-Null     # SENZA /T
  if ($LASTEXITCODE -ne 0) { throw "icacls su $p fallito (codice $LASTEXITCODE)" }
  "OK  $env:USERNAME ha accesso a $p"
}

# --- 3. BitLocker su C: spento, e niente cifratura automatica in futuro -----------------------
function Chiave($k) { if (-not (Test-Path $k)) { New-Item $k | Out-Null } }   # NON New-Item -Force: su una chiave esistente ne cancella i valori
Chiave 'HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker'
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker' PreventDeviceEncryption 1 -Type DWord
$bl = Get-BitLockerVolume C:
if ($bl.VolumeStatus -ne 'FullyDecrypted') {
  manage-bde -off C: | Out-Null       # anche a cifratura in corso: la inverte
  if ($LASTEXITCODE -ne 0) { throw "manage-bde -off C: fallito (codice $LASTEXITCODE)" }
  'OK  decifratura di C: avviata (qualche minuto): controlla con manage-bde -status C:'
} else { 'OK  C: non e'' cifrato' }
foreach ($v in Get-BitLockerVolume) {   # D: non deve mai essere cifrato: e' condiviso con FraOS
  if ($v.MountPoint -ne 'C:' -and $v.VolumeStatus -ne 'FullyDecrypted') { "ATTENZIONE: $($v.MountPoint) risulta $($v.VolumeStatus)" }
}

# --- 4. cartelle utente su D: (come sul Windows vecchio) -----------------------------------
$usf = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
$cartelle = [ordered]@{ Desktop = 'Desktop'; Personal = 'Documents'; 'My Pictures' = 'Pictures'
  'My Music' = 'Music'; 'My Video' = 'Videos'; '{374DE290-123F-4565-9164-39C4925E467B}' = 'Downloads' }
foreach ($k in $cartelle.Keys) {
  $p = "D:\Users\frhae\$($cartelle[$k])"
  if (Test-Path $p) { Set-ItemProperty $usf $k $p -Type ExpandString } else { "ATTENZIONE: manca $p, $k lasciata su C:" }
}
'OK  cartelle utente su D:\Users\frhae (valgono dal prossimo accesso)'

# --- 5. Claude Code e Ollama sulla copia -----------------------------------------------------
# rmdir e del su un symlink tolgono SOLO il link. NON Remove-Item (vedi fase2-svuota-crucial.ps1)
# l'utente nuovo si chiama Fra, ma settings.json ha 69 percorsi C:/Users/frhae (2026-10-26): una junction li fa tornare
if ($env:USERNAME -ne 'frhae' -and -not (Test-Path C:\Users\frhae)) { cmd /c mklink /J C:\Users\frhae "$env:USERPROFILE" | Out-Null; "OK  C:\Users\frhae -> $env:USERPROFILE" }
foreach ($l in @(@{n='.claude'; dir=$true}, @{n='.claude.json'; dir=$false})) {
  $p = Join-Path $env:USERPROFILE $l.n
  $item = Get-Item $p -Force -ErrorAction SilentlyContinue
  if ($item -and $item.LinkType -ne 'SymbolicLink') {
    # Claude Code gia' avviato qui (2026-10-24): config nuova e quasi vuota. Si mette da parte, non si cancella
    if (Get-Process claude -ErrorAction SilentlyContinue) { throw "chiudi Claude Code e rilancia: $p e' in uso" }
    Rename-Item $p "$($l.n).windows-nuovo"; "OK  $p messo da parte come $($l.n).windows-nuovo"
  } elseif ($item) { if ($l.dir) { cmd /c rmdir "$p" } else { cmd /c del "$p" } }
  $t = "$B\E\claude\$($l.n)"
  if ($l.dir) { cmd /c mklink /D "$p" "$t" | Out-Null } else { cmd /c mklink "$p" "$t" | Out-Null }
  "OK  {0} -> {1}" -f $p, ((Get-Item $p -Force).Target -join '')
}
setx /M OLLAMA_MODELS "$B\E\ollama_models" | Out-Null
'OK  OLLAMA_MODELS = ' + [Environment]::GetEnvironmentVariable('OLLAMA_MODELS', 'Machine')

# --- 6. QoS: "Limita larghezza di banda riservabile" all'8% (richiesta di Fra, = gpedit.msc) ---------
Chiave 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched'
Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched' NonBestEffortLimit 8 -Type DWord
'OK  banda riservabile QoS: 8%'

''
'Regolazioni fatte. Restano a mano: Steam -> libreria D:\SteamLibrary; installare Git, Node e Claude Code'
'(docs/INSTALL.md, FASE 4.4); disconnettersi e rientrare per le cartelle utente.'
