# FraOS — STATO DEL PROGETTO

> **SSOT dello stato corrente.** Se torni qui dopo mesi, **leggi questo file per primo**:
> ti dice dove siamo, cosa è fatto, cosa manca e qual è il prossimo comando da dare.
>
> - **Perché** una scelta è stata fatta → [`DECISIONS.md`](DECISIONS.md)
> - **Quando / cosa è successo** in ogni sessione → [`JOURNAL.md`](JOURNAL.md)
> - **Cosa fa l'upstream** (morrolinux/morros) → [`UPSTREAM.md`](UPSTREAM.md)
> - **Come si installa** sul PC → [`INSTALL.md`](INSTALL.md)
> - **Stack AI locale** (vLLM, Unsloth) → [`AI-STACK.md`](AI-STACK.md)

| | |
|---|---|
| **Ultimo aggiornamento** | 2026-10-21 |
| **Fase corrente** | **F3 — Backup pre-wipe**, non ancora iniziato |
| **Prossima azione** | FASE 2: `tools/fase2-svuota-crucial.ps1` (da amministratore, con Claude Code e Ollama chiusi). In corso: ricerca dei file EFS. Unsloth sulla 2080 Ti: ✅ funziona. Già fatti: SMART, avvio rapido, certificato EFS, FASE 1 |
| **Bloccante attivo** | Nessuno. La CI è tornata verde il 2026-10-21 ([D-034](DECISIONS.md#d-034)), dopo 23 giorni di build rosse |
| **Obiettivo finale** | Formattare il PC e usare FraOS come OS primario (dual boot con Windows) |

## ✅ L'immagine esiste ed è verificata

```bash
sudo bootc switch ghcr.io/0franky/fraos:latest
```

| | |
|---|---|
| **Ultima build verde** | 2026-10-21, run `39624317568`: `latest` = config `sha256:e2572eac…`, creata 15:24 UTC, scaricabile senza credenziali. I dati qui sotto sono della **prima** build (2026-08-20) |
| **Registry** | `ghcr.io/0franky/fraos` — pubblico, **pullabile senza credenziali** (verificato) |
| **Tag** | `latest` · `latest.20260820` · `20260820` · `bazzite` |
| **Digest** | `sha256:38b54169004142074991764f4d09e82be79d5b46343404d8a733e186573d2ef1` |
| **Dimensione** | 5,01 GB compressi, 130 layer |
| **Firma** | ✅ cosign verificata con `cosign.pub` (4 firme, una per tag) |
| **Prima build verde** | run `32367884947`, 32m50s, 2026-08-20 |
| **Base effettiva** | Bazzite GNOME NVIDIA su **Fedora 44** |

**Manutenzione automatica:** il sistema si aggiorna con `bootc upgrade` (immagine ricostruita
ogni notte dalla CI); lo stack AI, che sta fuori dall'immagine, con `fraos-ai-update` e il suo
timer utente settimanale ([`AI-STACK.md`](AI-STACK.md)).

Verifica della firma da qualsiasi macchina:
```bash
cosign verify --key cosign.pub ghcr.io/0franky/fraos:latest
```

---

## Fasi del progetto

| Fase | Cosa | Stato |
|---|---|---|
| **F0** | Design: hardware, requisiti, inventario tool, confronto basi | ✅ **CHIUSA** (2026-07-12) |
| **F1** | Scaffold repo: Containerfile, build.sh, config, CI, ISO config | ✅ **CHIUSA** (2026-07-12) |
| **F2** | Versionamento + pubblicazione + **prima build CI verde** | ✅ **CHIUSA** (2026-08-20) |
| **F3** | Backup pre-wipe — [checklist](INSTALL.md) | 🟡 **IN CORSO** |
| **F4** | Installazione: ISO Bazzite → `bootc switch` → primo boot | ⬜ Da fare |
| **F5** | Post-install: ArubaSign, Windows sul secondo disco, tuning | ⬜ Da fare |

---

## F3 — Backup pre-wipe (fase corrente)

La checklist operativa sta in **[`INSTALL.md` §FASE 1](INSTALL.md)**. In sintesi: l'HDD da 1 TB
fa da porto sicuro e non viene toccato; doppia copia delle credenziali su cloud **e** USB; tutti
i repo git pushati; poi si formattano solo i due SSD.

Il punto di non ritorno è qui: prima di partire col wipe, l'immagine deve essere scaricabile
(✅ lo è) e il backup completo.

---

## F2 — Chiusa il 2026-08-20 ✅

Tutti i task completati: `git init`, documentazione, repo pubblico, cosign (chiave + secret +
`cosign.pub`), push, **prima build verde**, immagine pubblica e firma verificata.

**Sono servite quattro build.** Le tre fallite sono state rapide ed economiche, e ognuna ha
lasciato una protezione permanente nel repo:

| # | Durata | Errore | Correzione, e cosa impedisce che si ripeta |
|---|---|---|---|
| 1 | 30s | `no FROM statement found` | `ARG BASE_IMAGE` spostato prima di ogni `FROM`, con il vincolo spiegato nel commento |
| 2 | 3m16s | `exit status 126` | `chmod +x` sull'index **e** invocazione `bash /ctx/build.sh`, così il bit `+x` perso su Windows non può più bloccare la build |
| 3 | 4m29s | `tuned-ppd` in conflitto con `power-profiles-daemon` | pacchetto rimosso, motivo scritto accanto alla riga |
| 4 | **32m50s** | — | ✅ **verde** |

I primi due erano attriti Windows→Linux; il terzo un conflitto di dipendenze. Nessuno era un
nome di pacchetto sbagliato: quelli erano già stati eliminati dalla validazione offline
([D-029](DECISIONS.md#d-029)), che ne aveva trovati quattro prima ancora di toccare la CI.

**Prassi confermata:** prima di ogni push che tocca `build.sh`, eseguire
`./tools/check-packages.sh` — 1 minuto contro i 30+ di una build. Ricorda però il suo limite:
vede i nomi, non i conflitti.

---

## Decisioni (domande a Fra del 2026-10-21, risposte lo stesso giorno)

| # | Domanda | Risposta di Fra |
|---|---|---|
| 1 | Ordine di installazione | ✅ **Windows prima, FraOS dopo**, un disco per volta → [D-035](DECISIONS.md#d-035) ACCETTATA |
| 2 | Spazio sull'HDD | ✅ **solo Call of Duty**: cancellato il 2026-10-21, ora l'HDD ha **225,5 GB liberi** (FASE 1 fatta) |
| 3 | I 33 GB di modelli Ollama | ✅ **Ollama resta, in prova** ([D-036](DECISIONS.md#d-036)): dopo l'installazione un confronto vLLM / Ollama / Unsloth Studio decide chi serve i modelli, e si tiene quello. Tenuti 7 modelli (16,5 GB), rimossi `jaahas/qwen3.5-uncensored:9b` e Rocinante 12B → `wiki/ollama-modelli.md` |
| 4 | Commit e push del fix della build | ✅ sì |
| 5 | Programmi in più (Flatpak/brew) | ⬜ aperta, non bloccante: proposta in `wiki/README.md` |

**Assetto dischi (invertito il 2026-08-27, [D-033](DECISIONS.md#d-033)):**

| Disco | Va | Nel wipe |
|---|---|---|
| SanDisk SSD 480 (`C:` oggi) | 🐧 **FraOS** | 🔴 formattato |
| Crucial SSD 120 | 🪟 **Windows** | 🔴 formattato |
| HDD 1 TB (`D:`) | dati, VM, Steam | 🟢 **mai toccato** |

---

## Rischi noti / da verificare solo a OS avviato

| Rischio | Mitigazione |
|---|---|
| **La CI fallisce in silenzio** (è già successo: 23 giorni) | Prima di installare, e ogni tanto dopo: `gh run list --workflow build.yml --limit 3` |
| **L'HDD è l'unica copia** di quasi tutto durante la migrazione | Controllo SMART prima di iniziare; credenziali, `~/.claude` e `.env` anche su chiavetta e cloud ([`INSTALL.md`](INSTALL.md) 0.3, 3.7) |
| `~/.claude` (hook, skill, memorie) usa percorsi e script Windows | Da adattare dopo il ripristino, non basta copiarlo ([`INSTALL.md`](INSTALL.md) 6.3) |
| ArubaSign AppImage non parla col lettore smartcard | Middleware già bakato (`pcsc-lite`, `opensc`, `pcscd`); fallback = Distrobox o Windows |
| `Mod+D` (launcher DMS) con IPC sbagliato | Correggere `dot_config/niri/config.kdl` e ri-pushare |
| Niri non parte al primo boot | GNOME resta installato: da TTY `sudo systemctl stop greetd && sudo systemctl start gdm` ([D-018](DECISIONS.md#d-018)) |
| Windows sovrascrive il boot di Linux | Installare Windows **con il cavo SATA del disco Linux staccato** ([D-019](DECISIONS.md#d-019)) |
| ~~Unsloth Studio non supporta la RTX 2080 Ti~~ | ✅ **Chiuso il 2026-10-21**: un fine-tuning QLoRA fp16 di prova va a buon fine sulla 2080 Ti (loss da 3,82 a 0,67). Resta da sapere: **mai** fidarsi di `torch.cuda.is_bf16_supported()`, che su Turing dice `True` ([`AI-STACK.md`](AI-STACK.md)) |
| vLLM: modelli 7B in fp16 non entrano negli 11 GB | Usare quantizzazione **AWQ/GPTQ 4-bit** e `--dtype half` (bfloat16 non esiste su Turing) |
