# FraOS — DIARIO DI BORDO

> Cronologia delle sessioni di lavoro: **cosa è successo, quando e con che esito**.
> Serve a ricostruire il filo senza rileggere i transcript.
> Le decisioni prese in ogni sessione hanno la scheda completa in [`DECISIONS.md`](DECISIONS.md).
>
> Ordine: **dal più recente al più vecchio**.

---

## 2026-10-24/25 — Sessione 4 (terza parte): FASE 4, Windows nuovo sul Crucial

- **Windows installato sul Crucial** con solo quel disco collegato: ESP propria + Windows (110,7 GB)
  + Recovery. Il SanDisk è intatto con la sua ESP e il vecchio Windows si avvia con F8.
  `powercfg /h off` fatto anche sul nuovo
- **Windows 11 ha cifrato `C:` da solo** (Crittografia dispositivo: 98,1%, protezione ancora
  disattivata, nessuna chiave): da spegnere prima della FASE 5, altrimenti i cambi di Secure Boot
  e MOK possono chiedere la chiave di ripristino
- **Trovato un buco: i permessi su `D:`.** `D:\Users\frhae` e `D:\_BACKUP-PREWIPE` danno accesso
  solo al SID dell'utente vecchio; l'utente del Windows nuovo ha un SID diverso, quindi senza UAC
  elevato non ci entra (Claude Code compreso). Lo corregge `tools/fase4-windows-nuovo.ps1`, insieme
  a lettera dell'HDD, BitLocker, cartelle utente e symlink di Claude Code
- ISO Bazzite GNOME NVIDIA (7.364.149.248 byte) in `D:\_iso`, SHA256 uguale a quello ufficiale
  (`0e35dcb3…451b1c`, dal file `…-CHECKSUM` accanto all'ISO). CI verde ogni giorno (ultimo run 2026-10-24)

---

## 2026-10-21/22 — Sessione 4 (seconda parte): FASI 0-3 del runbook eseguite

- **FASE 0:** SMART dei tre dischi sano (HDD: riallocati, in attesa e non correggibili a 0; il
  SanDisk ha 7 errori CRC, cioè un problema di cavo). Avvio rapido spento. Certificato EFS esportato,
  nessun file cifrato. Unsloth fa davvero il fine-tuning sulla 2080 Ti
- **FASE 1:** cancellato Call of Duty, HDD da 40 a 225 GB liberi. Modelli Ollama sfoltiti a 16,5 GB
  ([D-036](DECISIONS.md#d-036): Ollama resta in prova)
- **FASE 2:** `tools/fase2-svuota-crucial.ps1`, Crucial svuotato, `~/.claude` e Ollama puntati su `D:`
- **FASE 3:** `tools/fase3-backup-windows.ps1`, backup di circa 93 GB (home, Roaming, WSL, Docker con
  dump e volumi). Tre fermate, tutte innocue e tutte corrette nello script (file riscritto da
  Docker Desktop, lock spariti dalla sorgente, lock e log di Parsec). Cartella di backup ristretta
  all'utente: i due account della sandbox di Codex potevano leggerla. Pushati InstrumentStudy e
  kanban-ai; `willhouse-be` e `~/wh` di WSL verificati da **non** pushare. Password dei browser,
  `.env` dei progetti e credenziali raccolti in `segreti-prewipe.7z` (AES-256, nomi cifrati), testato
  e copiato su Telegram e Google Drive. Chiavi SSH della copia provate su GitHub e GitLab: funzionano

---

## 2026-10-21 — Sessione 4: ricognizione completa dopo 8 settimane, piano di migrazione

**Contesto:** progetto fermo dal 2026-08-27. Fra chiede di ricostruire tutto, salvarlo in una
wiki locale e fare un piano di migrazione **senza perdere dati**.

**Fonti:** il repo (unica fonte completa). I transcript delle sessioni di luglio e agosto **non
esistono più** sul disco: le sessioni rimaste (slm, NetView, WillHouse) non parlano mai di FraOS.
L'artifact di luglio sta in un'altra organizzazione claude.ai, ma la sua copia è `PLAN.html`.

**Scoperte, tutte misurate:**

1. 🔴 **La build giornaliera fallisce dal 2026-09-28** (23 build rosse di fila). Causa: Bazzite ora
   porta `terra-ddcutil`, che va in conflitto con il nostro `ddcutil`. `latest` è fermo
   all'immagine del 2026-09-27. Corretto in `build.sh` → [D-034](DECISIONS.md#d-034)
2. 🔴 **`~/.claude` vive sul Crucial 120** (`C:\Users\frhae\.claude` è un symlink a
   `E:\claude\.claude`, 2 GB), cioè sul disco che va formattato per Windows. Non era nel piano
3. 🔴 **Sul Crucial ci sono 39 GB** (`claude` 2, `flutter` 3,4, `ollama_models` 33). A
   agosto il disco era considerato vuoto
4. 🔴 **L'HDD ha solo 40 GB liberi** (ad agosto erano 155). Il backup non ci sta finché non si
   liberano i giochi
5. 🟡 **WSL `Ubuntu` contiene lavoro non pushato**: `~/wh` ha 29 commit non pushati. La home
   WSL sta in un VHDX su `C:` e sparisce col wipe
6. 🟡 **Docker Desktop ha 18 volumi** con dati di sviluppo (`willhouse-sa_postgres_data`,
   `dev_vault-data`, `minio`, …): stanno nel VHDX di Docker su `C:`
7. 🟡 Fra **usa davvero Ollama** (33 GB di modelli su `E:`) e **ha Unsloth Studio** installato su
   Windows: il rischio "Unsloth Studio su Turing" ([D-032](DECISIONS.md#d-032)) si può
   verificare **adesso**, prima di formattare
8. Inventario programmi Windows completo → wiki locale (`wiki/software-inventario.md`)
9. MorrOS: 4 commit nuovi valutati, nessuno recepito → [`UPSTREAM.md`](UPSTREAM.md)

10. **Revisione indipendente del piano** (un agente senza il contesto della sessione): ha trovato
    altri buchi seri, verificati a campione e integrati in [`INSTALL.md`](INSTALL.md): dati di
    produzione in cartelle della home fuori da ogni lista, avvio rapido acceso sul Windows vecchio,
    password dei browser non portabili, un certificato EFS, volumi Docker copiati a DB acceso,
    `robocopy` che con un `/LOG` in una cartella inesistente non copia nulla, e la riga di
    [D-019](DECISIONS.md#d-019) che diceva di staccare il disco sbagliato. Il backup ora copia
    **tutta** la home tranne le cache, con una funzione `Copia` che si ferma al primo errore
    (testata su dati finti)

**Proposta:** invertire l'ordine di installazione, Windows prima e FraOS dopo, un disco collegato
per volta → [D-035](DECISIONS.md#d-035) (PROPOSTA). Piano completo riscritto in
[`INSTALL.md`](INSTALL.md).

---

## 2026-08-27 — Sessione 3: dischi invertiti

*(Ricostruita dal commit `210bd7b`, il transcript non c'è più.)*

Fra chiede se 120 GB per Windows non siano risicati. Rifatti i conti con le misure reali della
macchina: lo stack dev/AI occupa già 68 GB su Windows, e su FraOS crescerebbe. Decisione:
**FraOS sul SanDisk 480, Windows sul Crucial 120** → [D-033](DECISIONS.md#d-033).
Analizzati i dischi: le VM sono già su `D:` (junction), quasi tutto `AppData` è cache. Riscritta
la checklist di backup in [`INSTALL.md`](INSTALL.md).

---

## 2026-08-20 — Sessione 2: ripresa, allineamento upstream, documentazione

**Contesto:** progetto fermo da ~5 settimane. Fra vuole chiudere e installare: Windows non è
più usabile, si formatta.

**Fatto:**
- Ricostruito lo stato dal repo (`NOTES.md` era la SSOT) senza rileggere i transcript
- Verificato che tutte le immagini base esistano ancora e siano aggiornate:
  `bazzite-gnome-nvidia:stable`, `bluefin-dx-nvidia-open:stable`, `rakuos-base-nvidia` (ghcr **e** quay), `ublue-os/brew`
- Verificato l'upstream `morrolinux/morros`: **3 commit nuovi** dopo il nostro scaffold → [`UPSTREAM.md`](UPSTREAM.md)
- Confermato che MorrOS usa tuttora `bazzite-gnome-nvidia:stable`, con la riga RakuOS commentata:
  **la nostra base è identica alla sua**
- Patchato `build_files/build.sh`: niente più rimozione di `gnome-shell`, aggiunto
  `xdg-desktop-portal-gnome`, aggiunti `podman-compose` / `iperf3` / `android-tools`
- Creata la documentazione persistente in `docs/` (STATUS, DECISIONS, JOURNAL, UPSTREAM, INSTALL)
- **`git init`**: da qui in poi ogni decisione è tracciata anche nella storia dei commit

**Decisioni prese:** [D-018](DECISIONS.md#d-018) (GNOME resta) · [D-019](DECISIONS.md#d-019) (dual boot, Windows dopo) ·
[D-020](DECISIONS.md#d-020) (ISO Bazzite + `bootc switch`) · [D-021](DECISIONS.md#d-021) (rEFInd: proposta no) ·
[D-022](DECISIONS.md#d-022) (pacchetti upstream)

**Domande di Fra risolte in sessione:**
- *"Morro su cosa si basa? È lo stesso mio?"* → sì, `bazzite-gnome-nvidia:stable`, identica
- *"Il kernel ottimizzato per Intel?"* → è CachyOS via RakuOS: già previsto come tag `fraos:rakuos`,
  provabile con `bootc switch` senza reinstallare. Guadagno reale ~zero per uso dev (misurato a luglio)
- *"rEFInd me l'avevi controbattuto?"* → no, mai discusso. Ora valutato: [D-021](DECISIONS.md#d-021)

**Seconda parte — validazione senza bruciare CI**

Fra chiede di testare in locale prima di consumare minuti di CI. Docker Desktop non fa partire
il daemon (GUI attiva, backend WSL muto) e in WSL manca `sudo` senza password → niente
container. Ripiegato su un approccio migliore: **scaricare i metadati dei repository e
interrogarli offline** (~25 MB invece di ~20 GB di immagine base).

Risultato: **quattro problemi trovati prima del primo push**, due dei quali avrebbero fatto
fallire la build:

1. 🔴 `quickshell` e `dms-greeter` **non sono** nel COPR `avengemedia/dms` che il build.sh
   aggiungeva (copiato da MorrOS): stanno in `avengemedia/danklinux` → [D-025](DECISIONS.md#d-025)
2. 🔴 `iotop` **non esiste più** in Fedora 43, si chiama `iotop-c` → [D-027](DECISIONS.md#d-027)
3. 🟡 tutti i companion DMS decisi a luglio erano spariti dallo scaffold, incluso
   `material-symbols-fonts` senza cui la shell mostra quadratini; più `playerctl` e `swaylock`,
   invocati dai bind di Niri ma non installati da nessuno → [D-026](DECISIONS.md#d-026)
4. 🟡 il Nerd Font richiesto da `kitty.conf` non esiste nei repo Fedora → [D-028](DECISIONS.md#d-028)

Lo strumento è stato salvato come `tools/check-packages.sh` per riusarlo a ogni modifica
([D-029](DECISIONS.md#d-029)). Validazione finale: **51 pacchetti su 51 risolti**.

Fra ha reso il repo **pubblico** ([D-024](DECISIONS.md#d-024)): Actions gratis illimitate e package
GHCR pullabile senza credenziali.

**Terza parte — primo push e prima build**

Repo pubblicato su `github.com/0Franky/FraOS`, `SIGNING_SECRET` caricato, primo push.
La prima build **fallisce in 30 secondi** (run `32366351579`):

```
[1/2] STEP 3/3: ARG BASE_IMAGE="ghcr.io/ublue-os/bazzite-gnome-nvidia:stable"
Error: determining starting point for build: no FROM statement found
```

Causa: nel `Containerfile` l'`ARG BASE_IMAGE` era scritto **dopo** `FROM scratch AS ctx`,
quindi apparteneva a quello stage invece di essere globale; nel secondo stage
`${BASE_IMAGE}` si espandeva a stringa vuota. MorrOS non ha il problema perché non usa
affatto un ARG (base hardcoded): l'abbiamo introdotto noi per i tag varianti, mettendolo nel
punto sbagliato. Corretto spostando l'ARG prima di ogni `FROM`, con il commento che spiega
il perché così non ci ricasca nessuno.

Nella stessa passata rimossi due **BOM UTF-8** (`Justfile` e `dot_config/niri/config.kdl`),
residui della creazione dei file su Windows. Quello nel `config.kdl` era una mina: sarebbe
finito in `/etc/skel` e avrebbe potuto rompere il parsing della config di Niri al primo boot.

La **seconda build** supera il `FROM`, scarica la base e muore a 3m16s su:

```
Error: building at STEP "... /ctx/build.sh": while running runtime: exit status 126
```

`126` = comando trovato ma non eseguibile: `build.sh` era committato con mode `100644`.
Git su Windows non registra il bit di esecuzione. Corretto con
`git update-index --chmod=+x`, e in più il `Containerfile` ora invoca `bash /ctx/build.sh`
invece di `/ctx/build.sh`: lavorando da Windows il bit `+x` è fragile e non deve poter
rompere di nuovo la build.

> **Nota di metodo.** I primi due fallimenti (`no FROM statement found`, `exit status 126`)
> sono entrambi **attriti Windows→Linux**, non errori di contenuto: la validazione offline dei
> pacchetti non poteva vederli, perché non riguardano *cosa* installiamo ma *come* il file
> arriva nel container. Sono anche entrambi a costo bassissimo (30s e 3m di CI), perché
> falliscono prima delle fasi lente.

La **terza build** arriva molto più in là: supera cinque gruppi di `dnf install` (compreso
`iotop-c`) e muore a 4m29s su un **conflitto vero**:

```
installed package tuned-ppd conflicts with ppd-service provided by power-profiles-daemon
```

`power-profiles-daemon` è uno dei pacchetti aggiunti oggi con [D-026](DECISIONS.md#d-026): le basi
ublue usano `tuned-ppd`, che fornisce lo stesso servizio, e i due si escludono. Rimosso — la
gestione dei profili di alimentazione c'era già.

> Questo è precisamente il **limite dichiarato** della validazione offline: verifica che il nome
> esista, non che la transazione si risolva. Il limite è ora scritto nell'intestazione di
> `tools/check-packages.sh`, con questo caso come esempio.

**Scoperta importante dallo stesso log:** la base non è su Fedora 43 ma su **Fedora 44** (i
pacchetti hanno suffisso `.fc44`). I tag GHCR di Bazzite erano fuorvianti — mostravano ancora
`stable-43`. Lo strumento di validazione ora punta a F44 di default, e l'intestazione spiega che
il modo affidabile per saperlo è leggere un log di build. Rivalidato su F44: **73 pacchetti su 73
risolti**.

Rimosso anche `renovate.json5` su richiesta di Fra dopo averne discusso: era inerte (app non
installata) e duplicava Dependabot — vedi [D-030](DECISIONS.md#d-030).

### 🎉 Quarta build: VERDE

Run `32367884947`, 32m50s. `FraOS` esiste:

```
ghcr.io/0franky/fraos:latest
sha256:38b54169004142074991764f4d09e82be79d5b46343404d8a733e186573d2ef1
5,01 GB compressi · 130 layer · Bazzite GNOME NVIDIA su Fedora 44
```

Verificato dopo la build:
- i tag `latest`, `bazzite`, `20260820` sono **pullabili senza credenziali** → `bootc switch`
  funzionerà senza configurare autenticazione (il timore del package privato era infondato:
  con repo pubblico GHCR eredita la visibilità)
- **firma cosign valida**: `cosign verify --key cosign.pub` conferma
  *"The signatures were verified against the specified public key"*, 4 firme, una per tag
- la nuova configurazione CI funziona: Dependabot ha aperto **una sola PR raggruppata** con 7
  update, e la build su quella PR è risultata `skipped` ([D-030](DECISIONS.md#d-030))

**Bilancio della giornata:** progetto ripreso da fermo, allineato all'upstream, messo sotto git,
documentato, corretto in sei punti (due dei quali avrebbero fatto fallire la build e quattro
avrebbero dato un primo boot difettoso), pubblicato e costruito. Da qui si passa al backup e
all'installazione vera.

**Aperto a fine sessione:** backup pre-wipe (F3); decisioni [D-021](DECISIONS.md#d-021) (rEFInd) e
[D-023](DECISIONS.md#d-023) (set Flatpak).

---

## 2026-07-12 — Sessione 1: dal foglio bianco allo scaffold completo

Giornata unica e lunga, con quattro round di decisioni.

**Mattina — design e requisiti**
- Definito hardware target: ASUS ROG STRIX Z370-E, i7-8700K, RTX 2080 Ti, 16 GB,
  SSD 480 (Windows) + SSD 120 (Linux) + HDD 1 TB (dati)
- Inventariato lo stack utente reale dalle dotfolder di Windows (cloud, linguaggi, AI, VM, tool)
- Prima ipotesi: BlueBuild + dual-tag CachyOS ([D-002](DECISIONS.md#d-002), [D-004](DECISIONS.md#d-004))

**Round (b) — decisioni e scoperta**
- Docker risolto → **podman** ([D-007](DECISIONS.md#d-007)); Distrobox confermato; terminale kitty, shell bash
- **Scoperta dall'inventario reale di `morrolinux/morros`:** MorrOS *oggi* gira su Bazzite,
  non su CachyOS — la riga RakuOS è commentata. Login via greetd + DankGreeter. Zero Flatpak.
  Usa `portal-wlr` (sbagliato per Niri/Smithay)
- Pubblicato per Fra un artifact con il piano

**Round (c) — ricerca tecnica sulle basi**
- Verificato che il kernel CachyOS/BORE rende **~zero** per uso dev/container/browser
- Verificato lo stato NVIDIA/Secure Boot delle tre candidate
- Raccomandazione a Bluefin-dx… che Fra poi non ha seguito (vedi round e)

**Round (d) — scelte sui tool**
- obs-studio e gnome-terminal esclusi; ffmpeg/x264, iotop, sysstat, just, parallel confermati
- Config kitty di MorrOS importate e **documentate** (richiesta esplicita: "segna dove sono
  così le posso modificare o cancellare")

**Round (e) — la base**
- **Fra sceglie Bazzite** ([D-008](DECISIONS.md#d-008)): stessa di MorrOS = massima probabilità che Niri+DMS
  funzionino al primo colpo. Sblocca lo scaffolding
- Multi-tag per provare le tre basi con una sola installazione ([D-009](DECISIONS.md#d-009))
- Login DankGreeter ([D-006](DECISIONS.md#d-006)), ArubaSign AppImage ([D-013](DECISIONS.md#d-013))
- Project home fissata: `D:\Users\frhae\gitProjects\_current\FraOS`

**Round (f) — scaffold**
- Approccio cambiato: BlueBuild → **ublue image-template** ([D-003](DECISIONS.md#d-003))
- Creati: `Containerfile`, `build_files/build.sh`, config kitty+niri, `disk_config/`,
  `Justfile`, i tre workflow CI, renovate/dependabot, README, LICENSE
- Patch alla config Niri di MorrOS: tolto `ssh-add` hardcoded su `/home/morro`,
  `Mod+T` → kitty, `Mod+D` → spotlight DMS, aggiunto `xwayland-satellite`
- Backup pre-install congelato ([D-017](DECISIONS.md#d-017)), da eseguire a ridosso dell'installazione

**Non fatto:** `git init`, push, prima build. Il progetto si ferma qui per ~5 settimane.
