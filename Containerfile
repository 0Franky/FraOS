# FraOS Containerfile — adattato da MorrOS / ublue image-template.
# Entry-point della build: parte da un'immagine base atomica e vi applica build.sh.

# ------------------------------------------------------------------------- #
# IMMAGINE BASE (default: Bazzite GNOME NVIDIA — scelta di MorrOS).
# Override per i tag "prova" (bluefin/rakuos): --build-arg BASE_IMAGE=...
# vedi .github/workflows/build-variants.yml
#
# ATTENZIONE: questo ARG deve stare PRIMA di qualsiasi FROM. Un ARG dichiarato
# dopo un FROM appartiene a quello stage e NON e' visibile alle istruzioni FROM
# successive: ${BASE_IMAGE} si espanderebbe a stringa vuota e la build muore con
# "no FROM statement found" (successo il 2026-08-20, run 32366351579).
# ------------------------------------------------------------------------- #
ARG BASE_IMAGE="ghcr.io/ublue-os/bazzite-gnome-nvidia:stable"

# Stage "ctx": rende build_files/ referenziabile senza copiarlo nell'immagine finale
FROM scratch AS ctx
COPY build_files /

FROM ${BASE_IMAGE}

# Alcuni repo COPR si basano sull'ID "fedora": normalizzalo.
RUN sed -i 's/^ID=.*/ID=fedora/' /etc/os-release

## Basi alternative (usate dai tag "prova" — 1 install, poi `bootc switch`):
#   ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable   # dev-oriented, NVIDIA-open, Secure Boot ON
#   quay.io/rakuos/rakuos-base-nvidia:latest         # kernel CachyOS, NVIDIA unsigned -> Secure Boot OFF
#   (RakuOS ha migrato su GitLab; le immagini stanno ora su quay.io)

# Homebrew (CLI user-space) dall'immagine ublue brew
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /usr/bin/systemctl preset brew-setup.service && \
    /usr/bin/systemctl preset brew-update.timer && \
    /usr/bin/systemctl preset brew-upgrade.timer

# Esegue lo script di build
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

# Verifica finale dell'immagine bootc
RUN bootc container lint
