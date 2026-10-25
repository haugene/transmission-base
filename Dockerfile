# Ubuntu LTS + Transmission built from source.
# Shared base for the wireguard and openvpn images.

# -----------------------------------------------------------------------------
# Build arguments (override at build time to retarget versions)
# -----------------------------------------------------------------------------
ARG UBUNTU_VERSION=26.04.1
ARG TRANSMISSION_VERSION=4.1.4
# From https://transmissionbt.com/download — bump together with TRANSMISSION_VERSION.
ARG TRANSMISSION_SHA256=86e7aa020cdf64826447034bc85f4d3b7c848d8c0891d9dc9b9fddfb2c805d22

# -----------------------------------------------------------------------------
# Stage 1: build Transmission from the official release tarball
# -----------------------------------------------------------------------------
FROM ubuntu:${UBUNTU_VERSION} AS builder

ARG TRANSMISSION_VERSION
ARG TRANSMISSION_SHA256
ARG DEBIAN_FRONTEND=noninteractive

# Build tools + development headers for libraries we link against at runtime.
# Optional Transmission dependencies are installed from the system so the
# resulting binaries use Ubuntu packages (easier to refresh via image rebuilds)
# instead of statically bundling third-party code into the daemon.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        ninja-build \
        pkg-config \
        xz-utils \
        libcurl4-openssl-dev \
        libssl-dev \
        libevent-dev \
        libminiupnpc-dev \
        libnatpmp-dev \
        libdeflate-dev \
        libpsl-dev \
        libb64-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Official release tarballs include the third-party submodules we need.
# Pin the checksum so accidental/corrupt downloads fail the build.
RUN curl -fsSL \
        "https://github.com/transmission/transmission/releases/download/${TRANSMISSION_VERSION}/transmission-${TRANSMISSION_VERSION}.tar.xz" \
        -o transmission.tar.xz \
    && echo "${TRANSMISSION_SHA256}  transmission.tar.xz" | sha256sum -c - \
    && tar -xJf transmission.tar.xz \
    && rm transmission.tar.xz \
    && mv "transmission-${TRANSMISSION_VERSION}" transmission

WORKDIR /src/transmission

# Daemon + utils + stock web UI. Disable desktop clients, tests, docs, and
# systemd. Install under /usr so paths match Ubuntu packages and downstream
# hardcoded /usr/bin/transmission-daemon references.
RUN cmake -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DENABLE_DAEMON=ON \
        -DENABLE_UTILS=ON \
        -DENABLE_CLI=OFF \
        -DENABLE_GTK=OFF \
        -DENABLE_QT=OFF \
        -DENABLE_MAC=OFF \
        -DENABLE_TESTS=OFF \
        -DENABLE_NLS=OFF \
        -DINSTALL_WEB=ON \
        -DREBUILD_WEB=OFF \
        -DINSTALL_DOC=OFF \
        -DINSTALL_LIB=OFF \
        -DWITH_SYSTEMD=OFF \
        -DRUN_CLANG_TIDY=OFF \
    && cmake --build build \
    && cmake --install build --strip \
    && rm -rf build

# -----------------------------------------------------------------------------
# Stage 2: minimal runtime image
# -----------------------------------------------------------------------------
FROM ubuntu:${UBUNTU_VERSION}

ARG UBUNTU_VERSION
ARG TRANSMISSION_VERSION
ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="transmission-base" \
      org.opencontainers.image.description="Shared Ubuntu + Transmission base for haugene VPN images" \
      org.opencontainers.image.source="https://github.com/haugene/transmission-base" \
      org.opencontainers.image.licenses="MIT" \
      transmission.version="${TRANSMISSION_VERSION}" \
      ubuntu.version="${UBUNTU_VERSION}"

# Runtime shared libraries matching the builder link set.
# Package names follow Ubuntu's t64 ABI transition (24.04+).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        libcurl4t64 \
        libssl3t64 \
        libevent-2.1-7t64 \
        libminiupnpc21 \
        libnatpmp1t64 \
        libdeflate0 \
        libpsl5t64 \
        libb64-0d \
    && rm -rf /var/lib/apt/lists/*

# Binaries and stock web UI (release tarball assets; REBUILD_WEB is off).
COPY --from=builder /usr/bin/transmission-* /usr/bin/
COPY --from=builder /usr/share/transmission/ /usr/share/transmission/

RUN test -x /usr/bin/transmission-daemon \
    && /usr/bin/transmission-daemon --version \
    && /usr/bin/transmission-remote --version \
    && test -f /usr/share/transmission/public_html/index.html
