# FraOS — DIARIO DI BORDO

> Cronologia delle sessioni di lavoro: **cosa è successo, quando e con che esito**.
> Serve a ricostruire il filo senza rileggere i transcript.
> Le decisioni prese in ogni sessione hanno la scheda completa in [`DECISIONS.md`](DECISIONS.md).
>
> Ordine: **dal più recente al più vecchio**.

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

**Aperto a fine sessione:** esito della seconda build; rendere pubblico il package GHCR;
decisioni [D-021](DECISIONS.md#d-021) (rEFInd) e [D-023](DECISIONS.md#d-023) (Flatpak).

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
