FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Core tools + everything the SDK Manager / Simulator (Electron/GTK apps) need
RUN apt-get update && apt-get install -y \
    wget curl unzip git ca-certificates sudo \
    openjdk-17-jdk \
    libwebkit2gtk-4.0-37 \
    libgtk-3-0 \
    libnotify4 \
    libnss3 \
    libxss1 \
    libxtst6 \
    libasound2 \
    libgbm1 \
    libcurl4 \
    libusb-1.0-0 \
    libudev1 \
    fonts-liberation \
    libsecret-1-0 \
    libappindicator3-1 \
    xdg-utils \
    x11-apps \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Username/UID/GID are passed in from the host at build time (see
# devcontainer.json's build.args, which reads ${localEnv:USER} etc.) — so
# this Dockerfile works unmodified for any host user, not just "vb".
# Matching the host username means every path inside ~/.Garmin
# (sdkmanager-location.cfg, current-sdk.cfg, etc.) resolves identically
# whether read on the host or in the container, with zero path translation.
ARG USERNAME=vb
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd -g ${USER_GID} ${USERNAME} \
    && useradd -m -s /bin/bash -u ${USER_UID} -g ${USER_GID} ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER ${USERNAME}
WORKDIR /home/${USERNAME}

# CIQ_HOME can't use the ARG directly (ENV doesn't expand ARGs the same way
# after USER switches), so devcontainer.json's containerEnv sets the final
# value using the same ${localEnv:USER} substitution for consistency.
ENV DISPLAY=:0

# A stable, version-independent bin directory on PATH. This is set via
# Dockerfile ENV (not .bashrc), so it applies to every process in the
# container unconditionally — interactive shells, F5 debug runs, VS Code
# tasks, all of it — with no dependency on a particular shell sourcing
# .bashrc. The actual SDK tools (monkeyc, monkeydo, etc.) get symlinked in
# here by devcontainer.json's postCreateCommand once the SDK mount is live,
# since the real SDK lives in a versioned folder that doesn't exist yet
# at image build time.
ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"
RUN mkdir -p /home/${USERNAME}/.local/bin

CMD ["/bin/bash"]
