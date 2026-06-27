ROOT := $(CURDIR)
WORK_DIR := $(ROOT)/.work
DIST_DIR := $(ROOT)/dist
UPSTREAM_DIR := $(ROOT)/upstream/immortalwrt-mt798x-rebase
ROOTFS_OVERLAY := $(ROOT)/overlays/mt3000/rootfs
KERNEL_COMPAT_DIR := $(ROOT)/overlays/kernel-compat
PACKAGE_PATCHES_DIR := $(ROOT)/overlays/package-patches
TRAVEL_PACKAGES_FILE := $(ROOT)/overlays/travel-router/packages

TARGET := mediatek/filogic
TARGET_BOARD := mediatek
SUBTARGET := filogic
PROFILE := glinet_gl-mt3000
TARGET_PROFILE := DEVICE_glinet_gl-mt3000
ARCH_PACKAGES := aarch64_cortex-a53
EXPECTED_UPSTREAM_REMOTE := https://github.com/chasey-dev/immortalwrt-mt798x-rebase.git

JOBS ?= 1
SOURCE_PLATFORM ?= linux/arm64
SOURCE_VOLUME_SUFFIX ?= $(subst /,-,$(SOURCE_PLATFORM))
IMAGEBUILDER_RELEASE ?= 25.12.0
IMAGEBUILDER_HOST ?= x86_64
IMAGEBUILDER_PLATFORM ?= linux/amd64
IMAGEBUILDER_VOLUME ?= mt3000-imagebuilder
IMAGEBUILDER_APT_CACHE_VOLUME ?= mt3000-imagebuilder-apt-cache
IMAGEBUILDER_APT_LISTS_VOLUME ?= mt3000-imagebuilder-apt-lists
CCACHE_VOLUME ?= mt3000-ccache
IMAGEBUILDER_NAME := immortalwrt-imagebuilder-$(IMAGEBUILDER_RELEASE)-$(TARGET_BOARD)-$(SUBTARGET).Linux-$(IMAGEBUILDER_HOST)
IMAGEBUILDER_TARBALL := $(IMAGEBUILDER_NAME).tar.zst
IMAGEBUILDER_BASE_URL := https://downloads.immortalwrt.org/releases/$(IMAGEBUILDER_RELEASE)/targets/$(TARGET)
IMAGEBUILDER_URL := $(IMAGEBUILDER_BASE_URL)/$(IMAGEBUILDER_TARBALL)
IMAGEBUILDER_SHA256SUMS_URL := $(IMAGEBUILDER_BASE_URL)/sha256sums
DOCKER_IMAGE := mt3000-source-builder:bookworm
IMAGEBUILDER_DOCKER_IMAGE ?= debian:bookworm-slim
DOCKERFILE ?= Dockerfile
IMAGEBUILDER_DOCKERFILE ?= $(DOCKERFILE)
DOCKER_BUILD_FLAGS ?= --pull=false
DOCKER_BUILDKIT ?= 0
IMAGEBUILDER_DOCKER_BUILDKIT ?= 1
IMAGEBUILDER_RUNNER_PACKAGES := bzip2 ca-certificates curl file findutils gawk grep gzip make patch perl python3 python3-distutils rsync squashfs-tools tar unzip wget xz-utils zstd
FAST_LOCAL_PACKAGE_DIRS ?= \
	package/network/utils/iwinfo-ucode \
	package/mtk/applications/datconf \
	package/mtk/applications/l1parser \
	package/mtk/applications/mtwifi-cfg-ucode \
	package/mtk/applications/luci-app-mtwifi-cfg
FAST_IMAGEBUILDER_LOCAL_PACKAGES ?= \
	iwinfo-ucode \
	ucode-mod-iwinfo \
	libkvcutil \
	kvcedit \
	datconf \
	ucode-mod-datconf \
	libl1parser \
	l1util \
	ucode-mod-l1parser \
	mtwifi-cfg-ucode \
	luci-app-mtwifi-cfg
SOURCE_BUILD_VOLUME := mt3000-$(SOURCE_VOLUME_SUFFIX)-build-dir
SOURCE_STAGING_VOLUME := mt3000-$(SOURCE_VOLUME_SUFFIX)-staging-dir
SOURCE_TMP_VOLUME := mt3000-$(SOURCE_VOLUME_SUFFIX)-tmp
SOURCE_BIN_VOLUME := mt3000-$(SOURCE_VOLUME_SUFFIX)-bin
SOURCE_DL_VOLUME := mt3000-dl
SOURCE_CCACHE_VOLUME := mt3000-$(SOURCE_VOLUME_SUFFIX)-ccache
DOCKER_RUN := docker run --rm --platform $(SOURCE_PLATFORM) \
--ulimit nofile=1048576:1048576 \
-v "$(ROOT):/repo" \
-v $(SOURCE_BUILD_VOLUME):/repo/upstream/immortalwrt-mt798x-rebase/build_dir \
-v $(SOURCE_STAGING_VOLUME):/repo/upstream/immortalwrt-mt798x-rebase/staging_dir \
-v $(SOURCE_TMP_VOLUME):/repo/upstream/immortalwrt-mt798x-rebase/tmp \
-v $(SOURCE_BIN_VOLUME):/repo/upstream/immortalwrt-mt798x-rebase/bin \
-v $(SOURCE_DL_VOLUME):/repo/upstream/immortalwrt-mt798x-rebase/dl \
-v $(SOURCE_CCACHE_VOLUME):/repo/upstream/immortalwrt-mt798x-rebase/.ccache \
-w /repo \
$(DOCKER_IMAGE)
DOCKER_RUN_ROOT := docker run --rm --platform $(SOURCE_PLATFORM) \
--user root \
-v "$(ROOT):/repo" \
-v $(SOURCE_BUILD_VOLUME):/repo/upstream/immortalwrt-mt798x-rebase/build_dir \
-v $(SOURCE_STAGING_VOLUME):/repo/upstream/immortalwrt-mt798x-rebase/staging_dir \
-v $(SOURCE_TMP_VOLUME):/repo/upstream/immortalwrt-mt798x-rebase/tmp \
-v $(SOURCE_BIN_VOLUME):/repo/upstream/immortalwrt-mt798x-rebase/bin \
-v $(SOURCE_DL_VOLUME):/repo/upstream/immortalwrt-mt798x-rebase/dl \
-v $(SOURCE_CCACHE_VOLUME):/repo/upstream/immortalwrt-mt798x-rebase/.ccache \
-w /repo \
$(DOCKER_IMAGE)
DOCKER_RUN_IMAGEBUILDER := docker run --rm --platform $(IMAGEBUILDER_PLATFORM) \
--ulimit nofile=1048576:1048576 \
-v "$(ROOT):/repo" \
-v $(SOURCE_BIN_VOLUME):/repo/upstream/immortalwrt-mt798x-rebase/bin \
-v $(IMAGEBUILDER_VOLUME):/imagebuilder \
-v $(IMAGEBUILDER_APT_CACHE_VOLUME):/var/cache/apt \
-v $(IMAGEBUILDER_APT_LISTS_VOLUME):/var/lib/apt/lists \
-w /repo \
$(IMAGEBUILDER_DOCKER_IMAGE)
DOCKER_RUN_IMAGEBUILDER_ROOT := docker run --rm --platform $(IMAGEBUILDER_PLATFORM) \
--user root \
-v "$(ROOT):/repo" \
-v $(SOURCE_BIN_VOLUME):/repo/upstream/immortalwrt-mt798x-rebase/bin \
-v $(IMAGEBUILDER_VOLUME):/imagebuilder \
-v $(IMAGEBUILDER_APT_CACHE_VOLUME):/var/cache/apt \
-v $(IMAGEBUILDER_APT_LISTS_VOLUME):/var/lib/apt/lists \
-w /repo \
$(IMAGEBUILDER_DOCKER_IMAGE)

PACKAGE_LIST := $(shell awk 'NF && $$1 !~ /^\#/ { printf "%s ", $$1 }' $(TRAVEL_PACKAGES_FILE))
REQUIRED_PACKAGES := $(filter-out -%,$(PACKAGE_LIST))

SYSUPGRADE_IMAGE := $(DIST_DIR)/mt3000-travel-router-sysupgrade.bin
INITRAMFS_IMAGE := $(DIST_DIR)/mt3000-travel-router-initramfs-kernel.bin
MANIFEST := $(DIST_DIR)/mt3000-travel-router.manifest
BUILD_INFO := $(DIST_DIR)/build-info.txt
FAST_DIST_DIR := $(DIST_DIR)/fast
FAST_SYSUPGRADE_IMAGE := $(FAST_DIST_DIR)/mt3000-travel-router-sysupgrade.bin
FAST_MANIFEST := $(FAST_DIST_DIR)/mt3000-travel-router.manifest
FAST_BUILD_INFO := $(FAST_DIST_DIR)/build-info.txt
BENCHMARK_INFO := $(DIST_DIR)/benchmark-builds.txt

.PHONY: build upstream-firmware fast-build setup-env setup-imagebuilder-env init-build-volumes validate-upstream configure-source prepare-rootfs-overlay prepare-imagebuilder build-fast-local-packages stage-fast-local-packages validate-imagebuilder-package-inputs apply-kernel-compat-patches upstream-source-build source-build source-build-with-kernel-clean collect-artifacts collect-fast-artifacts validate-artifacts validate-fast-artifacts checksums fast-checksums benchmark-builds clean-rootfs-overlay clean distclean status test-wifi-defaults

build: setup-env validate-upstream test-wifi-defaults configure-source prepare-rootfs-overlay source-build-with-kernel-clean collect-artifacts validate-artifacts checksums clean-rootfs-overlay validate-upstream

upstream-firmware: setup-env validate-upstream configure-source upstream-source-build

fast-build: setup-env setup-imagebuilder-env test-wifi-defaults configure-source prepare-imagebuilder build-fast-local-packages stage-fast-local-packages validate-imagebuilder-package-inputs collect-fast-artifacts validate-fast-artifacts fast-checksums

setup-env: $(WORK_DIR)/.docker-image init-build-volumes

setup-imagebuilder-env:
	@:

$(WORK_DIR):
	@mkdir -p "$(WORK_DIR)"

$(DIST_DIR):
	@mkdir -p "$(DIST_DIR)"

$(FAST_DIST_DIR):
	@mkdir -p "$(FAST_DIST_DIR)"

$(WORK_DIR)/.docker-image: $(DOCKERFILE) | $(WORK_DIR)
	DOCKER_BUILDKIT=$(DOCKER_BUILDKIT) docker build $(DOCKER_BUILD_FLAGS) -f "$(DOCKERFILE)" -t "$(DOCKER_IMAGE)" .
	@touch "$@"

$(WORK_DIR)/.imagebuilder-docker-image: $(IMAGEBUILDER_DOCKERFILE) | $(WORK_DIR)
	DOCKER_BUILDKIT=$(IMAGEBUILDER_DOCKER_BUILDKIT) docker build $(DOCKER_BUILD_FLAGS) --platform "$(IMAGEBUILDER_PLATFORM)" -f "$(IMAGEBUILDER_DOCKERFILE)" -t "$(IMAGEBUILDER_DOCKER_IMAGE)" .
	@touch "$@"

init-build-volumes:
	$(DOCKER_RUN_ROOT) bash -lc 'set -eu; \
	for dir in \
	/repo/upstream/immortalwrt-mt798x-rebase/build_dir \
	/repo/upstream/immortalwrt-mt798x-rebase/staging_dir \
	/repo/upstream/immortalwrt-mt798x-rebase/tmp \
	/repo/upstream/immortalwrt-mt798x-rebase/bin \
	/repo/upstream/immortalwrt-mt798x-rebase/dl \
	/repo/upstream/immortalwrt-mt798x-rebase/.ccache; do \
	mkdir -p "$$dir"; \
	chown -R builder:builder "$$dir"; \
	done'

validate-upstream:
	@test -e "$(UPSTREAM_DIR)/.git" || { echo "ERROR: missing upstream submodule at $(UPSTREAM_DIR)"; exit 1; }
	@remote="$$(git -C "$(UPSTREAM_DIR)" remote get-url origin)"; \
		test "$$remote" = "$(EXPECTED_UPSTREAM_REMOTE)" || { echo "ERROR: upstream origin is $$remote, expected $(EXPECTED_UPSTREAM_REMOTE)"; exit 1; }
	@test -z "$$(git -C "$(UPSTREAM_DIR)" status --porcelain)" || { git -C "$(UPSTREAM_DIR)" status --short; echo "ERROR: upstream submodule has uncommitted source changes"; exit 1; }

test-wifi-defaults:
	@for file in \
		"$(ROOTFS_OVERLAY)/lib/functions/mt798x-board.sh" \
		"$(ROOTFS_OVERLAY)/usr/bin/mt798x-board-info" \
		"$(ROOTFS_OVERLAY)/usr/bin/mt3000-factory-wifi" \
		"$(ROOTFS_OVERLAY)/etc/uci-defaults/99-mt3000-wifi-defaults"; do \
		sh -n "$$file"; \
	done
	@MT798X_BOARD_LIB="$(ROOTFS_OVERLAY)/lib/functions/mt798x-board.sh" \
		MT798X_LABEL_MAC="94:83:c4:44:94:da" \
		MT798X_WIFI_KEY="HQTCS5BEJ9" \
		"$(ROOTFS_OVERLAY)/usr/bin/mt798x-board-info" ssid-2g | grep -qx 'GL-MT3000-4da'
	@MT798X_BOARD_LIB="$(ROOTFS_OVERLAY)/lib/functions/mt798x-board.sh" \
		MT798X_LABEL_MAC="94:83:c4:44:94:da" \
		MT798X_WIFI_KEY="HQTCS5BEJ9" \
		"$(ROOTFS_OVERLAY)/usr/bin/mt798x-board-info" ssid-5g | grep -qx 'GL-MT3000-4da'
	@MT798X_BOARD_LIB="$(ROOTFS_OVERLAY)/lib/functions/mt798x-board.sh" \
		MT798X_LABEL_MAC="94:83:c4:44:94:da" \
		MT798X_WIFI_KEY="HQTCS5BEJ9" \
		"$(ROOTFS_OVERLAY)/usr/bin/mt798x-board-info" wifi-key | grep -qx 'HQTCS5BEJ9'
	@! grep -R -- '-5G' "$(ROOTFS_OVERLAY)"

configure-source:
	$(DOCKER_RUN) bash -lc 'set -eu; \
		cd /repo/upstream/immortalwrt-mt798x-rebase; \
		rm -f scripts/config/conf scripts/config/mconf scripts/config/nconf scripts/config/*.o; \
		cp defconfig/mt7981-ax3000.config .config; \
		MAKEFLAGS= /usr/bin/make defconfig V=s; \
		MAKEFLAGS= /usr/bin/make tools/install V=s; \
		rm -rf tmp/*; \
		./scripts/feeds update -a; \
		./scripts/feeds install -a; \
		for patch in /repo/overlays/package-patches/*.patch; do \
			test -e "$$patch" || continue; \
			patch -p1 --forward < "$$patch" || grep -q "DEPENDS:=+iwinfo-ucode" feeds/packages/net/travelmate/Makefile; \
		done; \
		grep -v -E "^(CONFIG_TARGET_MULTI_PROFILE=|CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_|CONFIG_TARGET_DEVICE_PACKAGES_mediatek_filogic_DEVICE_|CONFIG_TARGET_PROFILE=)" defconfig/mt7981-ax3000.config > .config; \
		hash="$$(printf "\043")"; \
		{ \
			printf "%s%s\n" "$$hash" " CONFIG_TARGET_MULTI_PROFILE is not set"; \
			printf "%s\n" "CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_glinet_gl-mt3000=y"; \
			printf "%s\n" "CONFIG_TARGET_DEVICE_PACKAGES_mediatek_filogic_DEVICE_glinet_gl-mt3000=\"\""; \
			printf "%s\n" "CONFIG_TARGET_PROFILE=\"$(TARGET_PROFILE)\""; \
			printf "%s\n" "CONFIG_TARGET_$(TARGET_BOARD)_$(SUBTARGET)_DEVICE_glinet_gl-mt3000=y"; \
			printf "%s\n" "CONFIG_DEVEL=y"; \
			printf "%s\n" "CONFIG_CCACHE=y"; \
			printf "%s\n" "CONFIG_CCACHE_DIR=\"/repo/upstream/immortalwrt-mt798x-rebase/.ccache\""; \
			printf "%s\n" "CONFIG_DOWNLOAD_FOLDER=\"/repo/upstream/immortalwrt-mt798x-rebase/dl\""; \
			printf "%s\n" "CONFIG_USE_APK=y"; \
			printf "%s\n" "CONFIG_PER_FEED_REPO=y"; \
			printf "%s%s\n" "$$hash" " CONFIG_IB is not set"; \
			printf "%s%s\n" "$$hash" " CONFIG_IB_STANDALONE is not set"; \
			printf "%s%s\n" "$$hash" " CONFIG_SDK is not set"; \
			printf "%s%s\n" "$$hash" " CONFIG_SDK_LLVM_BPF is not set"; \
			printf "%s%s\n" "$$hash" " CONFIG_ALL_KMODS is not set"; \
			printf "%s%s\n" "$$hash" " CONFIG_ALL_NONSHARED is not set"; \
			printf "%s\n" "CONFIG_TARGET_ROOTFS_INITRAMFS=y"; \
			printf "%s\n" "CONFIG_TARGET_ROOTFS_INITRAMFS_SEPARATE=y"; \
		} >> .config; \
		while IFS= read -r package; do \
			test -n "$$package" || continue; \
			first="$$(printf "%.1s" "$$package")"; \
			test "$$first" = "$$hash" && continue; \
			if test "$$first" = "-"; then \
				name="$$(printf "%s" "$$package" | sed "s/^-//")"; \
				printf "%s%s%s\n" "$$hash" " CONFIG_PACKAGE_$$name" " is not set" >> .config; \
			else \
				printf "%s\n" "CONFIG_PACKAGE_$$package=y" >> .config; \
			fi; \
		done < /repo/overlays/travel-router/packages; \
		rm -rf bin/targets/$(TARGET); \
		MAKEFLAGS= /usr/bin/make defconfig; \
		grep -qx "CONFIG_PACKAGE_luci-app-mtwifi-cfg=y" .config; \
		grep -qx "CONFIG_PACKAGE_mtwifi-cfg-ucode=y" .config; \
		grep -qx "CONFIG_PACKAGE_iwinfo-ucode=y" .config; \
		grep -qx "# CONFIG_PACKAGE_iwinfo is not set" .config'

prepare-rootfs-overlay: clean-rootfs-overlay
	@mkdir -p "$(UPSTREAM_DIR)/files"
	@rsync -a "$(ROOTFS_OVERLAY)/" "$(UPSTREAM_DIR)/files/"
	@chmod 0755 \
		"$(UPSTREAM_DIR)/files/usr/bin/mt798x-board-info" \
		"$(UPSTREAM_DIR)/files/usr/bin/mt3000-factory-wifi" \
		"$(UPSTREAM_DIR)/files/etc/uci-defaults/99-mt3000-wifi-defaults"

prepare-imagebuilder:
	$(DOCKER_RUN_IMAGEBUILDER_ROOT) bash -lc 'set -eu; \
		export DEBIAN_FRONTEND=noninteractive; \
		apt-get update; \
		apt-get install -y --no-install-recommends $(IMAGEBUILDER_RUNNER_PACKAGES); \
		mkdir -p /imagebuilder; \
		cd /imagebuilder; \
		if [ ! -f "$(IMAGEBUILDER_NAME)/Makefile" ]; then \
			rm -rf "$(IMAGEBUILDER_NAME)" sha256sums; \
			if [ ! -s "$(IMAGEBUILDER_TARBALL)" ]; then \
				curl -fL -o "$(IMAGEBUILDER_TARBALL)" "$(IMAGEBUILDER_URL)"; \
			fi; \
			curl -fL -o sha256sums "$(IMAGEBUILDER_SHA256SUMS_URL)"; \
			awk -v file="$(IMAGEBUILDER_TARBALL)" '\''$$2 == file || $$2 == "*" file { print; found=1 } END { exit !found }'\'' sha256sums | sha256sum -c -; \
			tar --zstd -xf "$(IMAGEBUILDER_TARBALL)"; \
		fi; \
		test -f "$(IMAGEBUILDER_NAME)/Makefile"'

validate-imagebuilder-package-inputs:
	$(DOCKER_RUN_IMAGEBUILDER_ROOT) bash -lc 'set -eu; \
		cd /imagebuilder/$(IMAGEBUILDER_NAME); \
		missing=""; \
		for package in $(FAST_IMAGEBUILDER_LOCAL_PACKAGES); do \
			if ! find packages -maxdepth 1 -type f -name "$$package-*.apk" | grep -q .; then \
				missing="$$missing $$package"; \
			fi; \
		done; \
		if [ -n "$$missing" ]; then \
			echo "ERROR: public ImmortalWrt ImageBuilder $(IMAGEBUILDER_RELEASE) is missing required MTK packages:$$missing"; \
			echo "Use make build for the exact chasey-dev source build, or provide an ImageBuilder/packages feed containing these packages."; \
			exit 1; \
		fi'

build-fast-local-packages: configure-source
	$(DOCKER_RUN) bash -lc 'set -eu; \
		cd /repo/upstream/immortalwrt-mt798x-rebase; \
		MAKEFLAGS= /usr/bin/make -j$(JOBS) tools/install toolchain/install V=s; \
		for package_dir in $(FAST_LOCAL_PACKAGE_DIRS); do \
			MAKEFLAGS= /usr/bin/make -j$(JOBS) "$$package_dir/compile" V=s; \
		done'

stage-fast-local-packages: prepare-imagebuilder
	$(DOCKER_RUN_IMAGEBUILDER_ROOT) bash -lc 'set -eu; \
		cd /imagebuilder/$(IMAGEBUILDER_NAME); \
		mkdir -p packages; \
		for package in $(FAST_IMAGEBUILDER_LOCAL_PACKAGES); do \
			rm -f packages/"$$package"-*.apk; \
		done; \
		missing=""; \
		for package in $(FAST_IMAGEBUILDER_LOCAL_PACKAGES); do \
			apk="$$(find /repo/upstream/immortalwrt-mt798x-rebase/bin/packages -type f -name "$$package-*.apk" | sort | tail -1)"; \
			if [ -z "$$apk" ]; then \
				missing="$$missing $$package"; \
				continue; \
			fi; \
			cp "$$apk" packages/; \
		done; \
		if [ -n "$$missing" ]; then \
			echo "ERROR: fork-local APKs were not built:$$missing"; \
			exit 1; \
		fi'

apply-kernel-compat-patches:
	$(DOCKER_RUN) bash -lc 'set -eu; \
		cd /repo/upstream/immortalwrt-mt798x-rebase; \
		linux_dir="$$(find build_dir/target-$(ARCH_PACKAGES)_musl/linux-$(TARGET_BOARD)_$(SUBTARGET) -maxdepth 2 -type d -name "linux-6.12.*" | sort | tail -1)"; \
		test -n "$$linux_dir" || { echo "ERROR: kernel build directory not found"; exit 1; }; \
		rm -f "$$linux_dir/include/uapi/linux/netfilter_ipv4/ipt_ECN.h"; \
		cp /repo/overlays/kernel-compat/ipt_ECN.h "$$linux_dir/include/uapi/linux/netfilter_ipv4/ipt_ECN.h"; \
		echo "Applied kernel compatibility overlay to $$linux_dir"'

seed-source-cache:
	$(DOCKER_RUN) bash -lc 'set -eu; \
		cd /repo/upstream/immortalwrt-mt798x-rebase; \
		if [ ! -s dl/libev-4.33.tar.gz ]; then \
			curl -fL --max-time 60 -o dl/libev-4.33.tar.gz.tmp https://sources.openwrt.org/libev-4.33.tar.gz; \
			mv dl/libev-4.33.tar.gz.tmp dl/libev-4.33.tar.gz; \
		fi'

upstream-source-build: seed-source-cache
	$(DOCKER_RUN) bash -lc 'set -eu; cd /repo/upstream/immortalwrt-mt798x-rebase; MAKEFLAGS= /usr/bin/make tools/install toolchain/install V=s'
	$(DOCKER_RUN) bash -lc 'set -eu; cd /repo/upstream/immortalwrt-mt798x-rebase; MAKEFLAGS= /usr/bin/make target/linux/prepare V=s'
	$(DOCKER_RUN) bash -lc 'set -eu; cd /repo/upstream/immortalwrt-mt798x-rebase; MAKEFLAGS= /usr/bin/make -j$(JOBS) V=s'

source-build: seed-source-cache
	$(DOCKER_RUN) bash -lc 'set -eu; cd /repo/upstream/immortalwrt-mt798x-rebase; MAKEFLAGS= /usr/bin/make tools/install toolchain/install V=s'
	$(DOCKER_RUN) bash -lc 'set -eu; cd /repo/upstream/immortalwrt-mt798x-rebase; MAKEFLAGS= /usr/bin/make target/linux/prepare V=s'
	$(MAKE) apply-kernel-compat-patches
	$(DOCKER_RUN) bash -lc 'set -eu; cd /repo/upstream/immortalwrt-mt798x-rebase; MAKEFLAGS= /usr/bin/make -j$(JOBS) V=s'

source-build-with-kernel-clean: seed-source-cache
	$(DOCKER_RUN) bash -lc 'set -eu; cd /repo/upstream/immortalwrt-mt798x-rebase; MAKEFLAGS= /usr/bin/make tools/install toolchain/install V=s'
	$(DOCKER_RUN) bash -lc 'set -eu; cd /repo/upstream/immortalwrt-mt798x-rebase; MAKEFLAGS= /usr/bin/make target/linux/clean V=s'
	$(DOCKER_RUN) bash -lc 'set -eu; cd /repo/upstream/immortalwrt-mt798x-rebase; MAKEFLAGS= /usr/bin/make target/linux/prepare V=s'
	$(MAKE) apply-kernel-compat-patches
	$(DOCKER_RUN) bash -lc 'set -eu; cd /repo/upstream/immortalwrt-mt798x-rebase; MAKEFLAGS= /usr/bin/make -j$(JOBS) V=s'

collect-fast-artifacts: | $(FAST_DIST_DIR)
	$(DOCKER_RUN_IMAGEBUILDER_ROOT) bash -lc 'set -eu; \
		export DEBIAN_FRONTEND=noninteractive; \
		apt-get update; \
		apt-get install -y --no-install-recommends $(IMAGEBUILDER_RUNNER_PACKAGES); \
		cd /imagebuilder/$(IMAGEBUILDER_NAME); \
		rm -rf /repo/dist/fast/*; \
		MAKEFLAGS= /usr/bin/make image \
			PROFILE="$(PROFILE)" \
			PACKAGES="$(PACKAGE_LIST)" \
			FILES="/repo/overlays/mt3000/rootfs" \
			BIN_DIR="/repo/dist/fast" \
			EXTRA_IMAGE_NAME="travel-router"; \
		sysupgrade="$$(find /repo/dist/fast -type f -name "*$(PROFILE)*travel-router*squashfs-sysupgrade.bin" | sort | tail -1)"; \
		test -n "$$sysupgrade" || sysupgrade="$$(find /repo/dist/fast -type f -name "*$(PROFILE)*squashfs-sysupgrade.bin" | sort | tail -1)"; \
		manifest="$$(find /repo/dist/fast -type f -name "*$(PROFILE)*travel-router*.manifest" | sort | tail -1)"; \
		test -n "$$manifest" || manifest="$$(find /repo/dist/fast -type f -name "*$(PROFILE)*.manifest" | sort | tail -1)"; \
		test -n "$$sysupgrade" || { echo "ERROR: GL-MT3000 fast sysupgrade image not found"; exit 1; }; \
		test -n "$$manifest" || { echo "ERROR: GL-MT3000 fast manifest not found"; exit 1; }; \
		cp "$$sysupgrade" /repo/dist/fast/mt3000-travel-router-sysupgrade.bin; \
		cp "$$manifest" /repo/dist/fast/mt3000-travel-router.manifest'
	@{ \
		echo "imagebuilder_release=$(IMAGEBUILDER_RELEASE)"; \
		echo "imagebuilder_url=$(IMAGEBUILDER_URL)"; \
		echo "target=$(TARGET)"; \
		echo "profile=$(PROFILE)"; \
		echo "built_at_utc=$$(date -u '+%Y-%m-%dT%H:%M:%SZ')"; \
		echo "packages=$(PACKAGE_LIST)"; \
	} > "$(FAST_BUILD_INFO)"

collect-artifacts: | $(DIST_DIR)
	$(DOCKER_RUN) bash -lc 'set -eu; \
		sysupgrade="$$(find /repo/upstream/immortalwrt-mt798x-rebase/bin/targets/$(TARGET) -type f -name "*$(PROFILE)*squashfs-sysupgrade.bin" | sort | tail -1)"; \
		initramfs="$$(find /repo/upstream/immortalwrt-mt798x-rebase/bin/targets/$(TARGET) -type f -name "*$(PROFILE)*initramfs-kernel.bin" | sort | tail -1)"; \
		manifest="$$(find /repo/upstream/immortalwrt-mt798x-rebase/bin/targets/$(TARGET) -type f -name "*$(PROFILE)*.manifest" | sort | tail -1)"; \
		test -n "$$sysupgrade" || { echo "ERROR: GL-MT3000 sysupgrade image not found"; exit 1; }; \
		test -n "$$initramfs" || { echo "ERROR: GL-MT3000 initramfs image not found"; exit 1; }; \
		test -n "$$manifest" || { echo "ERROR: GL-MT3000 manifest not found"; exit 1; }; \
		cp "$$sysupgrade" /repo/dist/mt3000-travel-router-sysupgrade.bin; \
		cp "$$initramfs" /repo/dist/mt3000-travel-router-initramfs-kernel.bin; \
		cp "$$manifest" /repo/dist/mt3000-travel-router.manifest'
	@{ \
		echo "upstream=$$(git -C "$(UPSTREAM_DIR)" rev-parse HEAD)"; \
		echo "target=$(TARGET)"; \
		echo "profile=$(PROFILE)"; \
		echo "jobs=$(JOBS)"; \
		echo "built_at_utc=$$(date -u '+%Y-%m-%dT%H:%M:%SZ')"; \
		echo "packages=$(PACKAGE_LIST)"; \
	} > "$(BUILD_INFO)"

validate-artifacts:
	@test -s "$(SYSUPGRADE_IMAGE)" || { echo "ERROR: empty sysupgrade image"; exit 1; }
	@test -s "$(INITRAMFS_IMAGE)" || { echo "ERROR: empty initramfs image"; exit 1; }
	@test -s "$(MANIFEST)" || { echo "ERROR: empty manifest"; exit 1; }
	@for package in $(REQUIRED_PACKAGES); do \
		grep -Eq "^$$package " "$(MANIFEST)" || { echo "ERROR: missing $$package in final manifest"; exit 1; }; \
	done
	@tar -tf "$(SYSUPGRADE_IMAGE)" | grep -Eq '^sysupgrade-$(PROFILE)/kernel$$'
	@tar -tf "$(SYSUPGRADE_IMAGE)" | grep -Eq '^sysupgrade-$(PROFILE)/root$$'
	@rm -rf "$(WORK_DIR)/validate-rootfs"
	@mkdir -p "$(WORK_DIR)/validate-rootfs"
	@tar -xf "$(SYSUPGRADE_IMAGE)" -C "$(WORK_DIR)/validate-rootfs" "sysupgrade-$(PROFILE)/root"
	$(DOCKER_RUN) bash -lc 'set -eu; \
		root_img=/repo/.work/validate-rootfs/sysupgrade-$(PROFILE)/root; \
		list="$$(unsquashfs -lc "$$root_img")"; \
		has_path() { printf "%s\n" "$$list" | grep -qx "squashfs-root/$$1"; }; \
		has_path usr/bin/mt798x-board-info; \
		has_path usr/bin/mt3000-factory-wifi; \
		has_path etc/uci-defaults/99-mt3000-wifi-defaults; \
		unsquashfs -cat "$$root_img" etc/uci-defaults/99-mt3000-wifi-defaults | sh -n; \
		has_path lib/functions/mt798x-board.sh; \
		has_path lib/wifi/mtwifi.uc; \
		has_path lib/wifi/mtwifi.sh; \
		has_path lib/netifd/wireless/mtwifi.sh; \
		unsquashfs -cat "$$root_img" etc/board.d/02_network | grep -q "glinet,gl-mt3000"; \
		unsquashfs -cat "$$root_img" etc/board.d/02_network | grep -q "ucidef_set_interfaces_lan_wan eth1 eth0"; \
		printf "%s\n" "$$list" | grep -Eq "squashfs-root/lib/modules/.*/mt76\\.ko"; \
		printf "%s\n" "$$list" | grep -Eq "squashfs-root/lib/modules/.*/mt76-connac-lib\\.ko"; \
		printf "%s\n" "$$list" | grep -Eq "squashfs-root/lib/modules/.*/mt7915e\\.ko"; \
		! { unsquashfs -cat "$$root_img" etc/uci-defaults/99-mt3000-wifi-defaults; \
			unsquashfs -cat "$$root_img" lib/functions/mt798x-board.sh; } | grep -q -- "-5G"'

validate-fast-artifacts:
	@test -s "$(FAST_SYSUPGRADE_IMAGE)" || { echo "ERROR: empty fast sysupgrade image"; exit 1; }
	@test -s "$(FAST_MANIFEST)" || { echo "ERROR: empty fast manifest"; exit 1; }
	@for package in $(REQUIRED_PACKAGES); do \
		grep -Eq "^$$package " "$(FAST_MANIFEST)" || { echo "ERROR: missing $$package in fast manifest"; exit 1; }; \
	done
	@tar -tf "$(FAST_SYSUPGRADE_IMAGE)" | grep -Eq '^sysupgrade-$(PROFILE)/kernel$$'
	@tar -tf "$(FAST_SYSUPGRADE_IMAGE)" | grep -Eq '^sysupgrade-$(PROFILE)/root$$'
	@rm -rf "$(WORK_DIR)/validate-fast-rootfs"
	@mkdir -p "$(WORK_DIR)/validate-fast-rootfs"
	@tar -xf "$(FAST_SYSUPGRADE_IMAGE)" -C "$(WORK_DIR)/validate-fast-rootfs" "sysupgrade-$(PROFILE)/root"
	$(DOCKER_RUN_IMAGEBUILDER_ROOT) bash -lc 'set -eu; \
		export DEBIAN_FRONTEND=noninteractive; \
		apt-get update; \
		apt-get install -y --no-install-recommends squashfs-tools; \
		root_img=/repo/.work/validate-fast-rootfs/sysupgrade-$(PROFILE)/root; \
		list="$$(unsquashfs -lc "$$root_img")"; \
		has_path() { printf "%s\n" "$$list" | grep -qx "squashfs-root/$$1"; }; \
		has_path usr/bin/mt798x-board-info; \
		has_path usr/bin/mt3000-factory-wifi; \
		has_path etc/uci-defaults/99-mt3000-wifi-defaults; \
		unsquashfs -cat "$$root_img" etc/uci-defaults/99-mt3000-wifi-defaults | sh -n; \
		has_path lib/functions/mt798x-board.sh; \
		has_path lib/wifi/mtwifi.uc; \
		has_path lib/wifi/mtwifi.sh; \
		has_path lib/netifd/wireless/mtwifi.sh; \
		unsquashfs -cat "$$root_img" etc/board.d/02_network | grep -q "glinet,gl-mt3000"; \
		unsquashfs -cat "$$root_img" etc/board.d/02_network | grep -q "ucidef_set_interfaces_lan_wan eth1 eth0"; \
		printf "%s\n" "$$list" | grep -Eq "squashfs-root/lib/modules/.*/mt76\\.ko"; \
		printf "%s\n" "$$list" | grep -Eq "squashfs-root/lib/modules/.*/mt76-connac-lib\\.ko"; \
		printf "%s\n" "$$list" | grep -Eq "squashfs-root/lib/modules/.*/mt7915e\\.ko"; \
		! { unsquashfs -cat "$$root_img" etc/uci-defaults/99-mt3000-wifi-defaults; \
			unsquashfs -cat "$$root_img" lib/functions/mt798x-board.sh; \
		} | grep -q -- "-5G"'

checksums:
	@cd "$(DIST_DIR)" && sha256sum \
		"$(notdir $(SYSUPGRADE_IMAGE))" \
		"$(notdir $(INITRAMFS_IMAGE))" \
		"$(notdir $(MANIFEST))" \
		"$(notdir $(BUILD_INFO))" > sha256sums.txt

fast-checksums:
	@cd "$(FAST_DIST_DIR)" && sha256sum \
		"$(notdir $(FAST_SYSUPGRADE_IMAGE))" \
		"$(notdir $(FAST_MANIFEST))" \
		"$(notdir $(FAST_BUILD_INFO))" > sha256sums.txt

benchmark-builds: | $(DIST_DIR)
	@{ \
		echo "started_at_utc=$$(date -u '+%Y-%m-%dT%H:%M:%SZ')"; \
		echo "imagebuilder_release=$(IMAGEBUILDER_RELEASE)"; \
		echo "source_platform=$(SOURCE_PLATFORM)"; \
		echo "imagebuilder_platform=$(IMAGEBUILDER_PLATFORM)"; \
	} > "$(BENCHMARK_INFO)"
	@echo "fast_build_cold" >> "$(BENCHMARK_INFO)"
	@/usr/bin/time -p $(MAKE) fast-build >> "$(BENCHMARK_INFO)" 2>&1
	@echo "fast_build_warm" >> "$(BENCHMARK_INFO)"
	@/usr/bin/time -p $(MAKE) fast-build >> "$(BENCHMARK_INFO)" 2>&1
	@echo "source_build_warm" >> "$(BENCHMARK_INFO)"
	@/usr/bin/time -p $(MAKE) source-build collect-artifacts validate-artifacts checksums >> "$(BENCHMARK_INFO)" 2>&1
	@{ \
		echo "finished_at_utc=$$(date -u '+%Y-%m-%dT%H:%M:%SZ')"; \
		echo "benchmark_info=$(BENCHMARK_INFO)"; \
	} >> "$(BUILD_INFO)"

clean-rootfs-overlay:
	@rm -rf "$(UPSTREAM_DIR)/files"

clean: clean-rootfs-overlay
	@rm -rf "$(WORK_DIR)/validate-rootfs" "$(WORK_DIR)/validate-fast-rootfs"

distclean: clean-rootfs-overlay
	@rm -rf "$(WORK_DIR)" "$(DIST_DIR)"

status:
	@git status --short
	@git -C "$(UPSTREAM_DIR)" status --short
