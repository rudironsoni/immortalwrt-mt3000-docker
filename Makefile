SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

ROOT := $(CURDIR)
UPSTREAM_URL := https://github.com/chasey-dev/immortalwrt-mt798x-rebase.git
UPSTREAM_BRANCH := 25.12
UPSTREAM_DIR := upstream/immortalwrt-mt798x-rebase

RELEASE := 25.12.0
TARGET := mediatek/filogic
TARGET_FLAT := mediatek-filogic
PROFILE := glinet_gl-mt3000
IMAGEBUILDER_NAME := immortalwrt-imagebuilder-$(RELEASE)-$(TARGET_FLAT).Linux-x86_64
IMAGEBUILDER_ARCHIVE := $(IMAGEBUILDER_NAME).tar.zst
IMAGEBUILDER_URL := https://downloads.immortalwrt.org/releases/$(RELEASE)/targets/$(TARGET)/$(IMAGEBUILDER_ARCHIVE)

DOCKER_IMAGE := mt3000-imagebuilder:bookworm
WORK_DIR := $(ROOT)/.work
IMAGEBUILDER_DIR := $(WORK_DIR)/$(IMAGEBUILDER_NAME)
DIST_DIR := $(ROOT)/dist
ROOTFS_OVERLAY := $(ROOT)/overlays/mt3000/rootfs
PACKAGE_LIST := $(ROOT)/overlays/travel-router/packages
FINAL_IMAGE := $(DIST_DIR)/mt3000-travel-router-sysupgrade.bin
BUILD_INFO := $(DIST_DIR)/build-info.txt
KERNEL_SEED := $(WORK_DIR)/glinet_gl-mt3000-kernel.bin
IMAGEBUILDER_KERNEL_DIR := build_dir/target-aarch64_cortex-a53_musl/linux-mediatek_filogic

DOCKER_RUN := docker run --rm --platform linux/amd64 \
	-v "$(ROOT):/repo" \
	-w /repo \
	$(DOCKER_IMAGE)

.PHONY: setup-env build test-wifi-defaults clean-work checksums

setup-env: $(WORK_DIR)/.setup-complete

$(WORK_DIR)/.docker-image:
	@mkdir -p "$(WORK_DIR)"
	@printf '%s\n' \
		'FROM debian:bookworm' \
		'RUN apt-get update && apt-get install -y --no-install-recommends bash build-essential ca-certificates curl file gawk gettext git libncurses5-dev libncursesw5-dev make patch perl python3 python3-distutils python3-setuptools rsync tar unzip wget xz-utils zstd && rm -rf /var/lib/apt/lists/*' \
		| docker build --platform linux/amd64 -t "$(DOCKER_IMAGE)" -f - .
	@touch "$@"

$(WORK_DIR)/.submodule-ready:
	@mkdir -p "$(WORK_DIR)"
	@if [ ! -d .git ]; then git init; fi
	@if [ ! -d "$(UPSTREAM_DIR)/.git" ] && [ ! -f "$(UPSTREAM_DIR)/.git" ]; then \
		mkdir -p upstream; \
		git submodule add -b "$(UPSTREAM_BRANCH)" "$(UPSTREAM_URL)" "$(UPSTREAM_DIR)"; \
	else \
		git submodule update --init --recursive "$(UPSTREAM_DIR)"; \
		git -C "$(UPSTREAM_DIR)" fetch origin "$(UPSTREAM_BRANCH)"; \
		git -C "$(UPSTREAM_DIR)" checkout "$(UPSTREAM_BRANCH)"; \
		git -C "$(UPSTREAM_DIR)" pull --ff-only origin "$(UPSTREAM_BRANCH)"; \
	fi
	@touch "$@"

$(WORK_DIR)/.imagebuilder-ready: $(WORK_DIR)/.docker-image
	@$(DOCKER_RUN) bash -lc '\
		mkdir -p /repo/.work && \
		cd /repo/.work && \
		if [ ! -f "$(IMAGEBUILDER_ARCHIVE)" ]; then \
			curl -fL --retry 3 --retry-delay 5 -o "$(IMAGEBUILDER_ARCHIVE)" "$(IMAGEBUILDER_URL)"; \
		fi && \
		if [ ! -f "$(IMAGEBUILDER_NAME)/Makefile" ]; then \
			rm -rf "$(IMAGEBUILDER_NAME)" && \
			tar --zstd -xf "$(IMAGEBUILDER_ARCHIVE)"; \
		fi && \
		cd "$(IMAGEBUILDER_NAME)" && \
		make info | grep -q "^$(PROFILE):"'
	@touch "$@"

$(WORK_DIR)/.setup-complete: $(WORK_DIR)/.submodule-ready $(WORK_DIR)/.imagebuilder-ready
	@mkdir -p "$(DIST_DIR)"
	@touch "$@"

$(WORK_DIR)/.imagebuilder-mt3000-patched: $(WORK_DIR)/.setup-complete
	perl -0pi -e 'BEGIN { $$from = q{$$(CP) $$(TARGET_DIR) $$(TARGET_DIR_ORIG)}; $$to = q{$$(CP) $$(TARGET_DIR) $$(TARGET_DIR_ORIG) || true}; } s/\Q$$from\E/$$to/' "$(IMAGEBUILDER_DIR)/Makefile"
	@touch "$@"

$(KERNEL_SEED):
	@mkdir -p "$(WORK_DIR)"
	@for candidate in \
		"$(ROOT)/upstream/immortalwrt-mt798x-rebase/build_dir/target-aarch64_cortex-a53_musl/linux-mediatek_filogic/glinet_gl-mt3000-kernel.bin" \
		"$(ROOT)/immortalwrt-mt798x-rebase/build_dir/target-aarch64_cortex-a53_musl/linux-mediatek_filogic/glinet_gl-mt3000-kernel.bin"; do \
		if [ -f "$$candidate" ]; then \
			cp "$$candidate" "$@"; \
			exit 0; \
		fi; \
	done; \
	if docker ps -a --format '{{.Names}}' | grep -qx 'immortalwrt-mt798x-build' && \
		docker exec immortalwrt-mt798x-build test -f /work/immortalwrt-mt798x-rebase/build_dir/target-aarch64_cortex-a53_musl/linux-mediatek_filogic/glinet_gl-mt3000-kernel.bin; then \
		docker cp immortalwrt-mt798x-build:/work/immortalwrt-mt798x-rebase/build_dir/target-aarch64_cortex-a53_musl/linux-mediatek_filogic/glinet_gl-mt3000-kernel.bin "$@"; \
		exit 0; \
	fi; \
	echo "ERROR: missing glinet_gl-mt3000-kernel.bin seed for ImageBuilder." >&2; \
	echo "Build the base upstream GL-MT3000 target once, then rerun make build." >&2; \
	exit 1

build: setup-env test-wifi-defaults $(KERNEL_SEED) $(WORK_DIR)/.imagebuilder-mt3000-patched
	@rm -rf "$(DIST_DIR)"
	@mkdir -p "$(DIST_DIR)"
	@$(DOCKER_RUN) bash -lc '\
		cd "/repo/.work/$(IMAGEBUILDER_NAME)" && \
		rm -rf bin build_dir tmp files && \
		mkdir -p "$(IMAGEBUILDER_KERNEL_DIR)" && \
		cp "/repo/.work/glinet_gl-mt3000-kernel.bin" "$(IMAGEBUILDER_KERNEL_DIR)/glinet_gl-mt3000-kernel.bin" && \
		packages="$$(sed -e "s/#.*//" -e "/^[[:space:]]*$$/d" "/repo/overlays/travel-router/packages" | tr "\n" " ")" && \
		echo "PROFILE=$(PROFILE)" && \
		echo "PACKAGES=$$packages" && \
		make image PROFILE="$(PROFILE)" FILES="/repo/overlays/mt3000/rootfs" PACKAGES="$$packages" && \
		rootfs="$$(find build_dir -type d -path "*/root-mediatek" | head -n 1)" && \
		test -n "$$rootfs" && \
		test -f "$$rootfs/etc/uci-defaults/99-mt3000-wifi-defaults" && \
		grep -R "GL-MT3000" "$$rootfs/etc/uci-defaults/99-mt3000-wifi-defaults" "$$rootfs/lib/wifi" >/dev/null && \
		if grep -R "ImmortalWrt-5G" "$$rootfs/etc/uci-defaults" "$$rootfs/lib/wifi" >/dev/null; then \
			echo "ERROR: final rootfs still contains ImmortalWrt-5G" >&2; \
			exit 1; \
		fi && \
		for pkg in modemmanager travelmate wireguard-tools openvpn-openssl tailscale adblock banip https-dns-proxy nlbwmon ksmbd-server curl tcpdump iperf3 wpad-openssl; do \
			grep -q "^$$pkg[[:space:]]" bin/targets/mediatek/filogic/*.manifest || { echo "ERROR: missing package in manifest: $$pkg" >&2; exit 1; }; \
		done && \
		mapfile -t images < <(find bin/targets/mediatek/filogic -maxdepth 1 -type f -name "*$(PROFILE)*squashfs-sysupgrade.bin" | sort) && \
		if [ "$${#images[@]}" -ne 1 ]; then \
			printf "ERROR: expected one sysupgrade image, found %s\n" "$${#images[@]}" >&2; \
			printf "%s\n" "$${images[@]}" >&2; \
			exit 1; \
		fi && \
		cp "$${images[0]}" "/repo/dist/mt3000-travel-router-sysupgrade.bin" && \
		tar -tf "/repo/dist/mt3000-travel-router-sysupgrade.bin" | grep -q "sysupgrade-$(PROFILE)/kernel" && \
		tar -tf "/repo/dist/mt3000-travel-router-sysupgrade.bin" | grep -q "sysupgrade-$(PROFILE)/root" && \
		sha256sum "/repo/dist/mt3000-travel-router-sysupgrade.bin" > "/repo/dist/sha256sums" && \
		{ \
			echo "release=$(RELEASE)"; \
			echo "target=$(TARGET)"; \
			echo "profile=$(PROFILE)"; \
			echo "imagebuilder=$(IMAGEBUILDER_URL)"; \
			echo "packages=$$packages"; \
		} > "/repo/dist/build-info.txt"'

test-wifi-defaults:
	@sh -n "$(ROOTFS_OVERLAY)/etc/uci-defaults/99-mt3000-wifi-defaults"
	@test -x "$(ROOTFS_OVERLAY)/etc/uci-defaults/99-mt3000-wifi-defaults"
	@test -x "$(ROOTFS_OVERLAY)/usr/bin/mt798x-board-info"
	@test -x "$(ROOTFS_OVERLAY)/usr/bin/mt3000-factory-wifi"
	@grep -R "GL-MT3000" "$(ROOTFS_OVERLAY)/etc/uci-defaults/99-mt3000-wifi-defaults" "$(ROOTFS_OVERLAY)/lib/wifi" >/dev/null
	@if grep -R "ImmortalWrt-5G" "$(ROOTFS_OVERLAY)/etc/uci-defaults" "$(ROOTFS_OVERLAY)/lib/wifi" >/dev/null; then \
		echo "ERROR: overlay still contains ImmortalWrt-5G" >&2; \
		exit 1; \
	fi

checksums:
	@sha256sum "$(FINAL_IMAGE)"

clean-work:
	@rm -rf "$(WORK_DIR)" "$(DIST_DIR)"
