#!/bin/bash
#
# FraOS — build script (layered on top of the base image, default: Bazzite).
# Struttura e molti pattern adattati da MorrOS (morrolinux/morros, ublue image-template).
# Ogni riga qui = una personalizzazione permanente e riproducibile dell'immagine.
#
# Per AGGIUNGERE un pacchetto system: aggiungi una riga `dnf -y install X` nella
# sezione giusta, poi commit+push -> la CI ribuilda -> sulla macchina `bootc upgrade`.
#
set -ouex pipefail

### ------------------------------------------------------------------ ###
### 0. DNF5 speedup                                                     ###
### ------------------------------------------------------------------ ###
sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf

### ------------------------------------------------------------------ ###
### 1. Desktop di base: NON lo rimuoviamo.                              ###
###    Niri + DMS e' la sessione primaria, ma gnome-shell resta         ###
###    installato di proposito, per due motivi:                         ###
###      a) rimuoverlo si porta via xdg-desktop-portal-gnome ->         ###
###         screen capture rotto (bug incontrato e poi corretto da      ###
###         MorrOS, commit 75e8ba8 "fix screen capture", 2026-07-19);   ###
###      b) e' la nostra sessione di FALLBACK: se Niri non parte,       ###
###         da un TTY (Ctrl+Alt+F3):                                    ###
###           sudo systemctl stop greetd && sudo systemctl start gdm    ###
###    Costo: qualche centinaio di MB su un'immagine gia' grossa.       ###
### ------------------------------------------------------------------ ###
# (nessuna rimozione: vedi sopra)

### ------------------------------------------------------------------ ###
### 2. Wayland core + portals                                          ###
###    -gnome: screencast sotto Niri (Smithay) + file chooser.         ###
###    -wlr:   come MorrOS, per le app che parlano wlroots.            ###
###    -gtk:   file chooser GTK.                                       ###
###    NB: portal-gnome arriva gia' con la base, lo installiamo         ###
###    esplicitamente per non dipendere dalle scelte dell'upstream.     ###
### ------------------------------------------------------------------ ###
dnf -y install pipewire xdg-desktop-portal-gnome xdg-desktop-portal-wlr xdg-desktop-portal-gtk

### ------------------------------------------------------------------ ###
### 3. SYSTEM apps — daemon / hardware / virtualizzazione / tooling     ###
###    (roba che DEVE stare nell'immagine, non Flatpak/Brew)            ###
### ------------------------------------------------------------------ ###
# Virtualizzazione: KVM/QEMU (NON VirtualBox). Converti i .vdi con:
#   qemu-img convert -f vdi -O qcow2 disco.vdi disco.qcow2
dnf -y install libvirt qemu-kvm virt-manager virt-viewer

# Tooling di base
dnf -y install \
  flatpak-builder \
  wlr-randr \
  iotop-c sysstat \
  lxqt-openssh-askpass lxpolkit \
  parallel just \
  tmux \
  seahorse gnome-keyring \
  distrobox \
  podman-docker podman-compose

# Networking diagnostics + Android/adb (allineati a MorrOS 557a52d, 2026-08-19;
# ktls-utils volutamente escluso). iperf3 = test banda, android-tools = adb/fastboot.
dnf -y install iperf3 android-tools

# Pezzi "da desktop" che su Bazzite ci sono gia' (GNOME completo), ma che
# elenchiamo esplicitamente: le basi alternative dei tag `bluefin` e soprattutto
# `rakuos` sono piu' minimali, e Niri da solo non porta nulla di tutto questo.
dnf -y install \
  xdg-user-dirs xdg-user-dirs-gtk xdg-utils \
  power-profiles-daemon \
  bluez blueman \
  pavucontrol \
  accountsservice \
  cups-pk-helper

# Networking / VPN: OpenVPN (+ GUI NetworkManager) e WireGuard
dnf -y install NetworkManager-openvpn NetworkManager-openvpn-gnome wireguard-tools

# Smartcard / firma digitale (CNS). Il MIDDLEWARE sta qui (system);
# l'app ArubaSign vera e' una AppImage scaricata a OS avviato (vedi README TODO).
dnf -y install pcsc-lite pcsc-tools opensc

# Tailscale (repo ufficiale Fedora)
curl -fsSL https://pkgs.tailscale.com/stable/fedora/tailscale.repo -o /etc/yum.repos.d/tailscale.repo
dnf -y install tailscale

# App X11 sotto Niri (Smithay non porta Xwayland integrato)
dnf -y install xwayland-satellite || true

### ------------------------------------------------------------------ ###
### 4. USER apps native (GUI leggere / CLI). Le app GUI "grosse"        ###
###    (Chrome, ...) vanno via Flatpak — vedi sezione 9.                ###
### ------------------------------------------------------------------ ###
dnf -y install nautilus kitty mpv gnome-system-monitor gnome-calculator loupe
# NOTE FraOS: gnome-terminal NON installato (kitty e' il terminale).
#             obs-studio NON installato (scelta esplicita).

### ------------------------------------------------------------------ ###
### 5. Multimedia completo: RPM Fusion + ffmpeg/x264 (NO obs)           ###
### ------------------------------------------------------------------ ###
dnf -y install \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
dnf -y install ffmpeg x264-libs libva-utils --allowerasing

# nautilus-open-any-terminal (repo aggiunto; install lasciato commentato come MorrOS)
curl -Lo /etc/yum.repos.d/nautilus-open-any-terminal.repo \
  https://copr.fedorainfracloud.org/coprs/monkeygold/nautilus-open-any-terminal/repo/fedora-$(rpm -E %fedora)/monkeygold-nautilus-open-any-terminal-fedora-$(rpm -E %fedora).repo
# dnf -y install nautilus-open-any-terminal

### ------------------------------------------------------------------ ###
### 6. Niri (compositor scrollable-tiling Wayland)                      ###
### ------------------------------------------------------------------ ###
dnf -y install niri

# Cursore Bibata
curl -Lo /etc/yum.repos.d/peterwu.repo \
  https://copr.fedorainfracloud.org/coprs/peterwu/rendezvous/repo/fedora-$(rpm -E %fedora)/peterwu-rendezvous-fedora-$(rpm -E %fedora).repo
dnf -y install bibata-cursor-themes

# --- Font ---------------------------------------------------------------
# kitty.conf chiede "JetBrainsMono Nerd Font": la versione PATCHATA con i glifi
# non esiste nei repo Fedora, va presa dalla release upstream. Senza, kitty
# ripiega su un font di sistema e i glifi del prompt diventano quadratini.
dnf -y install jetbrains-mono-fonts
NERD_FONTS_VER="v3.5.0"
curl -fsSL -o /tmp/JetBrainsMono.tar.xz \
  "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VER}/JetBrainsMono.tar.xz"
mkdir -p /usr/share/fonts/jetbrains-mono-nerd
tar -xJf /tmp/JetBrainsMono.tar.xz -C /usr/share/fonts/jetbrains-mono-nerd
rm -f /tmp/JetBrainsMono.tar.xz
fc-cache -f /usr/share/fonts/jetbrains-mono-nerd

# --- Theming Qt (le app GTK seguono gia' il tema di sistema) -------------
dnf -y install qt6ct

### ------------------------------------------------------------------ ###
### 7. DankMaterialShell (DMS) + greetd + DankGreeter                   ###
###                                                                     ###
###    SERVONO DUE COPR DISTINTI (verificato il 2026-08-20 leggendo i    ###
###    repodata di fedora-43-x86_64):                                    ###
###      avengemedia/dms        -> dms, dms-cli, dgop                    ###
###      avengemedia/danklinux  -> quickshell, dms-greeter, matugen,     ###
###                                cliphist, danksearch,                 ###
###                                material-symbols-fonts                ###
###    MorrOS aggiunge solo il primo: con quello `dnf install quickshell ###
###    dms-greeter` NON risolve. Non copiare quel pezzo da lui.          ###
### ------------------------------------------------------------------ ###
for copr in dms danklinux; do
  curl --output-dir "/etc/yum.repos.d/" --remote-name \
    "https://copr.fedorainfracloud.org/coprs/avengemedia/${copr}/repo/fedora-$(rpm -E %fedora)/avengemedia-${copr}-fedora-$(rpm -E %fedora).repo"
done

# Runtime Qt: quickshell (su cui gira DMS) e' un'app Qt6/QML
dnf -y install qt6-qtwayland qt6-qtdeclarative qt6-qtmultimedia qt6-qtsvg

dnf -y install quickshell dms greetd dms-greeter --allowerasing

# Companion di DMS: li USA ma non li porta con se'.
#   matugen                -> colori dinamici dal wallpaper
#   material-symbols-fonts -> le ICONE della shell (senza, l'interfaccia e' piena di quadratini)
#   cliphist               -> storico appunti
#   danksearch, dgop       -> ricerca e monitor di sistema
#   wl-clipboard           -> copia/incolla da CLI
#   brightnessctl, ddcutil -> luminosita' (laptop / monitor esterni via DDC)
#   cava                   -> visualizzatore audio del widget musica
dnf -y install matugen material-symbols-fonts cliphist danksearch dgop
dnf -y install wl-clipboard brightnessctl ddcutil cava

# Comandi richiesti dai bind in dot_config/niri/config.kdl: senza questi,
# quelle scorciatoie sono morte (verificato leggendo la config, 2026-08-20).
#   playerctl -> tasti multimediali play/pausa/avanti/indietro
#   swaylock  -> Super+Alt+L (blocco schermo)
dnf -y install playerctl swaylock

# Login manager: DankGreeter che lancia Niri
mkdir -p /etc/greetd/
cat > /etc/greetd/config.toml << 'EOF'
[terminal]
vt = 1
[default_session]
user = "greeter"
command = "dms-greeter --command niri"
EOF
rm -f /etc/systemd/system/display-manager.service
ln -s /usr/lib/systemd/system/greetd.service /etc/systemd/system/display-manager.service
systemctl enable --force greetd.service

### ------------------------------------------------------------------ ###
### 8. Default per-utente via /etc/skel                                 ###
###    (config spedite: si applicano ai NUOVI utenti al primo login)    ###
### ------------------------------------------------------------------ ###
# Abilita DMS nella sessione grafica
mkdir -p /etc/skel/.config/systemd/user/graphical-session.target.wants
ln -sf /usr/lib/systemd/user/dms.service /etc/skel/.config/systemd/user/graphical-session.target.wants/

# Niri config (adattata: vedi patch in scaffolding)
mkdir -p /etc/skel/.config/niri/
cp -rf /ctx/dot_config/niri/config.kdl /etc/skel/.config/niri/

# Placeholder per gli include dms/*.kdl (DMS li rigenera a runtime;
# vuoti evitano l'errore di include mancante al primo avvio di Niri)
mkdir -p /etc/skel/.config/niri/dms
touch /etc/skel/.config/niri/dms/binds.kdl \
      /etc/skel/.config/niri/dms/outputs.kdl \
      /etc/skel/.config/niri/dms/windowrules.kdl \
      /etc/skel/.config/niri/dms/cursor.kdl

# Kitty config (importate da MorrOS)
mkdir -p /etc/skel/.config/kitty/
cp -rf /ctx/dot_config/kitty/. /etc/skel/.config/kitty/

# DMS fornisce la barra: via waybar
dnf -y remove waybar || true

### ------------------------------------------------------------------ ###
### 9. First-boot Flatpak (app GUI: Chrome, Flatseal, ...)              ###
###    GUI grosse -> Flatpak (non bakate). Installate al primo boot.    ###
###    Aggiungi app: una riga per id in flatpaks.list.                  ###
### ------------------------------------------------------------------ ###
mkdir -p /usr/share/fraos
cat > /usr/share/fraos/flatpaks.list << 'EOF'
com.google.Chrome
com.github.tchx84.Flatseal
EOF

cat > /usr/libexec/fraos-firstboot-flatpaks << 'EOF'
#!/bin/bash
set -euo pipefail
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
grep -vE '^\s*(#|$)' /usr/share/fraos/flatpaks.list | xargs -r flatpak install -y --noninteractive flathub || true
EOF
chmod +x /usr/libexec/fraos-firstboot-flatpaks

cat > /etc/systemd/system/fraos-firstboot-flatpaks.service << 'EOF'
[Unit]
Description=FraOS first-boot Flatpak installation
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/fraos/flatpaks-done
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/libexec/fraos-firstboot-flatpaks
ExecStartPost=/usr/bin/mkdir -p /var/lib/fraos
ExecStartPost=/usr/bin/touch /var/lib/fraos/flatpaks-done
[Install]
WantedBy=multi-user.target
EOF

### ------------------------------------------------------------------ ###
### 10. Servizi + NVIDIA container toolkit + finalizzazione            ###
### ------------------------------------------------------------------ ###
systemctl enable podman.socket
systemctl enable tailscaled.service
systemctl enable pcscd.socket || systemctl enable pcscd.service || true
systemctl enable libvirtd.socket || systemctl enable libvirtd.service || true
systemctl enable fraos-firstboot-flatpaks.service

# NVIDIA Container Toolkit (GPU dentro i container/podman)
curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo \
  -o /etc/yum.repos.d/nvidia-container-toolkit.repo
dnf -y install nvidia-container-toolkit

# Schemi glib (necessari ad alcune app GTK)
glib-compile-schemas /usr/share/glib-2.0/schemas/

### CLEAN UP
dnf5 -y clean all || dnf -y clean all
rm -rf /run/dnf /run/selinux-policy /var/lib/dnf
