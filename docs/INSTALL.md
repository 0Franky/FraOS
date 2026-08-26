# FraOS — RUNBOOK DI INSTALLAZIONE

> ## 🔌 LE DUE COSE DA NON DIMENTICARE
>
> **1. Quando installerai Windows (FASE 4), STACCA PRIMA IL CAVO SATA DEL SANDISK 480 (il disco di FraOS).**
> L'installer di Windows, se trova una ESP già esistente su un altro disco, può scriverci
> dentro il proprio bootloader e riordinare il boot: ti ritroveresti FraOS non più avviabile.
> Con il cavo staccato, Windows crea la sua ESP sul Crucial e i due sistemi restano
> completamente indipendenti. Ricollega il cavo a installazione finita.
> ([D-019](DECISIONS.md#d-019), [D-033](DECISIONS.md#d-033))
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
| **SanDisk SSD 480 GB** | **FraOS** (+ la sua ESP) — è `C:` adesso | ✅ formattato |
| **Crucial SSD 120 GB** | **Windows** (+ la sua ESP), reinstallato dopo | ✅ formattato |
| HDD 1 TB (`D:`) | dati, VM, libreria Steam, `_BACKUP-PREWIPE` | ❌ **mai toccato** |

> L'assegnazione è stata **invertita** rispetto al piano di luglio: lo stack AI ([D-032](DECISIONS.md#d-032))
> ha bisogno di spazio e 120 GB non bastavano. Il perché, con i numeri, in [D-033](DECISIONS.md#d-033).

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

✅ **Verificato il 2026-08-20:** i tag `latest`, `bazzite` e `20260820` si scaricano senza
credenziali, e la firma cosign è valida. Nessuna configurazione di autenticazione necessaria.

---

## FASE 1 — Backup pre-wipe ([D-017](DECISIONS.md#d-017))

### Cosa è emerso analizzando i dischi (2026-08-27)

Da `C:` serve salvare **pochissimo**: i dati veri sono **già su `D:`**.

- `C:\Users\frhae\VirtualBox VMs` è una **junction** che punta a `D:\VirtualBox VMs` →
  le **39 GB di VM sono già al sicuro**, non c'è niente da spostare
- dei 407 GB occupati su `C:`, **222 sono `AppData`**, e quasi tutto è **cache rigenerabile**:
  SDK Android (37,6), VHDX di Docker (30,8), cache `uv` (27,5) e `pip` (4,9), pacchetti Store (48)
- fuori da `AppData`, su `C:` ci sono in tutto ~1,6 GB

**E lo spazio non è un problema:** disinstallando la libreria Steam (`D:\SteamLibrary`,
**298,6 GB**) l'HDD passa da 155 a ~450 GB liberi.

### Checklist

- [ ] **Disinstallare i giochi** da Steam/Ubisoft (ri-scaricabili) → libera ~300 GB su `D:`
- [ ] Copiare in `D:\_BACKUP-PREWIPE` le **dotfolder di configurazione** da `C:\Users\frhae`:
      `.ssh` `.aws` `.kube` `.docker` `.gemini` `.claude` `.gitconfig` `.npmrc` — pochi GB in tutto
- [ ] `C:\Users\frhae\Saved Games` e `source` (~0,6 GB)
- [ ] **Doppia copia** delle credenziali su Google Drive **e** chiavetta USB:
      chiavi `ssh`, certificati Aruba/CNS, credenziali cloud, config VPN/OpenVPN, `.env` dei progetti
- [ ] Verifica: GDrive/OneDrive **sincronizzati al 100%**
- [ ] Verifica: **tutti i repo git pushati** (`git status` pulito ovunque)
- [ ] Annotare licenze/chiavi software che non stanno in cloud
- [ ] Esportare i profili browser, se non sono già sincronizzati su account

**NON serve copiare:** `AppData` (cache), SDK Android, immagini Docker, le VM (già su `D:`),
i programmi installati.

> Il punto di non ritorno è qui. Una volta partito il wipe dei due SSD, l'unica copia dei dati
> è sull'HDD 1 TB + cloud + USB.

---

## FASE 2 — Installazione base (Bazzite ufficiale)

1. Scaricare l'ISO **Bazzite GNOME NVIDIA** da https://bazzite.gg (variante NVIDIA, desktop GNOME)
2. Scriverla su chiavetta con Fedora Media Writer, Rufus o `dd`
3. **BIOS:** UEFI attivo, CSM off, Secure Boot **ON** ([D-015](DECISIONS.md#d-015))
4. Boot da chiavetta → installer Anaconda
5. **Selezionare come destinazione SOLO il SanDisk 480 GB.** Custom/Advanced, mai "usa tutto il disco"
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

### Windows sul Crucial 120

⚠️ **Scollegare fisicamente il cavo SATA del SanDisk 480** (quello con FraOS) prima di installare
Windows ([D-019](DECISIONS.md#d-019)). Ricollegarlo a installazione finita. Poi impostare il disco di
default da BIOS, e usare **F8** per scegliere l'altro all'occorrenza.

**Subito dopo l'installazione, le tre accortezze che fanno stare Windows in 120 GB**
([D-033](DECISIONS.md#d-033)) — da prompt amministratore:

```powershell
powercfg /h off        # niente ibernazione: libera ~6,5 GB
```
Poi, da GUI:
- **pagefile**: Sistema → Impostazioni di sistema avanzate → Prestazioni → Avanzate → Memoria
  virtuale → dimensione personalizzata **8 GB**, oppure spostalo su `D:`
- **Steam**: al primo avvio, crea la libreria su `D:\SteamLibrary` (esiste già, ~300 GB)
- **Documenti/Download/Immagini**: tasto destro → Proprietà → Percorso → sposta su `D:`

Senza queste, Windows arriva a saturare i 120 GB nel giro di qualche mese.

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
