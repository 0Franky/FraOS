# FraOS — TRACKING UPSTREAM (morrolinux/morros)

> FraOS non è un fork git di MorrOS: è un progetto indipendente che **parte dalle stesse basi**
> (ublue image-template, base Bazzite) e ne riusa idee e config.
> Qui teniamo traccia di **cosa fa l'upstream e cosa abbiamo deciso di recepire**, in modo da
> poter riprendere il confronto da un punto preciso invece che da capo.

**Repo:** https://github.com/morrolinux/morros
**Ultimo controllo:** 2026-08-20 · **Ultimo commit upstream valutato:** `557a52d` (2026-08-19)

## Come si ricontrolla

```bash
# commit nuovi da quando abbiamo controllato l'ultima volta
gh api "repos/morrolinux/morros/commits?since=2026-08-19T00:00:00Z" \
  --jq '.[] | "\(.commit.author.date[0:10])  \(.sha[0:7])  \(.commit.message | split("\n")[0])"'

# cosa cambia un commit
gh api repos/morrolinux/morros/commits/<sha> --jq '.files[] | "--- \(.filename)\n\(.patch)"'
```
Dopo il controllo: aggiornare la data qui sopra e la tabella, anche se non si recepisce nulla.

---

## Base image — confronto

|  | MorrOS | FraOS |
|---|---|---|
| Base attiva | `ghcr.io/ublue-os/bazzite-gnome-nvidia:stable` | **identica** |
| Riga RakuOS/CachyOS | presente ma **commentata** | commentata + disponibile come tag `fraos:rakuos` |
| Template | ublue image-template | identico |

Verificato il 2026-08-20 leggendo il `Containerfile` di HEAD: nessuna divergenza sulla base.

---

## Commit valutati

| SHA | Data | Cosa fa | Recepito |
|---|---|---|---|
| `d2ba3ab` | 2026-07-12 | Update build.sh | — (precedente al nostro scaffold) |
| `8843559` | 2026-07-12 | smette di rimuovere `xdg-desktop-portal-gnome` | ✅ sì → [D-018](DECISIONS.md#d-018) |
| `75e8ba8` | 2026-07-19 | **"fix screen capture"**: commenta anche `remove gnome-shell` e l'install di `pipewire`; tiene solo `portal-wlr` | ✅ sì, **in versione più solida** → [D-018](DECISIONS.md#d-018) |
| `557a52d` | 2026-08-19 | aggiunge `android-tools iperf3 ktls-utils podman-compose` | ✅ 3 su 4 → [D-022](DECISIONS.md#d-022) |

### Nota su `75e8ba8` — il commit più importante
È la conferma di un dubbio che avevamo già annotato a luglio: **Niri è basato su Smithay, non su
wlroots**, quindi `xdg-desktop-portal-wlr` non copre lo screencast. Morro l'ha risolto smettendo di
rimuovere `gnome-shell` (che si portava dietro `portal-gnome`).

Noi facciamo la stessa cosa ma senza dipendere da un effetto collaterale: **installiamo
`xdg-desktop-portal-gnome` esplicitamente**, così resta anche se un domani l'upstream cambia idea.
In più il GNOME che resta installato ci fa da sessione di fallback al primo boot.

---

## Divergenze volute (cosa NON prendiamo da MorrOS)

| Aspetto | MorrOS | FraOS | Perché |
|---|---|---|---|
| `obs-studio` | installato | ❌ escluso | [D-012](DECISIONS.md#d-012) |
| `gnome-terminal` | installato | ❌ escluso | kitty + alacritty bastano — [D-010](DECISIONS.md#d-010) |
| `ktls-utils` | installato (ago) | ❌ escluso | nessun caso d'uso — [D-022](DECISIONS.md#d-022) |
| `xdg-desktop-portal-gnome` | implicito (dipendenza) | ✅ esplicito | non dipendere dalle scelte altrui — [D-018](DECISIONS.md#d-018) |
| Flatpak | nessuno | ✅ servizio di first-boot | Chrome + Flatseal, estendibile — [D-023](DECISIONS.md#d-023) |
| Config kitty | nel repo ma **non cablata** | ✅ cablata in `/etc/skel` | erano lì inutilizzate |
| Config niri | con path hardcoded `/home/morro` | ✅ ripulita | `ssh-add`, `Mod+T`, `Mod+D`, `xwayland-satellite` |
| Tailscale, OpenVPN, WireGuard | assenti | ✅ bakati | richiesta di Fra |
| Smartcard (`pcsc`, `opensc`) | assente | ✅ bakato | firma digitale Aruba/CNS — [D-013](DECISIONS.md#d-013) |
| `virt-viewer`, `tmux`, `distrobox`, `podman-docker` | parziali | ✅ bakati | stack di Fra |
| NVIDIA Container Toolkit | presente | ✅ preso | GPU nei container |
| Multi-tag (bluefin/rakuos) | no | ✅ sì | provare le basi senza reinstallare — [D-009](DECISIONS.md#d-009) |
