# FraOS — note di progetto (working notes)

> ⚠️ **ARCHIVIO STORICO — non è più la fonte di verità.**
> Questo è il diario grezzo della sessione del 2026-07-12, conservato perché contiene il
> ragionamento originale nel dettaglio. Dal 2026-08-20 la documentazione viva sta in `docs/`:
> [STATUS](docs/STATUS.md) (dove siamo) · [DECISIONS](docs/DECISIONS.md) (perché) ·
> [JOURNAL](docs/JOURNAL.md) (quando) · [UPSTREAM](docs/UPSTREAM.md) · [INSTALL](docs/INSTALL.md)

> Distro Linux atomica custom di Fra, stile MorrOS. Fonte di verità temporanea finché non scaffoldiamo il repo (poi diventa il design doc / README).

## Identità progetto
- **Nome:** FraOS
- **GitHub:** `0Franky` → immagini su **`ghcr.io/0franky/fraos`**
- **Build tool:** BlueBuild (recipe.yml dichiarativo) · CI GitHub Actions → GHCR · firma **cosign** (obbligatoria di default)
- **Install target:** stock Fedora Atomic → `bootc switch` alla nostra immagine (no ISO custom al primo giro)

## Hardware (questo PC — desktop ASUS ROG STRIX Z370-E)
- CPU Intel i7-8700K (x86-64-v3) · GPU **NVIDIA RTX 2080 Ti (Turing TU102)** · 16 GB RAM
- Dischi: **Windows+giochi → SanDisk SSD 480 GB** + **HDD 1 TB** (librerie/dati condivisi NTFS) · **Linux → Crucial SSD 120 GB**
- BitLocker OFF · UEFI · wipe totale previsto (reinstalla anche Windows)

## Approccio (APPROVATO da Fra)
- **Dual-tag** (una recipe, due basi, stesso layer desktop):
  - `fraos:cachyos` (PRIMARIO) — `FROM ghcr.io/rakuos/rakuos-base-nvidia` (kernel CachyOS + NVIDIA già compilato contro l'ABI CachyOS)
  - `fraos:fedora` (FALLBACK pinnato) — `FROM` base ublue `-nvidia-open` (Bluefin/Aurora dx, NVIDIA-open firmato)
- **Desktop identico nei due:** Niri + DankMaterialShell. Driver NVIDIA presente in ENTRAMBI.
- **Boot manager:** rEFInd (sull'ESP di Windows, chain-load del GRUB di Fedora; install da Windows/live-USB; bootupd lo ignora)
- **Secure Boot OFF** (gratis: niente BitLocker) → modulo NVIDIA non firmato di RakuOS carica senza problemi
- **Fallback kernel:** rollback automatico al deployment precedente; `ostree admin pin` o `bootc switch --retain` per fallback durevole; `bootc switch` tra i due tag
- **De-risk RakuOS (progetto giovane):** il valore (Niri+DMS+config) è nel NOSTRO layer → se RakuOS muore si cambia una riga FROM verso ublue e si rebuilda

## SYSTEM LAYER — da bakare (richiede rebuild → si definisce TUTTO prima, build unica)
### Desktop Niri + DMS
- COPR `yalter/niri` → `niri` (fornisce niri-session + niri.desktop)
- COPR `avengemedia/danklinux` → `dms` (+ **quickshell**; aggiungere `qt6-wayland`, `qt6-multimedia`)
- Companion DMS (bake, leggeri): `matugen`, `dgop`, `cliphist`, `cava`, `dankcalendar`, `danksearch`
- DMS usa ma NON bundle → bake: `wl-clipboard`, `brightnessctl`, `ddcutil`
- Abilitare DMS a build: **`systemctl --global enable dms.service`** (NON `--user`; NON anche `dms run` in niri config = doppio launch)
- **DMS FORNISCE GIÀ (non bakare doppi):** notifiche (mako), lock (swaylock), idle (swayidle), **polkit agent**, launcher (fuzzel), bar (waybar), wallpaper (swaybg), clipboard-history UI, control center rete/BT/audio/luminosità
### Login / DM  [DECISIONE]
- **GDM (base)** = più pulito per "niri default + DE fallback" (auto-lista niri.desktop) → raccomandato
- oppure DankGreeter (`dms-greeter`+greetd) per look coeso — su atomico NON usare `dms greeter install/enable`, solo pacchetto layered + `/etc/greetd/config.toml`
### Wayland essentials (Niri è minimale → bake)
- `xdg-desktop-portal` + `xdg-desktop-portal-gtk` + **`xdg-desktop-portal-gnome`** (screencast; Niri è Smithay → NON `xdg-desktop-portal-wlr`)
- `gnome-keyring`, `xwayland-satellite` (app X11: Steam/Discord), `nautilus` (file-chooser portale GNOME)
- Font: Nerd Font (`jetbrains-mono-nerd-fonts`, COPR `che/nerd-fonts`) + Material Symbols
- Theming Qt/GTK: `qt6ct` (+ `kvantum` opz.), cursor `bibata-cursor-themes`
### Misc comunemente dimenticati (bake)
- `xdg-user-dirs`(+`-gtk`), `xdg-utils`, `power-profiles-daemon`, `bluez`+`blueman`, `pavucontrol`, `accountsservice`, `cups-pk-helper`
### Daemon / hardware (system, richiesti da Fra)
- **Tailscale:** repo `pkgs.tailscale.com/stable/fedora/tailscale.repo` → `tailscale` + enable `tailscaled.service`
- **VPN:** `NetworkManager-openvpn` + `NetworkManager-openvpn-gnome` + `wireguard-tools` (import config a runtime)
- **KVM/QEMU** (scelto da Fra, no VirtualBox): `qemu-kvm libvirt-daemon-kvm libvirt-daemon-config-network virt-install virt-manager virt-viewer` + enable `libvirtd` + utente in gruppo `libvirt`. Convertire VM: `qemu-img convert -f vdi -O qcow2`
- **Firma digitale / smart card (Aruba/CNS):** `pcsc-lite pcsc-tools opensc` + driver PKCS#11 Bit4id/Aruba (RPM vendor). ArubaSign app → AppImage/Distrobox, NON system (verificare path .so del lettore)
- **Terminale + shell:** → da MorrOS (delegato da Fra) + `alacritty` (default niri). tmux richiesto (bake o brew)

## DOCKER — [DECISIONE APERTA]
Fra ha detto "Docker". Su atomico la via pulita NON è sempre bakare docker-ce sull'host (conflitti podman/SELinux). Opzioni da presentare:
1. **podman** (già presente, drop-in `docker`-compat, alias) — atomic-native, no daemon
2. **docker-ce bakato** sull'host + `docker.service` — funziona, meno "pulito"
3. **Docker Engine in Distrobox** — atomic-raccomandato, ma nested
→ per NetView/compose consigliare la più liscia nel documento.

## FLATPAK (default set, no rebuild per aggiungerne dopo)
VS Code (o brew), browser (Firefox/Brave/Chrome), Postman, media (mpv/Celluloid), Boxes(?), ArubaSign(appimage/distrobox)

## BREW (user CLI)
kubectl, aws/az CLI, node/bun/python/go toolchain, ripgrep, lazygit, tmux, gemini/copilot CLI

## DISTROBOX (dev env)
Docker Engine (opzione), dev box per-linguaggio, roba apt/pacman

## Stack utente rilevato (da dotfolders C:\Users\frhae — solo nomi, no contenuti)
cloud: .aws .azure .kube .docker · lang: node/pnpm/bun, python310, .dotnet, flutter/android/expo, gradle/nuget/go · AI: gemini/copilot/claude, ollama · vm: VirtualBox (→ convert KVM) · tool: Postman, OpenVPN, ArubaSign (firma), ssh, gitlab, scoop

## Deliverable in preparazione per Fra (da leggere e ragionarci)
1. Matrice compatibilità Linux / Windows / entrambi
2. Placement su FraOS: system / flatpak / brew / distrobox per ogni tool
3. Review inventario REALE MorrOS (dal repo morrolinux/morros) — utile per te / non serve

## Pending
- [ ] Inventario MorrOS (agente in corso) → shell+terminale+config
- [ ] Decisione Docker
- [ ] Set flatpak finale
- [ ] Poi: scaffold repo BlueBuild + BUILD UNICA
- [ ] Backup (rimandato a pre-install): HDD 1TB come "porto sicuro", libera giochi, consolida prezioso, doppia copia credenziali su cloud/USB, wipe solo i 2 SSD

## UPDATE 2026-07-12 (b) — decisioni + scoperta base
- **Docker → RISOLTO: podman** (Fra ha scelto podman: drop-in, atomic-native, già presente). Docker-ce NON bakato.
- **Distrobox: SÌ** (già incluso nelle basi ublue). Confermato.
- **Terminale = kitty** (da MorrOS, delegato da Fra) + alacritty (default niri). **Shell = bash** (MorrOS non la cambia).
- **SCOPERTA (inventario reale morrolinux/morros, pushed 2026-07-12):** MorrOS OGGI usa base **`ghcr.io/ublue-os/bazzite-gnome-nvidia:stable`**, NON CachyOS. La riga `rakuos-base-nvidia` è **commentata**. Login = greetd + dms-greeter (DankGreeter). DMS via /etc/skel symlink (graphical-session.target.wants). ZERO flatpak. Usa xdg-desktop-portal-wlr (SBAGLIATO per niri-Smithay → noi useremo -gnome). Configs: niri config.kdl in /etc/skel (kitty config presente ma non cablato).
- **RICONSIDERAZIONE BASE** (documento pubblicato per Fra):
  - **Bazzite** (CONSIGLIATA): quello che usa MorrOS; kernel performance/gaming (patch ~CachyOS), NVIDIA FIRMATO → Secure Boot ON ok, rock-solid, Niri+DMS collaudati. Contro: stack gaming inutile per Fra (bloat innocuo). **Se Bazzite → niente tag fallback (rollback basta), 1 immagine.**
  - **Bluefin-dx** (alt pulita): dev-oriented, no bloat gaming, NVIDIA-open firmato SB ON, ma kernel Fedora standard.
  - **RakuOS-CachyOS** (purista): CachyOS vero, ma progetto giovane + NVIDIA non firmato → SB OFF.
  - → **Fra deve scegliere la base** (sblocca lo scaffolding). Ricerca tecnica di dettaglio in corso per sezione "cosa cambia effettivamente".
- **Artifact pubblicato per Fra:** https://claude.ai/code/artifact/374c83f6-ff57-4820-b98b-244e2bd7195d (aggiornabile stesso URL, stesso file `scratchpad/fraos-plan.html`). Da espandere con sezione tecnica base.
- Nota: se base = Bazzite/Bluefin (NVIDIA firmato) → Secure Boot può restare ON (più sicuro). Se RakuOS → SB OFF.

## UPDATE 2026-07-12 (c) — ricerca tecnica basi + raccomandazione affinata
- **Ricerca deep base comparison (verificata):** kernel CachyOS/BORE dà guadagno **~zero** per uso dev/media/general (i benefici sono su frametime giochi + desktop sotto carico, non compile/container/browser). Bazzite kernel = kernel-bazzite (Fedora-ark + patch gaming Valve, NON CachyOS). Bluefin/Aurora = kernel Fedora standard. RakuOS = unico con CachyOS vero.
- NVIDIA/Secure Boot: Bazzite+Bluefin/Aurora = nvidia-open FIRMATO → SB ON (MOK enroll pwd `universalblue`). RakuOS = non firmato → SB OFF. Turing (2080 Ti) supportato da nvidia-open (ublue ha deprecato il proprietario chiuso Ott 2025).
- Baked: Bazzite = stack gaming (Steam/Gamescope/MangoHud) inutile per Fra; **Bluefin-dx = stack DEV** (Docker/podman/QEMU-libvirt/VS Code/devcontainer) = il suo stack; RakuOS minimale.
- **RACCOMANDAZIONE AFFINATA: Bluefin-dx-nvidia-open** (da Bazzite → Bluefin-dx). Motivo: uso dev + gaming su Windows → Bluefin baka i suoi tool, SB ON, backing forte, kernel CachyOS non serve. Aurora-dx = gemello KDE. Bazzite solo se gaming su Linux. RakuOS solo se CachyOS purista.
- Con base ublue stabile: **niente tag fallback** (rollback basta), **Secure Boot ON**, 1 immagine sola.
- **TODO (Fra 13:58): "bump per aggiornare i pacchetti"** = in fase scaffolding: CI GitHub Actions **cron rebuild giornaliero** (auto-pull ultimi pacchetti+base) + `bootc upgrade` sul PC + eventuale Renovate/bump versione base/COPR pin. (Pattern MorrOS: cron 10:05 daily.)
- Artifact aggiornato (v2, stesso URL): sezione "cosa cambia effettivamente" + tabella assi + raccomandazione Bluefin.

## UPDATE 2026-07-12 (d) — decisioni tool (da inventario MorrOS)
- **obs-studio → NO** (escluso)
- **ffmpeg + x264 → SÌ** (codec media; su ublue spesso già via RPMFusion, comunque confermato)
- **iotop · sysstat · just · parallel → SÌ**
- **gnome-terminal → SKIP** (raccomandato): kitty (primario) + alacritty (default niri) = già 2 terminali indipendenti, alacritty è il fallback. gnome-terminal = terzo ridondante. (Riaggiungibile in 1 riga se Fra vuole un GTK classico.)
- **Config kitty di MorrOS → IMPORTARE + DOCUMENTARE (richiesta Fra: "segna dove sono così le posso modificare/cancellare"):**
  - Sorgente MorrOS: `morrolinux/morros` → `build_files/dot_config/kitty/` (presente nel repo ma NON cablata da build.sh → la cabliamo noi).
  - Repo FraOS: `dot_config/kitty/kitty.conf` (sorgente versionata).
  - PC installato: `~/.config/kitty/kitty.conf` (copiata da `/etc/skel/.config/kitty/` alla creazione utente) → mutabile dall'utente.
- **TODO doc:** mantenere nel README FraOS una sezione **"Config incluse + dove trovarle"** (kitty, niri config.kdl, DMS, ecc.) con: sorgente → path in /etc/skel → path runtime `~/.config/...`. Così Fra sa sempre cosa spediamo e dove metterci mano.

## UPDATE 2026-07-12 (e) — BASE DECISA + multi-tag + login + ArubaSign + project home
- **Gaming: minimo, default Windows, possibile su Linux in futuro** → Bazzite default OK (stack gaming non sprecato).
- **BASE DEFAULT = Bazzite** (`ghcr.io/ublue-os/bazzite-gnome-nvidia:stable`), scelta Fra (come MorrOS). SBLOCCA lo scaffolding.
- **MULTI-TAG per provare:** stessa ricetta, 3 tag → `fraos:bazzite` (default) + `fraos:bluefin` (da provare, base `bluefin-dx-nvidia-open`) + `fraos:rakuos` (opz., CachyOS). Provare = `bootc switch ghcr.io/0franky/fraos:<tag>` (1 install, no reinstalli). Bazzite↔Bluefin lisci (SB ON entrambi); RakuOS richiede SB OFF (toggle BIOS) → 3° opzionale.
  - Spazio (indicativo, da confermare): ~10-20 GB/immagine (Bazzite la più grossa). Normale = attivo+rollback (2 depl.). Tutti e 3 pinnati ≈ 3 depl. (~30-50 GB). Consiglio: prova-e-scegli.
- **LOGIN = DankGreeter** (greetd + dms-greeter --command niri, come MorrOS). NON usare `dms greeter install/enable` su atomico → solo pacchetto layered + `/etc/greetd/config.toml`.
- **ArubaSign = AppImage** scaricata a OS avviato → **TODO** (verificare che funzioni). Middleware `pcsc-lite/pcsc-tools/opensc` + driver Aruba/Bit4id resta SYSTEM bakato.
- **PROJECT HOME = `D:\Users\frhae\gitProjects\_current\FraOS`** (file raccolti qui, canonico d'ora in poi; diventerà il repo BlueBuild).
- **PROالسSIMO: scaffolding repo** (base sbloccata): struttura BlueBuild, ricette bazzite/bluefin/rakuos, module system-layer, config kitty/niri/DMS cablate+documentate, CI GitHub Actions cron (bump auto-update) + cosign.

## Backup strategy (congelata, si esegue a ridosso dell'install)
Zero disco esterno → HDD 1TB = porto sicuro: disinstalla giochi (Steam/Ubisoft, ri-scaricabili) → consolida prezioso su D:\_BACKUP-PREWIPE → 2ª copia credenziali (ssh/Aruba/cloud/VPN) su Google Drive/USB → wipe SSD 480 (Windows) + SSD 120 (Linux), HDD NON toccato. Verifiche pre-wipe: GDrive/OneDrive sincronizzati, repo pushati su git.

## UPDATE 2026-07-12 (f) — APPROCCIO DECISO + SCAFFOLD CREATO
- Approccio = ublue image-template (Containerfile + build_files/build.sh), NON BlueBuild.
  Motivo: delivery identica (OCI su GHCR + bootc upgrade), controllo totale in bash dove c'è molta
  logica custom (greetd/DankGreeter, COPR, NVIDIA-toolkit, repo tailscale, /etc/skel), zero traduzione
  da MorrOS, un layer in meno da debuggare, bump+cosign+ISO+renovate già inclusi.
- MorrOS = image-template (verificato clonando morrolinux/morros): base Bazzite, RakuOS commentato.
  Clone di riferimento in scratchpad/morros-ref (non nel repo).
- Scaffold creato in FraOS/: Containerfile (ARG BASE_IMAGE=bazzite), build_files/build.sh, dot_config/{kitty,niri},
  disk_config/{disk,iso}.toml, Justfile (image_name=fraos), .github/workflows/{build,build-variants,build-disk}.yml,
  renovate.json5, dependabot.yml, README.md, LICENSE.
- Delivery tag: build.yml = Bazzite primaria (push + cron giornaliero = bump); build-variants.yml = bluefin+rakuos
  ON-DEMAND per "provare le 3" via bootc switch (1 install, no reinstalli).
- Patch niri config vs MorrOS: rimosso ssh-add /home/morro; Mod+T alacritty->kitty; launcher Mod+D noctalia->dms
  spotlight; +xwayland-satellite; dms/*.kdl placeholder vuoti in skel.
- build.sh vs MorrOS: tolto obs-studio + gnome-terminal; aggiunti tailscale(+enable), tmux, NetworkManager-openvpn
  (+gnome)+wireguard-tools, virt-viewer, pcsc/opensc(+pcscd), podman-docker, distrobox, xwayland-satellite,
  gnome-keyring, xdg-desktop-portal-gtk, Chrome+Flatseal via firstboot flatpak.
- TODO (vedi README): (1) ArubaSign AppImage post-boot; (2) cosign key + SIGNING_SECRET prima del 1° push;
  (3) 1° build CI = validazione nomi pacchetto incerti; (4) verificare IPC launcher DMS; (5) portal -gnome se serve.
- NON ancora fatto: git init + primo push (serve cosign); backup pre-install (rimandato come richiesto).
