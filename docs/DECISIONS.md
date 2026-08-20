# FraOS — REGISTRO DELLE DECISIONI (ADR)

> **Ogni scelta di progetto vive qui**, con data, motivo e conseguenze.
> Le decisioni **non si cancellano mai**: quando una viene sostituita passa a
> `SUPERATA` e punta a quella che la rimpiazza. Così l'albero delle decisioni
> resta leggibile anche a distanza di mesi.
>
> **Stati:** `ACCETTATA` · `SUPERATA` (rimpiazzata) · `APERTA` (da decidere) · `PROPOSTA` (in attesa di conferma di Fra)
>
> Stato corrente del progetto → [`STATUS.md`](STATUS.md) · Cronologia → [`JOURNAL.md`](JOURNAL.md)

## Indice rapido

| ID | Decisione | Stato | Data |
|---|---|---|---|
| [D-001](#d-001) | Identità: FraOS, immagini su `ghcr.io/0franky/fraos` | ACCETTATA | 2026-07-12 |
| [D-002](#d-002) | Build tool = BlueBuild | **SUPERATA** → D-003 | 2026-07-12 |
| [D-003](#d-003) | Build tool = ublue image-template (Containerfile + build.sh) | ACCETTATA | 2026-07-12 |
| [D-004](#d-004) | Base = dual-tag con CachyOS primario | **SUPERATA** → D-008 | 2026-07-12 |
| [D-005](#d-005) | Desktop = Niri + DankMaterialShell | ACCETTATA | 2026-07-12 |
| [D-006](#d-006) | Login = greetd + DankGreeter | ACCETTATA | 2026-07-12 |
| [D-007](#d-007) | Container runtime = podman (no docker-ce) | ACCETTATA | 2026-07-12 |
| [D-008](#d-008) | Base default = Bazzite GNOME NVIDIA | ACCETTATA | 2026-07-12 |
| [D-009](#d-009) | Multi-tag: bazzite / bluefin / rakuos su una sola installazione | ACCETTATA | 2026-07-12 |
| [D-010](#d-010) | Terminale kitty + alacritty, shell bash | ACCETTATA | 2026-07-12 |
| [D-011](#d-011) | Virtualizzazione = KVM/QEMU, non VirtualBox | ACCETTATA | 2026-07-12 |
| [D-012](#d-012) | Esclusi: obs-studio, gnome-terminal | ACCETTATA | 2026-07-12 |
| [D-013](#d-013) | ArubaSign = AppImage post-boot, middleware bakato | ACCETTATA | 2026-07-12 |
| [D-014](#d-014) | Aggiornamenti = cron CI giornaliero + `bootc upgrade` | ACCETTATA | 2026-07-12 |
| [D-015](#d-015) | Secure Boot ON | ACCETTATA | 2026-07-12 |
| [D-016](#d-016) | Portal = solo `-wlr` | **SUPERATA** → D-018 | 2026-07-12 |
| [D-017](#d-017) | Strategia di backup pre-wipe | ACCETTATA | 2026-07-12 |
| [D-018](#d-018) | GNOME resta installato + `portal-gnome` esplicito | ACCETTATA | 2026-08-20 |
| [D-019](#d-019) | Dual boot con Windows reinstallato **dopo** FraOS | ACCETTATA | 2026-08-20 |
| [D-020](#d-020) | Installazione via ISO Bazzite ufficiale + `bootc switch` | ACCETTATA | 2026-08-20 |
| [D-021](#d-021) | rEFInd | **PROPOSTA: no** | 2026-08-20 |
| [D-022](#d-022) | Allineamento pacchetti all'upstream (agosto) | ACCETTATA | 2026-08-20 |
| [D-023](#d-023) | Set Flatpak finale | **APERTA** | — |

---

## D-001
### Identità: FraOS, immagini su `ghcr.io/0franky/fraos`
**Stato:** ACCETTATA · **Data:** 2026-07-12

Distro atomica personale di Fra, sul modello di MorrOS. Account GitHub `0Franky`, registry GHCR.
Il repo va creato con nome **minuscolo** (`fraos`): il workflow usa il nome repo come nome immagine.

---

## D-002
### Build tool = BlueBuild
**Stato:** SUPERATA da [D-003](#d-003) · **Data:** 2026-07-12

Prima ipotesi: `recipe.yml` dichiarativo, più leggibile. Abbandonata lo stesso giorno — vedi D-003.

---

## D-003
### Build tool = ublue image-template (Containerfile + `build_files/build.sh`)
**Stato:** ACCETTATA · **Data:** 2026-07-12 · **Sostituisce:** D-002

**Perché:** la delivery è identica (immagine OCI su GHCR + `bootc upgrade`), ma qui abbiamo
controllo totale in bash proprio dove la logica è densa (greetd/DankGreeter, repo COPR,
NVIDIA toolkit, repo Tailscale, `/etc/skel`). In più: zero traduzione da MorrOS — che usa lo
stesso template — quindi possiamo copiare e confrontare riga per riga, e un layer in meno da
debuggare. Bump, cosign, generazione ISO e renovate sono già inclusi nel template.

**Conseguenza:** ogni personalizzazione di sistema è una riga in `build_files/build.sh`.

---

## D-004
### Base = dual-tag, CachyOS (RakuOS) primario + Fedora fallback
**Stato:** SUPERATA da [D-008](#d-008) · **Data:** 2026-07-12

Ipotesi iniziale: `fraos:cachyos` primario (kernel CachyOS + NVIDIA precompilato) e
`fraos:fedora` come fallback pinnato. Superata dopo la ricerca tecnica: il kernel CachyOS dà
guadagno ~zero per uso dev/browser/container, e RakuOS ha il modulo NVIDIA non firmato.
L'idea del multi-tag è però sopravvissuta in forma diversa → [D-009](#d-009).

---

## D-005
### Desktop = Niri + DankMaterialShell (DMS)
**Stato:** ACCETTATA · **Data:** 2026-07-12

Niri = compositor Wayland scrollable-tiling (Smithay). DMS fornisce già barra, notifiche, lock,
idle, agente polkit, launcher, wallpaper, clipboard e control center → **non vanno bakati doppioni**.
Companion leggeri inclusi: `matugen`, `dgop`, `cliphist`, `cava`.
DMS si abilita con `systemctl --global enable dms.service` (NON `--user`, e NON anche `dms run`
nella config di Niri: sarebbe un doppio avvio).

---

## D-006
### Login = greetd + DankGreeter (`dms-greeter --command niri`)
**Stato:** ACCETTATA · **Data:** 2026-07-12

Alternativa valutata: GDM (più pulito per "Niri default + DE di fallback in lista").
Scelto DankGreeter per coerenza visiva con DMS, come MorrOS.

**Attenzione (su atomico):** NON usare `dms greeter install/enable`. Solo pacchetto layered +
`/etc/greetd/config.toml` scritto a build time.
**Conseguenza:** il greeter lancia Niri e basta, non offre un selettore di sessione → il fallback
GNOME si raggiunge da TTY, vedi [D-018](#d-018).

---

## D-007
### Container runtime = podman (docker-ce NON bakato)
**Stato:** ACCETTATA · **Data:** 2026-07-12

Tre opzioni valutate: podman / docker-ce sull'host / Docker Engine in Distrobox.
Scelto **podman**: già presente nelle basi ublue, atomic-native, nessun daemon, e con
`podman-docker` + `podman-compose` è drop-in per i comandi `docker` e `docker compose`.
Docker-ce sull'host su atomico crea conflitti con podman e SELinux.

Distrobox resta incluso (arriva con le basi ublue) per gli ambienti di sviluppo.

---

## D-008
### Base default = `ghcr.io/ublue-os/bazzite-gnome-nvidia:stable`
**Stato:** ACCETTATA · **Data:** 2026-07-12 · **Sostituisce:** D-004

Confronto fatto su tre candidate:

| Base | Kernel | NVIDIA | Baked | Verdetto |
|---|---|---|---|---|
| **Bazzite** | kernel-bazzite (Fedora-ark + patch Valve) | firmato → SB ON | stack gaming | **SCELTA** — è quella di MorrOS, collaudata con Niri+DMS |
| Bluefin-dx | Fedora standard | nvidia-open firmato → SB ON | stack dev | raccomandata a metà giornata, poi scartata da Fra |
| RakuOS | **CachyOS vero** (BORE, x86-64-v3) | non firmato → SB OFF | minimale | progetto giovane, resta come tag di prova |

**Motivo della scelta di Fra:** stessa base di MorrOS = massima probabilità che Niri+DMS
funzionino al primo colpo. Il gaming resta su Windows, quindi lo stack gaming di Bazzite è
peso morto ma innocuo.

**Verificato il 2026-08-20:** l'immagine esiste ancora ed è aggiornata.

---

## D-009
### Multi-tag: `bazzite` (default) + `bluefin` + `rakuos`, su una sola installazione
**Stato:** ACCETTATA · **Data:** 2026-07-12

Stessa ricetta, tre basi. `build.yml` costruisce la primaria (Bazzite);
`build-variants.yml` costruisce le altre due su richiesta.

Sulla macchina si passa da una all'altra **senza reinstallare**:
```bash
sudo bootc switch ghcr.io/0franky/fraos:bluefin   # SB ON, switch liscio
sudo bootc switch ghcr.io/0franky/fraos:rakuos    # kernel CachyOS, richiede SB OFF da BIOS
sudo bootc switch ghcr.io/0franky/fraos:bazzite   # ritorno alla default
```
La precedente resta disponibile come rollback. Costo indicativo: ~10-20 GB per immagine.

---

## D-010
### Terminale = kitty (+ alacritty), shell = bash
**Stato:** ACCETTATA · **Data:** 2026-07-12

kitty è il primario, con le config importate da MorrOS; alacritty resta come default di Niri e
fallback. `gnome-terminal` escluso ([D-012](#d-012)): sarebbe un terzo ridondante.
Shell bash (MorrOS non la cambia). `tmux` bakato.

---

## D-011
### Virtualizzazione = KVM/QEMU (non VirtualBox)
**Stato:** ACCETTATA · **Data:** 2026-07-12

Bakati `qemu-kvm`, `libvirt`, `virt-manager`, `virt-viewer`; `libvirtd` abilitato.
**Migrazione delle VM esistenti:** `qemu-img convert -f vdi -O qcow2 disco.vdi disco.qcow2`

---

## D-012
### Esclusi esplicitamente: obs-studio, gnome-terminal
**Stato:** ACCETTATA · **Data:** 2026-07-12

Entrambi presenti in MorrOS, entrambi non serventi. Riaggiungibili con una riga in `build.sh`.
`ffmpeg` + `x264` restano (codec), via RPM Fusion.

---

## D-013
### ArubaSign = AppImage scaricata a OS avviato; middleware smartcard bakato
**Stato:** ACCETTATA · **Data:** 2026-07-12

Nell'immagine va solo il middleware: `pcsc-lite`, `pcsc-tools`, `opensc`, con `pcscd` abilitato.
L'app in sé no: è un'AppImage, non ha senso metterla in un'immagine immutabile.

**Da verificare a OS avviato:** che l'AppImage veda davvero il lettore. Se no → Distrobox,
oppure la firma digitale resta su Windows.

---

## D-014
### Aggiornamenti = cron CI giornaliero (bump) + `bootc upgrade`
**Stato:** ACCETTATA · **Data:** 2026-07-12

Richiesta esplicita di Fra ("bump per aggiornare i pacchetti"). Implementato come
`schedule: cron '05 10 * * *'` in `build.yml`: ogni giorno l'immagine viene ricostruita sulla base
aggiornata e sui pacchetti aggiornati. Sul PC si applica con `sudo bootc upgrade` (o dal timer
automatico di ublue). Si torna indietro con `sudo bootc rollback`.

Renovate e Dependabot sono configurati per gli aggiornamenti delle Action.

---

## D-015
### Secure Boot ON
**Stato:** ACCETTATA · **Data:** 2026-07-12

Possibile perché Bazzite e Bluefin usano `nvidia-open` **firmato** (enrollment MOK con password
`universalblue` al primo boot). Vantaggio collaterale: niente rogne con BitLocker su Windows.
**Eccezione:** il tag `rakuos` ha il modulo non firmato → per provarlo serve disattivare SB da BIOS.

---

## D-016
### Portal = solo `xdg-desktop-portal-wlr`, con rimozione di gnome-shell
**Stato:** SUPERATA da [D-018](#d-018) · **Data:** 2026-07-12

Copiato da MorrOS di luglio. Già allora nelle note c'era il dubbio ("Niri è Smithay, non wlroots
→ servirebbe `-gnome`"), ma nello scaffold è rimasto `-wlr`. L'upstream ha poi confermato che
era sbagliato.

---

## D-017
### Strategia di backup pre-wipe
**Stato:** ACCETTATA (congelata, si esegue a ridosso dell'installazione) · **Data:** 2026-07-12

Nessun disco esterno disponibile → **l'HDD da 1 TB fa da porto sicuro** e non viene toccato dal wipe.

1. Disinstallare i giochi (Steam/Ubisoft: ri-scaricabili) per liberare spazio
2. Consolidare tutto il prezioso in `D:\_BACKUP-PREWIPE`
3. Seconda copia delle credenziali (ssh, Aruba, cloud, VPN) su Google Drive **e** chiavetta USB
4. Verifiche pre-wipe: GDrive/OneDrive sincronizzati, **tutti i repo git pushati**
5. Wipe **solo** dei due SSD (SanDisk 480 = Windows, Crucial 120 = Linux). HDD 1 TB intatto

---

## D-018
### GNOME resta installato + `xdg-desktop-portal-gnome` esplicito
**Stato:** ACCETTATA · **Data:** 2026-08-20 · **Sostituisce:** D-016

**Contesto:** l'upstream ha corretto proprio questo punto dopo il nostro scaffold
(commit `8843559` del 12/07 e `75e8ba8` "fix screen capture" del 19/07, vedi [`UPSTREAM.md`](UPSTREAM.md)).
Rimuovendo `gnome-shell` si porta via `xdg-desktop-portal-gnome` → **screen capture rotto**.

**Decisione:** non rimuoviamo più `gnome-shell`, e installiamo esplicitamente
`xdg-desktop-portal-gnome` (oltre a `-wlr` e `-gtk`), senza dipendere dalle scelte dell'upstream.

**Conseguenze:**
- Screencast/screenshot funzionanti sotto Niri (che è Smithay, non wlroots)
- **Sessione di fallback**: se Niri non parte, da TTY (`Ctrl+Alt+F3`):
  ```bash
  sudo systemctl stop greetd && sudo systemctl start gdm
  ```
  È la rete di sicurezza per il primo boot, dove il rischio è più alto
- Costo: qualche centinaio di MB su un'immagine già grande. Accettato

---

## D-019
### Dual boot, con Windows reinstallato **dopo** FraOS
**Stato:** ACCETTATA · **Data:** 2026-08-20

**Assetto:** FraOS sul **Crucial SSD 120 GB**, Windows sul **SanDisk SSD 480 GB**, HDD 1 TB
condiviso e mai toccato. Ogni SSD ha la propria ESP → i due sistemi restano indipendenti.

**Ordine:** prima FraOS (sblocca subito la migrazione), Windows nei giorni successivi con calma.

⚠️ **Rischio e mitigazione obbligatoria:** l'installer di Windows, se trova una ESP già esistente
su un altro disco, può scriverci dentro il proprio bootloader e riordinare il boot.
→ **Installare Windows con il cavo SATA del Crucial 120 fisicamente scollegato.** Ricollegarlo dopo.

---

## D-020
### Installazione via ISO Bazzite ufficiale + `bootc switch`
**Stato:** ACCETTATA · **Data:** 2026-08-20

**Alternativa scartata:** ISO custom generata da `build-disk.yml` (un passo solo, ma è un pezzo di
CI mai testato — se l'ISO è rotta lo scopri con il PC già formattato).

**Percorso scelto:** installare Bazzite ufficiale (installer Anaconda collaudato), poi un solo comando:
```bash
sudo bootc switch ghcr.io/0franky/fraos:latest && sudo systemctl reboot
```
Se FraOS avesse problemi, sotto c'è un sistema funzionante e `bootc rollback` che riporta indietro.
Il workflow `build-disk.yml` resta nel repo, utile in futuro per installare su altre macchine.

---

## D-021
### rEFInd come boot manager
**Stato:** **PROPOSTA — non installarlo** (in attesa di conferma di Fra) · **Data:** 2026-08-20

**Contesto:** rEFInd compare nelle note del 12/07 come dato di fatto, senza che ne sia mai stato
discusso il costo. Con l'assetto deciso in [D-019](#d-019) la valutazione cambia.

**Proposta: non installarlo**, almeno all'inizio.

| Argomento | |
|---|---|
| Non risolve un problema esistente | Due dischi, **due ESP separate**. Sulla ASUS Z370-E si sceglie il disco con **F8**; il default si imposta da BIOS o con `efibootmgr -o`. rEFInd serve per la contesa fra OS sullo stesso disco |
| È l'unico pezzo non gestito | Su atomico `bootupd` aggiorna GRUB/shim da solo. rEFInd andrebbe aggiornato a mano: l'unico componente mutabile in un sistema immutabile, e l'unico che `bootc rollback` non recupera |
| Attrito con Secure Boot ON ([D-015](#d-015)) | rEFInd non è firmato Microsoft: servirebbe firmarlo con MOK + shim |
| Rimandarlo costa zero | È puramente additivo: installabile sull'ESP in qualsiasi momento, senza toccare né Linux né Windows |

**Se in futuro serve** (es. i due OS finiscono sullo stesso disco, o F8 diventa fastidioso):
si installa in ~10 minuti e questa decisione viene superata da una nuova.

---

## D-022
### Allineamento pacchetti all'upstream di agosto
**Stato:** ACCETTATA · **Data:** 2026-08-20

Dal commit upstream `557a52d` (2026-08-19) recepiamo:

| Pacchetto | Esito | Perché |
|---|---|---|
| `podman-compose` | ✅ preso | serve per gli stack compose (NetView) |
| `iperf3` | ✅ preso | test di banda, coerente con il lavoro di rete di Fra |
| `android-tools` | ✅ preso | adb/fastboot, c'è uno stack Flutter/Android/Expo |
| `ktls-utils` | ❌ scartato | TLS in kernel, nessun caso d'uso |

---

## D-023
### Set Flatpak finale
**Stato:** **APERTA** — decide Fra

Oggi in `/usr/share/fraos/flatpaks.list` (installati al primo boot) ci sono solo:
`com.google.Chrome`, `com.github.tchx84.Flatseal`.

Candidati dall'inventario di luglio, mai confermati: **VS Code** (o via brew), **Postman**,
un secondo browser (Firefox/Brave), un player video (mpv è già bakato nativo), Boxes.

**Non è bloccante:** i Flatpak si installano anche a mano dopo, senza ricostruire l'immagine.
Metterli in lista serve solo ad averli già pronti al primo boot.
