#!/bin/bash
#
# FraOS — validatore dei nomi pacchetto, SENZA costruire l'immagine.
#
# Perché esiste: una build CI completa dura ~20-40 minuti e fallisce alla prima
# riga `dnf install` con un nome sbagliato. Questo script scarica solo i METADATI
# dei repository (~25 MB) e verifica offline che ogni pacchetto richiesto da
# build_files/build.sh esista davvero da qualche parte. Gira in ~1 minuto.
#
# Uso:
#   ./tools/check-packages.sh             # Fedora 44 = quella della base Bazzite attuale
#   FEDORA_VERSION=45 ./tools/check-packages.sh
#
# La versione va tenuta allineata alla base: i tag GHCR di Bazzite sono fuorvianti
# (mostravano ancora "stable-43" quando la base era gia' su Fedora 44). Il modo
# affidabile per saperlo e' leggere un log di build: i pacchetti hanno il suffisso
# .fc44 / .fc45.
#
# Richiede: curl, zstd, awk, grep. Su Windows usare WSL o Git Bash + zstd.
#
# LIMITI — cosa NON vede (e che quindi puo' ancora far fallire la build):
#   - la RISOLUBILITA': verifica che il nome esista, non che si installi. Un
#     conflitto fra pacchetti passa di qui indisturbato (es. power-profiles-daemon
#     contro tuned-ppd, che ha fatto fallire la run 32367033127).
#   - i pacchetti forniti dai repo PROPRI della base (Terra, ublue), non inclusi qui.
# Non sostituisce la build: intercetta l'errore piu' frequente, non tutti.
#
set -uo pipefail

FEDORA_VERSION="${FEDORA_VERSION:-44}"
ARCH="x86_64"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_SH="$REPO_ROOT/build_files/build.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

command -v zstd >/dev/null || { echo "ERRORE: serve zstd (i metadati Fedora sono compressi in .zst)"; exit 2; }
[ -f "$BUILD_SH" ] || { echo "ERRORE: non trovo $BUILD_SH"; exit 2; }

echo "FraOS — validazione pacchetti su Fedora ${FEDORA_VERSION}/${ARCH}"
echo

# ---------------------------------------------------------------- metadati ---
fetch_primary() {   # $1 = etichetta, $2 = URL base del repo
  local label="$1" base="$2" loc
  loc=$(curl -sSL -m 60 "$base/repodata/repomd.xml" 2>/dev/null \
        | grep -oE 'href="repodata/[^"]*primary\.xml\.(zst|gz)"' | sed 's/href="//;s/"//' | head -1)
  [ -z "$loc" ] && { echo "  ! $label: repodata non raggiungibile ($base)"; return 1; }
  curl -sSL -m 300 -o "$WORK/$label.raw" "$base/$loc" || return 1
  case "$loc" in
    *.zst) zstd -dqf "$WORK/$label.raw" -o "$WORK/$label.xml" ;;
    *.gz)  gzip -dc "$WORK/$label.raw" > "$WORK/$label.xml" ;;
  esac
  grep -oE '<name>[^<]+</name>' "$WORK/$label.xml" | sed 's/<name>//;s#</name>##' | sort -u > "$WORK/$label.list"
  printf "  %-22s %6d pacchetti\n" "$label" "$(wc -l < "$WORK/$label.list")"
}

echo "scarico i metadati dei repository..."
fetch_primary fedora  "https://dl.fedoraproject.org/pub/fedora/linux/releases/${FEDORA_VERSION}/Everything/${ARCH}/os"
fetch_primary updates "https://dl.fedoraproject.org/pub/fedora/linux/updates/${FEDORA_VERSION}/Everything/${ARCH}"
COPR_BASE="https://download.copr.fedorainfracloud.org/results"
fetch_primary copr-dms        "$COPR_BASE/avengemedia/dms/fedora-${FEDORA_VERSION}-${ARCH}"
fetch_primary copr-danklinux  "$COPR_BASE/avengemedia/danklinux/fedora-${FEDORA_VERSION}-${ARCH}"
fetch_primary copr-rendezvous "$COPR_BASE/peterwu/rendezvous/fedora-${FEDORA_VERSION}-${ARCH}"

# repo senza metadati facilmente interrogabili: elenco noto, va tenuto allineato
cat > "$WORK/altri.list" <<'EOF'
ffmpeg
x264-libs
tailscale
code
nvidia-container-toolkit
EOF

cat "$WORK"/*.list 2>/dev/null | sort -u > "$WORK/tutti.list"
echo "  ----------------------------------------"
printf "  %-22s %6d pacchetti noti\n" "TOTALE" "$(wc -l < "$WORK/tutti.list")"
echo

# ------------------------------------------------- pacchetti richiesti --------
# unisce le continuazioni di riga e prende gli argomenti di "dnf -y install"
awk '{ line=$0
       while (line ~ /\\[ \t]*$/) { sub(/\\[ \t]*$/,"",line); if ((getline nxt) > 0) line = line " " nxt; else break }
       print line }' "$BUILD_SH" \
  | grep -E '^[[:space:]]*dnf -y install' \
  | sed 's/^[[:space:]]*dnf -y install//' \
  | tr -s ' ' '\n' \
  `# scarta: vuoti, flag, URL, operatori di shell, e i frammenti prodotti dallo` \
  `# split su spazi di "$(rpm -E %fedora)" nelle righe che installano da URL` \
  | grep -vE '^$|^-|^https?:|^\|\||^true$|^\\$|^%|\.rpm$|^\$\(|^[A-Za-z_]+=' \
  | sort -u > "$WORK/richiesti.txt"

echo "build.sh richiede $(wc -l < "$WORK/richiesti.txt") pacchetti"
echo

fail=0
while read -r p; do
  [ -z "$p" ] && continue
  if grep -qxF "$p" "$WORK/tutti.list"; then
    printf "  ok    %s\n" "$p"
  else
    printf "  FAIL  %s  <-- nessun repo noto lo fornisce\n" "$p"
    fail=$((fail+1))
  fi
done < "$WORK/richiesti.txt"

echo
if [ "$fail" -eq 0 ]; then
  echo "OK: tutti i pacchetti sono risolvibili. Si può pushare."
  exit 0
else
  echo "STOP: $fail pacchetti non risolti. Correggi build.sh PRIMA di consumare una build CI."
  exit 1
fi
