# FraOS — RUNBOOK DI INSTALLAZIONE

> ## 🔌 LE DUE COSE DA NON DIMENTICARE
>
> **1. Quando installerai Windows (FASE 4), STACCA PRIMA IL CAVO SATA DEL CRUCIAL 120.**
> L'installer di Windows, se trova una ESP già esistente su un altro disco, può scriverci
> dentro il proprio bootloader e riordinare il boot: ti ritroveresti FraOS non più avviabile.
> Con il cavo staccato, Windows crea la sua ESP sul SanDisk e i due sistemi restano
> completamente indipendenti. Ricollega il cavo a installazione finita. ([D-019](DECISIONS.md#d-019))
>
> **2. Nel wipe si toccano SOLO i due SSD. L'HDD da 1 TB non si formatta mai:** è il porto
> sicuro dove sta il backup. Nell'installer seleziona il disco a mano, mai "usa tutto il
> disco". ([D-017](DECISIONS.md#d-017))

> Procedura completa dal PC-Windows-attuale al PC-FraOS. **Da seguire in ordine.**
> Le scelte dietro ogni passo: [D-017](DECISIONS.md#d-017) backup · [D-019](DECISIONS.md#d-019) dual boot ·
> [D-020](DECISIONS.md#d-020) percorso di installazione · [D-021](DECISIONS.md#d-021) bootloader
>
> Stato di avanzamento → [`STATUS.md`](STATUS.md)

## Assetto finale a cui puntiamo

| Disco | Contenuto | Nel wipe |
|---|---|---|
| Crucial SSD 120 GB | **FraOS** (+ la sua ESP) | ✅ formattato |
| SanDisk SSD 480 GB | **Windows** (+ la sua ESP), reinstallato dopo | ✅ formattato |
| HDD 1 TB | dati, librerie, `_BACKUP-PREWIPE` | ❌ **mai toccato** |

Boot: **niente rEFInd**. Si sceglie il disco con **F8** all'avvio (ASUS Z370-E), il default si
imposta da BIOS o con `efibootmgr -o`.

---

## FASE 0 — Prerequisito: build CI verde

Non si formatta niente finché `ghcr.io/0franky/fraos:latest` non esiste e non è scaricabile.

```bash
# da qualunque macchina, verifica che l'immagine sia pubblica e risolvibile
skopeo inspect docker://ghcr.io/0franky/fraos:latest | head -20
# oppure
docker manifest inspect ghcr.io/0franky/fraos:latest
```

⚠️ Al primo push il package su GHCR nasce **privato** anche se il repo è pubblico.
Va reso pubblico a mano: *GitHub → Packages → fraos → Package settings → Change visibility → Public*.
Senza questo, `bootc switch` sul PC fallirebbe con un errore di autenticazione.

---

## FASE 1 — Backup pre-wipe ([D-017](DECISIONS.md#d-017))

Da fare **mentre la CI gira**, non dopo.

- [ ] Disinstallare i giochi (Steam/Ubisoft: ri-scaricabili) per liberare spazio sull'HDD
- [ ] Consolidare tutto il prezioso in `D:\_BACKUP-PREWIPE` (documenti, progetti, config, saves)
- [ ] **Doppia copia** delle credenziali su Google Drive **e** chiavetta USB:
      chiavi `ssh`, certificati Aruba/CNS, credenziali cloud, config VPN/OpenVPN, `.env` dei progetti
- [ ] Export delle VM VirtualBox che servono ancora (si convertono dopo con `qemu-img`)
- [ ] Verifica: GDrive/OneDrive **sincronizzati al 100%**
- [ ] Verifica: **tutti i repo git pushati** (`git status` pulito ovunque)
- [ ] Annotare licenze/chiavi software che non stanno in cloud

> Il punto di non ritorno è qui. Una volta partito il wipe dei due SSD, l'unica copia dei dati
> è sull'HDD 1 TB + cloud + USB.

---

## FASE 2 — Installazione base (Bazzite ufficiale)

1. Scaricare l'ISO **Bazzite GNOME NVIDIA** da https://bazzite.gg (variante NVIDIA, desktop GNOME)
2. Scriverla su chiavetta con Fedora Media Writer, Rufus o `dd`
3. **BIOS:** UEFI attivo, CSM off, Secure Boot **ON** ([D-015](DECISIONS.md#d-015))
4. Boot da chiavetta → installer Anaconda
5. **Selezionare come destinazione SOLO il Crucial 120 GB.** Custom/Advanced, mai "usa tutto il disco"
6. Primo boot: enrollment MOK per il driver NVIDIA firmato → password **`universalblue`**
7. Verificare che il desktop parta e che la rete funzioni

---

## FASE 3 — Passaggio a FraOS

```bash
sudo bootc switch ghcr.io/0franky/fraos:latest
sudo systemctl reboot
```

Al riavvio parte DankGreeter → login → Niri + DankMaterialShell.

**Se qualcosa non va:**
```bash
sudo bootc rollback && sudo systemctl reboot     # torna a Bazzite ufficiale
```
**Se Niri non parte** ma il sistema è vivo — da TTY con `Ctrl+Alt+F3` ([D-018](DECISIONS.md#d-018)):
```bash
sudo systemctl stop greetd && sudo systemctl start gdm    # sessione GNOME di fallback
```

### Checklist del primo boot
- [ ] Niri parte, DMS mostra la barra
- [ ] `Mod+T` apre kitty · `Mod+D` apre il launcher (se no → correggere `dot_config/niri/config.kdl`)
- [ ] Audio, rete, Bluetooth, luminosità dal control center DMS
- [ ] I Flatpak di first-boot si sono installati (Chrome, Flatseal)
- [ ] `nvidia-smi` vede la 2080 Ti
- [ ] Screencast/screenshot funzionano (era il bug di `portal-gnome`)
- [ ] App X11 (Steam, Discord) partono via `xwayland-satellite`
- [ ] `tailscale up` funziona
- [ ] HDD 1 TB montato e leggibile (NTFS)

---

## FASE 4 — Post-install

### Windows sul secondo disco
⚠️ **Scollegare fisicamente il cavo SATA del Crucial 120** prima di installare Windows
([D-019](DECISIONS.md#d-019)). Ricollegarlo a installazione finita. Poi impostare il disco di default
da BIOS, e usare **F8** per scegliere l'altro all'occorrenza.

### Migrazione VM VirtualBox → KVM ([D-011](DECISIONS.md#d-011))
```bash
qemu-img convert -f vdi -O qcow2 disco.vdi disco.qcow2
```

### ArubaSign ([D-013](DECISIONS.md#d-013))
Scaricare l'AppImage e verificare che veda il lettore smartcard
(`pcsc-lite`/`opensc`/`pcscd` sono già nell'immagine):
```bash
systemctl status pcscd    # deve essere attivo
pcsc_scan                 # deve vedere il lettore
opensc-tool -l            # deve elencare la carta
```
Se non funziona → provare in Distrobox, altrimenti la firma resta su Windows.

### Provare le altre basi ([D-009](DECISIONS.md#d-009))
```bash
sudo bootc switch ghcr.io/0franky/fraos:bluefin   # dev-oriented, Secure Boot ON
sudo bootc switch ghcr.io/0franky/fraos:rakuos    # kernel CachyOS — richiede Secure Boot OFF da BIOS
sudo bootc switch ghcr.io/0franky/fraos:bazzite   # ritorno alla default
```

### Manutenzione ordinaria
| Cosa | Comando |
|---|---|
| Aggiornare | `sudo bootc upgrade` (immagine ricostruita ogni giorno dalla CI) |
| Tornare indietro | `sudo bootc rollback` |
| Aggiungere un pacchetto system | riga in `build_files/build.sh` → push → `bootc upgrade` |
| Provarne uno al volo | `rpm-ostree install X` (temporaneo; se convince, mettilo in `build.sh`) |
| CLI user-space | `brew install X` |
| App GUI | `flatpak install X` |
