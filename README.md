# FraOS

Immagine **Fedora atomic (bootc)** personale — desktop **Niri** (compositor scrollable-tiling
Wayland) + **DankMaterialShell (DMS)**, costruita in cloud (GitHub Actions → GHCR) e
aggiornabile con un comando. Pensata come OS primario in **dual-boot con Windows**.

- **Base default:** `ghcr.io/ublue-os/bazzite-gnome-nvidia:stable` (come MorrOS)
- **Login:** greetd + **DankGreeter** (`dms-greeter --command niri`)
- **Approccio:** ublue *image-template* (Containerfile + `build_files/build.sh`) — vedi `NOTES.md` per il perché
- **Ispirazione / config:** [MorrOS](https://github.com/morrolinux/morros)

## 📚 Documentazione

Il README spiega **come si usa** FraOS. Il resto sta in `docs/`:

| Documento | A cosa serve |
|---|---|
| **[docs/STATUS.md](docs/STATUS.md)** | ⭐ **Parti da qui.** Dove siamo, cosa manca, qual è il prossimo passo |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Ogni scelta di progetto, con data, motivo e conseguenze (D-001…) |
| [docs/JOURNAL.md](docs/JOURNAL.md) | Diario di bordo: cosa è successo in ogni sessione |
| [docs/UPSTREAM.md](docs/UPSTREAM.md) | Cosa fa MorrOS, cosa recepiamo e cosa no |
| [docs/INSTALL.md](docs/INSTALL.md) | Runbook: backup → installazione → primo boot → post-install |
| [docs/AI-STACK.md](docs/AI-STACK.md) | vLLM e Unsloth su questa GPU: comandi, vincoli, cosa ci gira |
| [NOTES.md](NOTES.md) | Archivio storico della sessione di design (non più aggiornato) |

---

## Setup iniziale (una tantum)

1. **Repo su GitHub** come `0franky/fraos` e abilita le Actions (tab *Actions*).
2. **Firma cosign** (obbligatoria, altrimenti la build fallisce allo step di firma):
   ```bash
   COSIGN_PASSWORD="" cosign generate-key-pair
   gh secret set SIGNING_SECRET < cosign.key      # la CHIAVE PRIVATA come secret
   git add cosign.pub && git commit -m "add cosign pub"
   # NON committare mai cosign.key (è in .gitignore)
   ```
3. `git push` → la Action **Build FraOS** costruisce e pubblica su
   `ghcr.io/0franky/fraos:latest`.

> Se lo username GHCR non è `0franky`, aggiorna il riferimento in `disk_config/iso.toml`
> e nei comandi qui sotto.

---

## Installare / passare a FraOS

- **Prima installazione** (PC vuoto): genera l'ISO con la Action **build-disk** (o `just build-iso`),
  installala; il kickstart rebasa automaticamente su `ghcr.io/0franky/fraos:latest`.
- **Da un sistema atomico già installato** (Bazzite/Bluefin/Fedora Atomic):
  ```bash
  sudo bootc switch ghcr.io/0franky/fraos:latest   # poi reboot
  ```

## Aggiornare, rollback, aggiungere pacchetti

| Operazione | Comando / azione |
|---|---|
| Aggiornare all'ultima immagine | `sudo bootc upgrade` (o automatico via timer ublue) |
| Tornare indietro | `sudo bootc rollback` |
| **Bump** (ricostruzione su base+pacchetti aggiornati) | automatico ogni giorno (cron in `build.yml`); manuale: *Run workflow* |
| **Aggiungere un pacchetto system** | aggiungi `dnf -y install X` in `build_files/build.sh` → push → `bootc upgrade` |
| Provare un pacchetto al volo (temporaneo) | `rpm-ostree install X` sulla macchina (poi, se ok, mettilo in `build.sh`) |

## Provare tutte e 3 le basi (una sola installazione)

La Action **Build FraOS variants** (manuale) pubblica i tag alternativi. Poi, sulla stessa
installazione, `bootc switch` scambia l'immagine (la precedente resta come rollback):

```bash
sudo bootc switch ghcr.io/0franky/fraos:bluefin   # dev-oriented, Secure Boot ON  → switch liscio
sudo bootc switch ghcr.io/0franky/fraos:rakuos    # kernel CachyOS, Secure Boot OFF → toggle BIOS
sudo bootc switch ghcr.io/0franky/fraos:bazzite   # torna alla default
```

---

## Config incluse — cosa spediamo e dove sta

Le config vivono nel repo, vengono copiate in `/etc/skel` durante la build e finiscono
in `~/.config/...` al primo login di un nuovo utente. Puoi modificarle/cancellarle liberamente.

| Config | Sorgente (repo) | In immagine | Runtime utente |
|---|---|---|---|
| **kitty** (importata da MorrOS) | `build_files/dot_config/kitty/{kitty,dank-theme,dank-tabs}.conf` | `/etc/skel/.config/kitty/` | `~/.config/kitty/` |
| **niri** | `build_files/dot_config/niri/config.kdl` | `/etc/skel/.config/niri/config.kdl` | `~/.config/niri/config.kdl` |
| **DMS include niri** | (placeholder vuoti; DMS li rigenera) | `/etc/skel/.config/niri/dms/*.kdl` | `~/.config/niri/dms/*.kdl` |
| **greetd / DankGreeter** | generato in `build.sh` | `/etc/greetd/config.toml` | (system) |
| **Flatpak first-boot** | generato in `build.sh` | `/usr/share/fraos/flatpaks.list` | installati al 1° boot |

**Patch applicate alla niri config di MorrOS** (per non ereditare cose sue/rotte):
- rimosso `ssh-add` hardcoded su `/home/morro/...`
- `Mod+T` → `kitty` (alacritty non installato)
- launcher `Mod+D` → `dms ipc call spotlight toggle` (noctalia non installato)
- aggiunto avvio `xwayland-satellite` (app X11 sotto Niri)

---

## TODO

La lista dei task aperti vive in **[docs/STATUS.md](docs/STATUS.md)** — checklist della fase
corrente, decisioni ancora aperte e rischi noti. Non duplicarla qui.

---

## Struttura

```
Containerfile              # base (ARG BASE_IMAGE) + brew + esegue build.sh
build_files/
  build.sh                 # TUTTE le personalizzazioni system (pacchetti, servizi, greetd)
  dot_config/{kitty,niri}/ # config spedite in /etc/skel
disk_config/               # config ISO/disk (bootc-image-builder)
.github/workflows/
  build.yml                # build primaria Bazzite + cron (bump)
  build-variants.yml       # build on-demand bluefin/rakuos (prova le 3)
  build-disk.yml           # generazione ISO installabile
Justfile                   # build/vm/iso in locale
docs/                      # SSOT: STATUS, DECISIONS, JOURNAL, UPSTREAM, INSTALL, AI-STACK
tools/check-packages.sh    # valida i nomi pacchetto senza costruire (da lanciare prima di ogni push)
NOTES.md                   # archivio storico della sessione di design
```
