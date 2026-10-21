# FraOS — RUNBOOK DI MIGRAZIONE E INSTALLAZIONE

> ## 🛡️ LE TRE REGOLE CHE IMPEDISCONO DI PERDERE DATI
>
> 1. **Un solo disco collegato durante ogni installazione.** Prima di installare Windows o
>    FraOS si staccano i cavi SATA degli altri due dischi. Con un solo disco visibile,
>    l'installer non può formattare quello sbagliato, né scrivere il bootloader sulla ESP
>    dell'altro sistema ([D-019](DECISIONS.md#d-019), [D-035](DECISIONS.md#d-035)).
> 2. **L'HDD da 1 TB non si formatta mai.** È il porto sicuro: lì sta il backup
>    ([D-017](DECISIONS.md#d-017)).
> 3. **Niente si cancella finché la copia non è stata verificata.** Ogni copia si controlla con
>    `robocopy /L`, che deve elencare zero differenze, prima di toccare l'originale.

> Le scelte dietro ogni passo: [D-017](DECISIONS.md#d-017) backup · [D-019](DECISIONS.md#d-019) dual boot ·
> [D-020](DECISIONS.md#d-020) percorso di installazione · [D-021](DECISIONS.md#d-021) niente rEFInd ·
> [D-033](DECISIONS.md#d-033) dischi · [D-035](DECISIONS.md#d-035) ordine
>
> Stato di avanzamento → [`STATUS.md`](STATUS.md) · Dettagli personali (repo, licenze,
> programmi) → `wiki/` nella cartella del progetto, **solo locale** (non va su GitHub)

## Assetto finale

| Disco | Contenuto | Nel wipe |
|---|---|---|
| **SanDisk SSD 480 GB** (`C:` oggi) | **FraOS** + la sua ESP | ✅ formattato, **per ultimo** |
| **Crucial SSD 120 GB** (`E:` oggi) | **Windows** + la sua ESP | ✅ formattato, **per primo** |
| HDD 1 TB (`D:`) | dati, VM, libreria Steam, `_BACKUP-PREWIPE` | ❌ **mai** |

Boot: niente rEFInd. **F8** all'avvio (ASUS Z370-E) per scegliere il disco, il default da BIOS.

## Cosa c'è sui dischi oggi (misurato il 2026-10-21)

| Disco | Usato / libero | Cosa contiene che conta |
|---|---|---|
| SanDisk `C:` | 431 / 15 GB | Windows attuale; dotfolder in `C:\Users\frhae` (~62 GB, perlopiù cache); **WSL `Ubuntu`** (home 3,6 GB, `~/wh` con **29 commit non pushati**); **Docker Desktop** (18 volumi, ~2 GB, DB di sviluppo); profili browser |
| Crucial `E:` | 39 / 73 GB | ⚠️ **`claude` 2 GB = `~/.claude`** (symlink da `C:`), `ollama_models` **33 GB**, `flutter` 3,4 GB. `llm-group` è una junction verso `D:`: lì non c'è niente da copiare |
| HDD `D:` | 892 / **40 GB** | `SteamLibrary` 298,6 · `VirtualBox VMs` 39,4 · `D:\Users\frhae` (progetti git, Desktop, Documenti, Download: le cartelle utente di Windows **puntano già qui**) |

## L'ordine, in breve

```
FASE 0  prerequisiti, verifiche e decisioni           (zero rischio)
FASE 1  fare spazio sull'HDD                          (si cancella solo roba riscaricabile)
FASE 2  svuotare il Crucial  E: → D:                  (punto di non ritorno per E:)
FASE 3  backup del vecchio Windows  C: → D: + USB/cloud
FASE 4  Windows NUOVO sul Crucial   (solo il Crucial collegato)
        → il vecchio Windows resta avviabile e leggibile: seconda occasione di copia
FASE 5  FraOS sul SanDisk           (solo il SanDisk collegato) ← punto di non ritorno per C:
FASE 6  ripristino su FraOS
FASE 7  pulizia, non prima di 30 giorni
```


---

## FASE 0 — Prerequisiti, verifiche e decisioni (zero rischio)

### 0.1 L'immagine deve essere verde e recente

```bash
gh run list --workflow build.yml --limit 5      # l'ultima deve essere "success" e di oggi/ieri
# data di creazione di :latest, senza credenziali (gh api vorrebbe lo scope read:packages)
T=$(curl -s "https://ghcr.io/token?scope=repository:0franky/fraos:pull" | jq -r .token)
C=$(curl -s -H "Authorization: Bearer $T" -H "Accept: application/vnd.oci.image.manifest.v1+json"   https://ghcr.io/v2/0franky/fraos/manifests/latest | jq -r .config.digest)
curl -sL -H "Authorization: Bearer $T" "https://ghcr.io/v2/0franky/fraos/blobs/$C" | jq -r .created
```
⚠️ Dal 2026-09-28 al 2026-10-21 la build è fallita ogni giorno senza che nessuno lo vedesse
([D-034](DECISIONS.md#d-034)). Fix pushato e **build verde il 2026-10-21** (run 39624317568):
il controllo va comunque rifatto il giorno della FASE 5.

### 0.2 Materiale

- [ ] Chiavetta **A** (≥ 16 GB) per gli installer: prima Windows 11 (Media Creation Tool), poi
      l'ISO **Bazzite GNOME NVIDIA** (https://bazzite.gg)
- [ ] Chiavetta **B**, solo per la seconda copia cifrata (non si riscrive mai; exFAT, non FAT32:
      con FAT32 un file non può superare 4 GB)
- [ ] Accesso fisico ai cavi SATA (case aperto), e l'etichetta su ogni cavo: `SANDISK` · `CRUCIAL` · `HDD`
- [ ] Telefono con le app di autenticazione a due fattori a portata di mano
- [ ] 7-Zip (c'è già) per l'archivio cifrato della 3.7

### 0.3 Verifiche da fare su Windows finché c'è

- [ ] **Salute dell'HDD**: CrystalDiskInfo (o `smartctl -a` da Linux). Deve essere *Buono*.
      Durante la migrazione l'HDD è l'**unica** copia di quasi tutto: se è *Attenzione*, ci vuole
      un disco esterno **prima** di andare avanti
- [ ] **Spegnere l'avvio rapido sul Windows VECCHIO** (prompt amministratore):
      `powercfg /h off`, poi `powercfg /a` non deve più elencare "Avvio rapido".
      Nella FASE 4 due Windows si alternano sullo stesso HDD: con l'avvio rapido acceso, uno dei
      due può riprendere da uno stato NTFS vecchio e **corrompere l'HDD**, che in quel momento è
      l'unica copia di tutto. Per passare da un sistema all'altro: sempre **Riavvia**, mai **Arresta**
- [ ] **Unsloth Studio sulla 2080 Ti** ([D-032](DECISIONS.md#d-032)): è già installato su Windows e
      non ha mai fatto un training (`.unsloth/studio/runs` è vuota). Provare un fine-tuning
      piccolo adesso dice se il rischio aperto è reale, senza aspettare FraOS
- [ ] Windows: Impostazioni → Attivazione → la licenza è **digitale e collegata all'account
      Microsoft** (così si riattiva da sola sulla stessa scheda madre)

### 0.4 Licenze, certificati e credenziali che non stanno in un file (elenco personale nella wiki locale)

- [ ] Annotare i product key che non stanno in un account (Office 2021 LTSC, ecc.)
- [ ] **Disattivare** le licenze legate alla macchina **prima** del wipe (Adobe: esci
      dall'account; software con licenza a nodo: deattivazione dal programma)
- [ ] **Certificato EFS `CN=frhae`** (c'è, con chiave privata): `certmgr.msc` → Personale →
      `frhae` → Esporta → *sì, esporta la chiave privata* → `.pfx` con password. Senza, ogni file
      cifrato con EFS (su `C:` **o su `D:`**) diventa illeggibile per sempre. Controllare se ce ne
      sono con `cipher /u /n /h` (sola lettura); se sì, decifrarli prima con `cipher /d /s:<cartella>`
- [ ] **Gestione credenziali di Windows**: i segreti lì dentro sono cifrati con la chiave
      dell'utente (DPAPI) e spariscono col wipe. Quasi tutti si rifanno con un login; annotare nel
      password manager quelli che non si rigenerano facilmente (token del registry GitLab usato da
      Docker, che ha `credsStore: desktop`; API key di estensioni VS Code)

---

## FASE 1 — Fare spazio sull'HDD

Oggi l'HDD ha **40 GB liberi**. Il backup ne chiede (misurato a secco con `robocopy /L`):

| Cosa | GB | |
|---|---|---|
| `E:\claude` (= `~/.claude`) | 2 | **obbligatorio** |
| home di `C:\Users\frhae` **tutta**, tolte le cache | 20,7 | **obbligatorio**: dentro ci sono dump di DB di produzione, una copia del MinIO di produzione, un repo con commit non pushati (`sim-frontendista`) |
| `C:\Users\frhae\AppData\Roaming`, tolte le cache | 14,5 | **obbligatorio**: config di app (Telegram, MySQL Workbench, FileZilla, Postman, Claude Desktop, VNC/AnyDesk…) |
| export di WSL `Ubuntu` | ~19 | **obbligatorio** (29 commit non pushati in `~/wh`, e credenziali proprie) |
| dump dei DB + volumi Docker | ~3 | **obbligatorio** se servono i DB di sviluppo |
| `C:\RustDeskServer`, `C:\tmp`, `hosts`, profili Wi-Fi | <1 | **obbligatorio** (la chiave del server RustDesk non si rigenera senza riconfigurare i client) |
| `E:\ollama_models` | 33 | facoltativo: riscaricabile, **ma** ci sono modelli personalizzati (`*-ctx16k`, `*-ctx8k`) |
| margine | 20 | per non lavorare a disco pieno |
| **totale** | **~115** | |

**Come liberarli** (decisione di Fra, vedi [`STATUS.md`](STATUS.md) → domande aperte):

- **A — disinstallare la libreria Steam** (298,6 GB) dai launcher: spazio abbondante, ma sul
  Windows nuovo si riscaricano i giochi
- **B — tenere la libreria** e disinstallare solo **Call of Duty** (178 GB da solo; gli altri:
  Apex 90,8 · Splitgate 15,7 · KovaaK's 6,7 · 3DMark 4,3) → **~218 GB liberi**, quasi il doppio
  del necessario. Sul Windows nuovo Steam ritrova il resto in `D:\SteamLibrary` senza
  riscaricare nulla
- In ogni caso: `D:\.pnpm-store` (0,8) e `D:\tmp` (0,6) sono cache

> ⚠️ Fino al 2026-10-21 questo runbook diceva *sia* "disinstallare i giochi" (FASE 1) *sia* "al
> primo avvio di Steam usa `D:\SteamLibrary`, esiste già, ~300 GB" (post-install). Le due cose si
> escludono: va scelta una delle due.

---

## Come si copia (vale per le FASI 2 e 3)

Ogni copia segue lo stesso schema, e **un passo non parte se il precedente non è verde**.
Da incollare una volta nella PowerShell in cui si lavora:

```powershell
function Copia($da, $a, [string[]]$extra) {
  New-Item -ItemType Directory -Force $a | Out-Null        # robocopy NON crea la cartella del log
  robocopy $da $a /E /COPY:DAT /DCOPY:DAT /XJ /R:1 /W:1 /MT:8 @extra /LOG:"$a.log"
  if ($LASTEXITCODE -ge 8) { throw "robocopy $da -> codice $LASTEXITCODE, leggi $a.log" }
  # verifica con un log DIVERSO, sennò sovrascrive quello della copia
  robocopy $da $a /E /XJ /L /NJH /NDL /R:0 /W:0 @extra /LOG:"$a.verifica.log"
  # conteggio indipendente da robocopy
  $n1 = Get-ChildItem $da -Recurse -File -Force -Attributes !ReparsePoint -ErrorAction SilentlyContinue | Measure-Object Length -Sum
  $n2 = Get-ChildItem $a  -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum
  "{0}: origine {1} file / {2:N1} GB - copia {3} file / {4:N1} GB" -f $da, $n1.Count, ($n1.Sum/1GB), $n2.Count, ($n2.Sum/1GB)
}
$B = 'D:\_BACKUP-PREWIPE'
```

- `/XJ` salta **junction e symlink**. Va bene così (le junction puntano a `D:`, i symlink si
  ricreano), ma significa che anche la verifica `/L` non li vede: sono esclusi di proposito
  (12 link a file dentro `ollama_models`, uno in `.claude\debug`)
- Con le cartelle escluse (`/XD`) i due conteggi non coincidono: il confronto vale per le copie
  senza esclusioni (`E:\claude`, `ollama_models`)
- Le copie si lanciano da una **PowerShell normale**, non da dentro Claude Code

---

## FASE 2 — Svuotare il Crucial (`E:` → `D:`)

Il Crucial è il primo disco che si formatta. Va svuotato per intero.

1. **Fermare Claude Code, tutto**, comprese le sessioni sempre accese pilotate da Telegram
   (lavorano dentro `E:\claude`). Chiudere anche Ollama dall'icona nella tray:
   ```powershell
   Get-Process claude, bun, ollama* -ErrorAction SilentlyContinue      # deve restituire VUOTO
   ```
2. Copiare:
   ```powershell
   Copia E:\claude        "$B\E\claude"
   Copia E:\ollama_models "$B\E\ollama_models" @('/XD','.studio_links')   # solo i modelli scelti: wiki/ollama-modelli.md
   ```
   `.studio_links` va escluso esplicitamente: sono 9 symlink di Unsloth Studio verso i blob, e
   robocopy li ha contati come 47,9 GB di file veri anche con `/XJ` (misurato il 2026-10-21).
   Copiarli raddoppierebbe i modelli sull'HDD; Unsloth Studio li ricrea da solo
   `E:\llm-group` è una junction verso `D:`: `/XJ` la salta, non c'è niente da copiare.
   `flutter` non si copia: si riclona. `E:\tmp` è vuota
3. **Ripuntare i symlink di Claude Code** sulla copia, così continua a funzionare sul Windows
   vecchio (prompt amministratore):
   ```powershell
   if (-not (Test-Path "$B\E\claude\.claude\settings.json")) { throw 'copia di .claude assente: FERMATI' }
   # rmdir e del su un symlink tolgono SOLO il link. NON usare Remove-Item: su Windows
   # PowerShell 5.1, con una cartella-symlink, può cancellare il contenuto del bersaglio.
   cmd /c rmdir C:\Users\frhae\.claude
   cmd /c del   C:\Users\frhae\.claude.json
   cmd /c mklink /D C:\Users\frhae\.claude      D:\_BACKUP-PREWIPE\E\claude\.claude
   cmd /c mklink    C:\Users\frhae\.claude.json D:\_BACKUP-PREWIPE\E\claude\.claude.json
   ```
   (`.claude.json.bak-ok` è un terzo link verso `E:`: dopo il wipe resta orfano, è innocuo.)
4. Ollama: `setx /M OLLAMA_MODELS D:\_BACKUP-PREWIPE\E\ollama_models` (la variabile è **di
   sistema**: senza `/M` se ne crea una utente e quella vecchia resta), poi riavviare Ollama
5. Controllo: aprire Claude Code e verificare che veda memoria e skill

---

## FASE 3 — Backup del vecchio Windows (`C:` → `D:`)

L'ordine conta: i container Docker vanno fermati **prima** di spegnere WSL.

### 3.1 Docker: prima i dump, poi i volumi a container fermi
I container girano (Docker Desktop parte da solo, con restart policy): un `tar` della cartella
di Postgres mentre il server scrive può dare un archivio che non riparte.
```powershell
New-Item -ItemType Directory -Force "$B\C\docker" | Out-Null
docker ps -a --format '{{.Names}}  {{.Image}}  {{.Mounts}}' | Out-File -Encoding utf8 "$B\C\docker\container.txt"
docker inspect $(docker ps -aq) | Out-File -Encoding utf8 "$B\C\docker\inspect.json"   # quale volume va a quale container
# dump logici: reggono anche un cambio di versione di Postgres. L'utente va controllato per container
cmd /c "docker exec netview-db pg_dumpall -U postgres > $B\C\docker\netview-db.sql"
cmd /c "docker exec willhouse-postgres pg_dumpall -U postgres > $B\C\docker\willhouse-db.sql"
docker stop $(docker ps -q)
docker volume ls -q | ForEach-Object {
  docker run --rm -v "$($_):/v:ro" -v "$B\C\docker:/b" alpine tar czf "/b/$($_).tgz" -C /v .
}
```
Vault: verificare **dove stanno le chiavi di unseal** e il root token. Senza quelle, i volumi
Vault non servono a niente.

### 3.2 WSL (la home Linux di oggi vive dentro un VHDX su `C:`)
```powershell
# prima, se si può: pushare i 29 commit di ~/wh e committare ~/wh-sa, dall'interno di WSL
wsl --shutdown
wsl --export Ubuntu "$B\C\wsl-ubuntu.tar"        # ~19 GB
```
La home WSL ha **le sue** `.aws`, `.azure`, `.kube`, `.docker`, `.claude`, diverse da quelle di
Windows: anche se `~/wh` si riclona, quelle vanno estratte dalla tar.

### 3.3 La home, **tutta**, tolte le cache
Non una lista di cartelle da salvare (si dimentica sempre qualcosa), ma tutto tranne le cache note:
```powershell
Copia C:\Users\frhae "$B\C\home" @('/XD','AppData','.gradle','.cache','.rustup','.cargo','.bun',
  'scoop','npm-cache','unsloth_compiled_cache','avd','.venv_t5_510','.venv_t5_530','.venv_t5_550',
  'OneDrive','node_modules','/XF','NTUSER.DAT*','ntuser.dat*','UsrClass.dat*')
Copia C:\Users\frhae\AppData\Roaming "$B\C\AppData-Roaming" @('/XD','Cache','Code Cache','GPUCache',
  'CachedData','CachedExtensionVSIXs','Service Worker','logs')
Copia C:\RustDeskServer "$B\C\RustDeskServer"     # chiave privata del server RustDesk
Copia C:\tmp            "$B\C\root-tmp"
Copy-Item C:\Windows\System32\drivers\etc\hosts "$B\C\hosts"    # 95 righe personalizzate
netsh wlan export profile key=clear folder="$B\C\wifi"         # da amministratore: chiavi in chiaro
```
`.claude` è un symlink e `/XJ` lo salta: è già stato copiato nella FASE 2. Nella home ci sono
cartelle che una lista non avrebbe preso: `backups-prod` e `willhouse-backups` (dump di DB di
produzione e staging), `wh-handoff` (copia del MinIO di produzione), `sim-frontendista` (con un
repo da **pushare**: 3 commit), `Developer`, `memory-recovery`, `Il mio Drive (…proj1…)`, la
`Documents` rimasta su `C:` (un workspace di Codex da 3,5 GB). **Dentro `.android` resta
`debug.keystore`**: firma le build Android di debug (`avd`, gli emulatori, si ricreano).

**Controllo di completezza:** elencare `Get-ChildItem C:\Users\frhae -Force -Directory` e
`Get-ChildItem C:\ -Force -Directory`, e spuntare **ogni** voce come *copiata* o *scartata
di proposito*. Nessuna voce senza segno.

### 3.4 Browser: le password non viaggiano con le cartelle
Chrome ed Edge cifrano le password con la chiave dell'utente Windows: una cartella profilo
copiata apre i segnalibri ma **non le password**.
- [ ] Per **ogni** profilo Chrome (3) e per **Edge**: Impostazioni → Password → **Esporta** in
      CSV, più i segnalibri in HTML. `Profile 3` non ha nessun account collegato, quindi non è
      sincronizzato. `Profile 1` è un account universitario: verificare che il sync sia permesso
- [ ] Firefox: la cartella profilo è portabile (è già dentro `AppData-Roaming`), oppure Firefox Sync
- [ ] I CSV contengono password **in chiaro**: vanno solo nell'archivio cifrato (3.7) e si
      cancellano dopo l'importazione

### 3.5 Inventari (servono dopo, per reinstallare)
```powershell
winget export -o "$B\winget.json" --accept-source-agreements
```
L'elenco completo dei programmi e delle 61 estensioni VS Code è già in `wiki/`.

### 3.6 Git
- [ ] I repo con **commit non pushati e un remote** vanno pushati (elenco in
      `wiki/repo-git-stato-2026-10-21.txt`, più `sim-frontendista\willhouse-fe` su `C:` e `~/wh`
      in WSL). I progetti su `D:` il wipe non li tocca, ma un commit pushato sopravvive anche
      alla rottura dell'HDD
- [ ] Il push non salva **modifiche non committate e stash**: per i repo che contano, un commit
      WIP su un branch `backup/prewipe` da pushare, oppure `git bundle create` nella 3.7
- [ ] I repo **senza remote** restano solo su `D:`: decidere quali meritano un repo privato

### 3.7 Seconda copia, fuori dall'HDD, **cifrata** (chiavetta B **e** Google Drive)
```powershell
& 'C:\Program Files\7-Zip\7z.exe' a -p -mhe=on "$B\segreti-prewipe.7z" <elenco qui sotto>
```
`.ssh` · `.gnupg` · `.aws` · `.azure` · `.kube` · i loro gemelli dentro WSL · il `.pfx` EFS ·
certificati Aruba/CNS · config VPN e profili Wi-Fi · i **`.env` dei progetti** (non stanno su
git) · i CSV delle password · `backups-prod`, `willhouse-backups`, `wh-handoff` · `~/.claude` ·
la cartella `wiki/` di FraOS.
La passphrase sta nel password manager, **non** sulla chiavetta. Per copiare su chiavetta
exFAT con robocopy, aggiungere `/FFT` (timestamp a 2 secondi).

### 3.8 Verifica finale, prima della FASE 4
- [ ] Ogni `Copia` ha stampato conteggi coerenti e nessun errore
- [ ] Il controllo di completezza della 3.3 ha una spunta su ogni cartella
- [ ] Google Drive (4 account), OneDrive **e kDrive**: stato "aggiornato" **e**, dal web, si apre un
      file modificato di recente. Con Google Drive in streaming, i file non ancora caricati
      stanno in una cache su `C:` e il wipe li cancellerebbe
- [ ] L'archivio `segreti-prewipe.7z` **si apre** con la passphrase, dalla copia su chiavetta
- [ ] La chiave SSH dell'archivio funziona: `ssh -i <copia> -T git@github.com`
- [ ] Un file a caso per ogni cartella del backup si apre

---

## FASE 4 — Windows nuovo sul Crucial

1. Spegnere. **Staccare i cavi SATA del SanDisk e dell'HDD**: resta collegato solo il Crucial
2. Boot dalla chiavetta A → installare Windows 11 sul Crucial (eliminare le sue partizioni)
3. Spegnere, **ricollegare tutto**. BIOS: primo disco di avvio il Crucial. Il vecchio Windows
   resta avviabile con F8: la sua ESP sta sul SanDisk, e formattare il Crucial non la tocca
4. Le accortezze che fanno stare Windows in 120 GB ([D-033](DECISIONS.md#d-033)):
   ```powershell
   powercfg /h off     # niente ibernazione (~6,5 GB) e niente "avvio rapido"
   manage-bde -status  # Windows 11 può attivare da solo la crittografia: se C: è cifrato,
                       # salvare la chiave di ripristino; D: NON deve risultare cifrato
   ```
   Senza "avvio rapido" Windows chiude l'NTFS in modo pulito: è ciò che permette a FraOS di
   scrivere sull'HDD condiviso.
   - pagefile a 8 GB, o su `D:`
   - Desktop/Documenti/Download/Immagini/Musica/Video → Proprietà → Percorso → le cartelle
     esistenti in `D:\Users\frhae\…`
   - Steam: aggiungere la libreria esistente `D:\SteamLibrary`
   - la prima apertura di `D:\Users\frhae` chiede "Continua" e riscrive i permessi (l'utente è
     nuovo): su centinaia di GB è lento, ma è normale e non è un errore
5. **Seconda occasione**: il `C:` del vecchio Windows ora è un disco dati. Tutto ciò che si
   scopre di aver dimenticato si copia da lì, finché non parte la FASE 5. Per passare da un
   Windows all'altro: **Riavvia**, mai **Arresta**

---

## FASE 5 — FraOS sul SanDisk (punto di non ritorno per il vecchio Windows)

**Prima di partire:** FASE 0.1 verde · checklist 3.8 tutta spuntata · nessun "ah, devo
ancora copiare…" in sospeso.

1. Spegnere. **Staccare i cavi SATA del Crucial e dell'HDD**: resta solo il SanDisk
2. BIOS: UEFI, CSM off, Secure Boot **ON** ([D-015](DECISIONS.md#d-015))
3. Boot dalla chiavetta A con l'ISO Bazzite GNOME NVIDIA → Anaconda → destinazione il SanDisk
   (l'unico disco), eliminando le partizioni del vecchio Windows
4. Primo boot: enrollment MOK, password **`universalblue`**. Verificare desktop e rete
   (l'HDD è staccato: nessun rischio di toccarlo)
5. Spegnere, **ricollegare tutto**, riaccendere su Bazzite e passare a FraOS:
   ```bash
   sudo bootc switch ghcr.io/0franky/fraos:latest
   sudo systemctl reboot
   ```
   Se `bootc switch` rifiuta l'immagine per la policy di firma di Bazzite, la via documentata da
   Universal Blue è `sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/0franky/fraos:latest`
   (da verificare il giorno stesso)

**Se qualcosa non va:**
```bash
sudo bootc rollback && sudo systemctl reboot                 # torna a Bazzite
# Niri non parte ma il sistema è vivo → TTY con Ctrl+Alt+F3 (D-018):
sudo systemctl stop greetd && sudo systemctl start gdm      # sessione GNOME di fallback
```

### Checklist del primo boot
- [ ] Niri parte, DMS mostra la barra
- [ ] `Mod+T` apre kitty · `Mod+D` apre il launcher (se no → `dot_config/niri/config.kdl`)
- [ ] Audio, rete, Bluetooth, luminosità dal control center DMS
- [ ] I Flatpak di first-boot si sono installati (`/usr/share/fraos/flatpaks.list`)
- [ ] `nvidia-smi` vede la 2080 Ti · `podman run --rm --device nvidia.com/gpu=all docker.io/nvidia/cuda:12.6.0-base-ubuntu24.04 nvidia-smi`
- [ ] Screencast/screenshot funzionano (il bug di `portal-gnome`)
- [ ] App X11 (Steam, Discord) partono via `xwayland-satellite`
- [ ] `tailscale up` (poi togliere il vecchio nodo Windows dalla console Tailscale)
- [ ] HDD montato e scrivibile (vedi 6.1)
- [ ] F8 → il Windows nuovo si avvia ancora

---

## FASE 6 — Ripristino su FraOS

### 6.1 L'HDD condiviso
```bash
lsblk -f                                   # trova la partizione NTFS da 931 GB
sudo mkdir -p /var/mnt/dati
U=$(lsblk -no UUID /dev/sdXN); echo "$U"    # sdXN = la partizione NTFS; U non deve essere vuoto
echo "UUID=$U /var/mnt/dati ntfs3 ro,uid=1000,gid=1000,nofail 0 0" | sudo tee -a /etc/fstab
sudo systemctl daemon-reload && sudo mount -a
```
**In sola lettura (`ro`) fino alla FASE 7**: per un mese l'HDD è la sola copia di quasi tutto, e
ciò che serve si copia sul SanDisk prima di lavorarci. Dopo: `ro` → `rw,windows_names`
(`windows_names` impedisce nomi di file che Windows non sa leggere).
Su un sistema atomico `/etc` è scrivibile e persistente: la riga sopravvive ai `bootc upgrade`.

### 6.2 Config e credenziali
Da `/var/mnt/dati/_BACKUP-PREWIPE/C/home`: `.ssh` (`chmod 700 ~/.ssh; chmod 600 ~/.ssh/id_*`),
`.gitconfig`, `.aws`, `.azure`, `.kube`, `.gnupg`, `.codex`, `.gemini`, ecc.

### 6.3 Claude Code
Installer nativo, poi `~/.claude` dalla copia. ⚠️ Hook e script in `~/.claude` contengono
percorsi Windows (`C:/Users/frhae/...`, PowerShell): vanno adattati, non basta copiarli.

### 6.4 Dati di sviluppo
- WSL: `~/wh` si riclona (dopo il push), ma le config della home WSL (`.aws`, `.kube`, …) si
  estraggono da `wsl-ubuntu.tar`
- Volumi Docker: `podman volume import <nome> <file>.tgz`
- Ollama: modelli da `_BACKUP-PREWIPE/E/ollama_models`, **copiati** sul SanDisk (non spostati:
  il backup resta intatto fino alla FASE 7). Dall'HDD un modello da 5 GB si carica in oltre un
  minuto ([D-033](DECISIONS.md#d-033))
- Postgres: si ripristina dai dump `.sql` (`psql -f`), più affidabili dei `tar` dei volumi

### 6.5 VM VirtualBox → KVM ([D-011](DECISIONS.md#d-011))
```bash
qemu-img convert -f vdi -O qcow2 /var/mnt/dati/'VirtualBox VMs'/<vm>/<disco>.vdi ~/VM/<disco>.qcow2
```

### 6.6 Programmi
Flatpak, brew e script in home: elenco ragionato in `wiki/software-inventario.md`.
Stack AI: [`AI-STACK.md`](AI-STACK.md). ArubaSign ([D-013](DECISIONS.md#d-013)):
```bash
systemctl status pcscd ; pcsc_scan ; opensc-tool -l
```

### 6.7 Provare le altre basi ([D-009](DECISIONS.md#d-009))
```bash
sudo bootc switch ghcr.io/0franky/fraos:bluefin   # Secure Boot ON
sudo bootc switch ghcr.io/0franky/fraos:rakuos    # kernel CachyOS — Secure Boot OFF da BIOS
sudo bootc switch ghcr.io/0franky/fraos:bazzite   # ritorno alla default
```

---

## FASE 7 — Pulizia (non prima di 30 giorni di uso)

`_BACKUP-PREWIPE` si cancella solo dopo un mese di uso di entrambi i sistemi senza aver
dovuto ripescare nulla. La copia delle credenziali sulla chiavetta B resta.

---

## Manutenzione ordinaria

| Cosa | Comando |
|---|---|
| Aggiornare | `sudo bootc upgrade` (immagine ricostruita ogni giorno dalla CI) |
| Controllare che la CI sia viva | `gh run list --workflow build.yml --limit 3` |
| Tornare indietro | `sudo bootc rollback` |
| Aggiungere un pacchetto system | riga in `build_files/build.sh` → `./tools/check-packages.sh` → push → `bootc upgrade` |
| Provarne uno al volo | `rpm-ostree install X` (temporaneo; se convince, va in `build.sh`) |
| CLI user-space | `brew install X` |
| App GUI | `flatpak install X` |
