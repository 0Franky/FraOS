# FraOS — STATO DEL PROGETTO

> **SSOT dello stato corrente.** Se torni qui dopo mesi, **leggi questo file per primo**:
> ti dice dove siamo, cosa è fatto, cosa manca e qual è il prossimo comando da dare.
>
> - **Perché** una scelta è stata fatta → [`DECISIONS.md`](DECISIONS.md)
> - **Quando / cosa è successo** in ogni sessione → [`JOURNAL.md`](JOURNAL.md)
> - **Cosa fa l'upstream** (morrolinux/morros) → [`UPSTREAM.md`](UPSTREAM.md)
> - **Come si installa** sul PC → [`INSTALL.md`](INSTALL.md)

| | |
|---|---|
| **Ultimo aggiornamento** | 2026-08-20 |
| **Fase corrente** | **F2 — Pubblicazione repo e prima build CI** |
| **Prossima azione** | Creare `0Franky/fraos` su GitHub, generare cosign key, push → far girare la prima build |
| **Bloccante attivo** | Nessuna build è mai stata eseguita: i nomi pacchetto non sono ancora validati |
| **Obiettivo finale** | Formattare il PC e usare FraOS come OS primario (dual boot con Windows) |

---

## Fasi del progetto

| Fase | Cosa | Stato |
|---|---|---|
| **F0** | Design: hardware, requisiti, inventario tool, confronto basi | ✅ **CHIUSA** (2026-07-12) |
| **F1** | Scaffold repo: Containerfile, build.sh, config, CI, ISO config | ✅ **CHIUSA** (2026-07-12) |
| **F2** | Versionamento + pubblicazione + **prima build CI verde** | 🟡 **IN CORSO** |
| **F3** | Backup pre-wipe (si esegue mentre la CI gira) | ⬜ Da fare |
| **F4** | Installazione: ISO Bazzite → `bootc switch` → primo boot | ⬜ Da fare |
| **F5** | Post-install: ArubaSign, Windows sul secondo disco, tuning | ⬜ Da fare |

---

## F2 — Checklist operativa (fase corrente)

| # | Task | Stato | Note |
|---|---|---|---|
| 1 | Allineare `build.sh` alle novità upstream | ✅ fatto (2026-08-20) | vedi [D-018](DECISIONS.md#d-018), [D-022](DECISIONS.md#d-022) |
| 2 | `git init` + primo commit | ✅ fatto (2026-08-20) | storia del progetto ora versionata |
| 3 | Documentazione persistente (`docs/`) | ✅ fatto (2026-08-20) | questo file + DECISIONS/JOURNAL/UPSTREAM/INSTALL |
| 4 | Creare repo GitHub `0Franky/fraos` | 🟡 in corso (Fra) | **nome repo in minuscolo**, pubblico, **vuoto** (no README/licenza auto), Actions abilitate |
| 5 | Generare cosign key-pair | ✅ fatto (2026-08-20) | chiave senza password, generata in locale |
| 6 | `gh secret set SIGNING_SECRET < cosign.key` | ⬜ | serve il repo. Senza questo la build **fallisce** allo step di firma |
| 7 | Committare `cosign.pub`, mai `cosign.key` | ✅ fatto (2026-08-20) | `cosign.key` resta solo in locale, è in `.gitignore` |
| 8 | Primo `git push` → build CI | ⬜ | **qui si valida tutto**: iterare finché è verde |
| 9 | Rendere **pubblico il package GHCR** | ⬜ | al primo push il package nasce PRIVATO → `bootc switch` fallirebbe senza login |
| 10 | Verificare che `bootc switch` risolva l'immagine | ⬜ | test da qualsiasi macchina: `skopeo inspect docker://ghcr.io/0franky/fraos:latest` |

### Cosa la prima build deve validare
Nomi pacchetto mai verificati, tutti in `build_files/build.sh`:
`niri` · `dms` · `dms-greeter` · `quickshell` · `xwayland-satellite` · `podman-docker` · `podman-compose` · `bibata-cursor-themes` · `android-tools` · `iperf3`

Se un `dnf install` fallisce, la Action lo segnala con la riga esatta → si corregge e si ri-pusha.

---

## Decisioni ancora APERTE (bloccano poco, ma vanno chiuse)

| ID | Cosa | Chi decide |
|---|---|---|
| [D-021](DECISIONS.md#d-021) | rEFInd sì/no → **proposta: NO** | Fra (da confermare) |
| [D-023](DECISIONS.md#d-023) | Set Flatpak finale (ora solo Chrome + Flatseal) | Fra |

---

## Rischi noti / da verificare solo a OS avviato

| Rischio | Mitigazione |
|---|---|
| ArubaSign AppImage non parla col lettore smartcard | Middleware già bakato (`pcsc-lite`, `opensc`, `pcscd`); fallback = Distrobox o Windows |
| `Mod+D` (launcher DMS) con IPC sbagliato | Correggere `dot_config/niri/config.kdl` e ri-pushare |
| Niri non parte al primo boot | GNOME resta installato: da TTY `sudo systemctl stop greetd && sudo systemctl start gdm` ([D-018](DECISIONS.md#d-018)) |
| Windows sovrascrive il boot di Linux | Installare Windows **con il cavo SATA del disco Linux staccato** ([D-019](DECISIONS.md#d-019)) |
