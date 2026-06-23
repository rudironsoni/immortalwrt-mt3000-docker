
FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \

    ack \

    antlr3 \

    asciidoc \

    autoconf \

    automake \

    autopoint \

    bash \

    bc \

    binutils \

    bison \

    build-essential \

    bzip2 \

    ca-certificates \

    clang \

    cmake \

    cpio \

    curl \

    device-tree-compiler \

    ecj \

    fastjar \

    file \

    flex \

    g++ \

    gawk \

    gcc \

    gettext \

    git \

    gperf \

    help2man \

    intltool \

    libelf-dev \

    libglib2.0-dev \

    libncurses-dev \

    libssl-dev \

    libtool \

    libxml-parser-perl \

    libz-dev \

    libzstd-dev \

    make \

    msmtp \

    ninja-build \

    p7zip-full \

    patch \

    perl \

    pkgconf \

    python3 \

    python3-dev \

    python3-distutils \

    python3-pip \

    python3-pyelftools \

    python3-setuptools \

    qemu-utils \

    rsync \

    scons \

    squashfs-tools \

    subversion \

    swig \

    tar \

    texinfo \

    time \

    uglifyjs \

    unzip \

    wget \

    xz-utils \

    zlib1g-dev \

    zstd \

 && apt-get clean \

 && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash builder \

 && mkdir -p /work \

 && chown -R builder:builder /work

USER builder

WORKDIR /work

SHELL ["/bin/bash", "-lc"]

