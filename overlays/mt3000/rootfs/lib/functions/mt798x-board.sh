#!/bin/sh

# OpenWrt-style board helpers for GL.iNet MT798x devices.  Keep this file
# dependency-light: it is used by first-boot defaults and preflight evidence.

MT798X_FALLBACK_SSID_2G="${MT798X_FALLBACK_SSID_2G:-${MT3000_FALLBACK_SSID_2G:-OpenWrt-MT3000-2G}}"
MT798X_FALLBACK_SSID_5G="${MT798X_FALLBACK_SSID_5G:-${MT3000_FALLBACK_SSID_5G:-OpenWrt-MT3000-5G}}"
MT798X_FALLBACK_KEY="${MT798X_FALLBACK_KEY:-${MT3000_FALLBACK_KEY:-OpenWrt24!}}"
MT798X_FALLBACK_COUNTRY="${MT798X_FALLBACK_COUNTRY:-${MT3000_FALLBACK_COUNTRY:-US}}"

mt798x_upper() {
	tr 'abcdefghijklmnopqrstuvwxyz' 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
}

mt798x_lower() {
	tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz'
}

mt798x_alnum_only() {
	tr -cd 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
}

mt798x_trim_field() {
	tr '\000' '\n' | sed -n '1p' | tr -cd '[:print:]' | sed 's/[[:space:]]*$//'
}

mt798x_read_first() {
	[ -r "$1" ] || return 1
	sed -n '1p' "$1" 2>/dev/null
}

mt798x_env_value() {
	local name="$1"
	local override env_name

	env_name="$(printf '%s' "$name" | mt798x_upper)"
	eval "override=\${MT798X_${env_name}:-}"
	[ -n "$override" ] || eval "override=\${MT3000_${env_name}:-}"
	[ -n "$override" ] && {
		printf '%s\n' "$override"
		return 0
	}

	[ -r "/var/run/uboot-env/$name" ] && {
		mt798x_read_first "/var/run/uboot-env/$name"
		return 0
	}

	if command -v fw_printenv >/dev/null 2>&1; then
		fw_printenv -n "$name" 2>/dev/null && return 0
		fw_printenv "$name" 2>/dev/null | sed -n "s/^$name=//p" | sed -n '1p'
	fi
}

mt798x_valid_ssid() {
	local ssid="$1"
	local len="${#ssid}"

	[ "$len" -ge 1 ] && [ "$len" -le 32 ] || return 1
	case "$ssid" in
		*[![:print:]]*) return 1 ;;
		00000000000000000000000000000000|ffffffffffffffffffffffffffffffff|FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) return 1 ;;
	esac
}

mt798x_valid_wifi_key() {
	local key="$1"
	local len="${#key}"

	[ "$len" -ge 8 ] && [ "$len" -le 63 ] || return 1
	case "$key" in
		*[![:print:]]*) return 1 ;;
	esac
}

mt798x_valid_factory_key() {
	local key="$1"

	[ "${#key}" -eq 10 ] || return 1
	case "$key" in
		*[!A-Za-z0-9]*) return 1 ;;
	esac
}

mt798x_board_name() {
	local board

	board="$(mt798x_read_first /tmp/sysinfo/board_name 2>/dev/null || true)"
	[ -n "$board" ] && { printf '%s\n' "$board"; return 0; }

	board="$(tr '\000' '\n' < /proc/device-tree/compatible 2>/dev/null | sed -n '1p' || true)"
	[ -n "$board" ] && printf '%s\n' "$board"
}

mt798x_factory_dev() {
	[ -n "${MT798X_FACTORY_DEV:-}" ] && {
		printf '%s\n' "$MT798X_FACTORY_DEV"
		return 0
	}
	[ -n "${MT3000_FACTORY_DEV:-}" ] && {
		printf '%s\n' "$MT3000_FACTORY_DEV"
		return 0
	}

	awk -F: '
		/"Factory"|factory|Factory|"ART"|art|ART/ {
			print "/dev/" $1
			exit
		}
	' /proc/mtd 2>/dev/null
}

mt798x_factory_field() {
	local offset="$1"
	local count="$2"
	local dev

	dev="$(mt798x_factory_dev)"
	[ -n "$dev" ] && [ -r "$dev" ] || return 1
	dd if="$dev" bs=1 skip="$offset" count="$count" 2>/dev/null | mt798x_trim_field
}

mt798x_factory_key_field() {
	local offset="$1"
	local count="$2"
	local dev

	dev="$(mt798x_factory_dev)"
	[ -n "$dev" ] && [ -r "$dev" ] || return 1
	dd if="$dev" bs=1 skip="$offset" count="$count" 2>/dev/null | mt798x_alnum_only
}

mt798x_factory_hex() {
	local offset="$1"
	local count="$2"
	local dev

	dev="$(mt798x_factory_dev)"
	[ -n "$dev" ] && [ -r "$dev" ] || return 1
	dd if="$dev" bs=1 skip="$offset" count="$count" 2>/dev/null | hexdump -v -e '1/1 "%02x"'
}

mt798x_mac_from_hex() {
	local mac="$1"

	case "$mac" in
		[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])
			printf '%s:%s:%s:%s:%s:%s\n' \
				"$(printf '%s' "$mac" | cut -c1-2)" \
				"$(printf '%s' "$mac" | cut -c3-4)" \
				"$(printf '%s' "$mac" | cut -c5-6)" \
				"$(printf '%s' "$mac" | cut -c7-8)" \
				"$(printf '%s' "$mac" | cut -c9-10)" \
				"$(printf '%s' "$mac" | cut -c11-12)" | mt798x_lower
			return 0
			;;
	esac

	return 1
}

mt798x_valid_mac() {
	local mac="$1"

	case "$mac" in
		[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f])
			[ "$mac" != "00:00:00:00:00:00" ] || return 1
			return 0
			;;
	esac

	return 1
}

mt798x_label_mac() {
	local mac path

	[ -n "${MT798X_LABEL_MAC:-}" ] && {
		printf '%s\n' "$MT798X_LABEL_MAC"
		return 0
	}
	[ -n "${MT3000_LABEL_MAC:-}" ] && {
		printf '%s\n' "$MT3000_LABEL_MAC"
		return 0
	}

	mac="$(mt798x_read_first /proc/gl-hw-info/device_mac 2>/dev/null || true)"
	[ -n "$mac" ] && { printf '%s\n' "$mac" | mt798x_lower; return 0; }

	for path in \
		/sys/class/net/eth0/address \
		/sys/class/net/wlan1/address \
		/sys/class/net/eth1/address \
		/sys/class/net/br-lan/address \
		/sys/class/net/wlan0/address \
		/sys/class/net/lan/address \
		/sys/class/net/wan/address; do
		[ -r "$path" ] || continue
		mac="$(cat "$path" 2>/dev/null | sed -n '1p' | mt798x_lower)"
		mt798x_valid_mac "$mac" || continue
		printf '%s\n' "$mac"
		return 0
	done

	mac="$(mt798x_factory_hex $((0xa)) 6 2>/dev/null || true)"
	mac="$(mt798x_mac_from_hex "$mac" 2>/dev/null || true)"
	if mt798x_valid_mac "$mac"; then
		printf '%s\n' "$mac"
		return 0
	fi

	if [ -r /lib/functions/system.sh ]; then
		. /lib/functions/system.sh
		if command -v get_mac_label >/dev/null 2>&1; then
			mac="$(get_mac_label 2>/dev/null || true)"
			[ -n "$mac" ] && { printf '%s\n' "$mac" | mt798x_lower; return 0; }
		fi
	fi

	return 1
}

mt798x_model_code() {
	local model

	model="${MT798X_MODEL:-${MT3000_MODEL:-}}"
	[ -n "$model" ] || model="$(mt798x_read_first /proc/gl-hw-info/model 2>/dev/null || true)"
	[ -n "$model" ] || model="$(mt798x_read_first /tmp/sysinfo/model 2>/dev/null || true)"
	[ -n "$model" ] || model="$(mt798x_read_first /tmp/sysinfo/board_name 2>/dev/null || true)"
	[ -n "$model" ] || model="MT3000"

	model="$(printf '%s\n' "$model" | mt798x_upper)"
	case "$model" in
		*MT3000*|3000) printf 'MT3000\n' ;;
		*)
			printf '%s\n' "$model" | sed 's/^GL[.-]*INET[[:space:]-]*//; s/^GL-//; s/[^A-Z0-9-]//g'
			;;
	esac
}

mt798x_prefers_derived_ssids() {
	local model board

	model="$(mt798x_model_code 2>/dev/null || true)"
	case "$model" in
		MT3000) return 0 ;;
	esac

	board="$(mt798x_board_name 2>/dev/null || true)"
	case "$board" in
		glinet,gl-mt3000|glinet,mt3000-snand) return 0 ;;
	esac

	return 1
}

mt798x_mac_suffix() {
	local mac compact

	mac="$(mt798x_label_mac | sed -n '1p')"
	compact="$(printf '%s' "$mac" | tr -d ':-' | mt798x_lower)"
	[ "${#compact}" -ge 3 ] || return 1
	printf '%s\n' "$compact" | sed 's/.*\(...\)$/\1/'
}

mt798x_derived_ssid() {
	local band="$1"
	local model suffix ssid

	model="$(mt798x_model_code)"
	suffix="$(mt798x_mac_suffix 2>/dev/null || true)"
	[ -n "$suffix" ] || suffix="$(cat /proc/sys/kernel/random/uuid 2>/dev/null | cut -c1-3 | mt798x_lower)"
	[ -n "$suffix" ] || suffix="mt3000"

	ssid="GL-$model-$suffix"
	[ "$band" = "5g" ] && ssid="$ssid-5G"
	printf '%s\n' "$ssid"
}

mt798x_ssid_2g() {
	local ssid

	ssid="$(mt798x_env_value owrt_ssid_2g 2>/dev/null || true)"
	mt798x_valid_ssid "$ssid" && { printf '%s\n' "$ssid"; return 0; }

	ssid="$(mt798x_env_value owrt_ssid 2>/dev/null || true)"
	mt798x_valid_ssid "$ssid" && { printf '%s\n' "$ssid"; return 0; }

	if mt798x_prefers_derived_ssids; then
		mt798x_derived_ssid 2g
		return 0
	fi

	ssid="$(mt798x_factory_field $((0xe0)) 32 2>/dev/null || true)"
	mt798x_valid_ssid "$ssid" && { printf '%s\n' "$ssid"; return 0; }

	mt798x_derived_ssid 2g
}

mt798x_ssid_5g() {
	local ssid base_ssid

	ssid="$(mt798x_env_value owrt_ssid_5g 2>/dev/null || true)"
	mt798x_valid_ssid "$ssid" && { printf '%s\n' "$ssid"; return 0; }

	base_ssid="$(mt798x_env_value owrt_ssid 2>/dev/null || true)"
	if mt798x_valid_ssid "$base_ssid"; then
		case "$base_ssid" in
			*-5G|*-5g) ssid="$base_ssid" ;;
			*) ssid="$base_ssid-5G" ;;
		esac
		mt798x_valid_ssid "$ssid" && { printf '%s\n' "$ssid"; return 0; }
	fi

	if mt798x_prefers_derived_ssids; then
		mt798x_derived_ssid 5g
		return 0
	fi

	ssid="$(mt798x_factory_field $((0x100)) 32 2>/dev/null || true)"
	mt798x_valid_ssid "$ssid" && { printf '%s\n' "$ssid"; return 0; }

	mt798x_derived_ssid 5g
}

mt798x_wifi_key() {
	local key

	key="$(mt798x_env_value owrt_wifi_key 2>/dev/null || true)"
	mt798x_valid_wifi_key "$key" && { printf '%s\n' "$key"; return 0; }

	key="$(mt798x_factory_key_field $((0x40)) 10 2>/dev/null || true)"
	mt798x_valid_factory_key "$key" && { printf '%s\n' "$key"; return 0; }

	key="$(mt798x_factory_field $((0x120)) 32 2>/dev/null || true)"
	mt798x_valid_wifi_key "$key" && { printf '%s\n' "$key"; return 0; }

	printf '%s\n' "$MT798X_FALLBACK_KEY"
}

mt798x_country_code() {
	local country

	country="$(mt798x_env_value owrt_country 2>/dev/null || true)"
	[ "${#country}" -eq 2 ] && { printf '%s\n' "$country" | mt798x_upper; return 0; }

	country="$(mt798x_read_first /proc/gl-hw-info/country_code 2>/dev/null || true)"
	[ "${#country}" -eq 2 ] && { printf '%s\n' "$country" | mt798x_upper; return 0; }

	printf '%s\n' "$MT798X_FALLBACK_COUNTRY"
}

mt798x_wifi_key_source() {
	local key

	key="$(mt798x_env_value owrt_wifi_key 2>/dev/null || true)"
	mt798x_valid_wifi_key "$key" && { echo "uboot-env"; return 0; }

	key="$(mt798x_factory_key_field $((0x40)) 10 2>/dev/null || true)"
	mt798x_valid_factory_key "$key" && { echo "factory-0x40"; return 0; }

	key="$(mt798x_factory_field $((0x120)) 32 2>/dev/null || true)"
	mt798x_valid_wifi_key "$key" && { echo "factory-0x120"; return 0; }

	echo "fallback"
}

mt798x_wan_port() {
	local value board

	value="$(mt798x_read_first /proc/gl-hw-info/wan 2>/dev/null || true)"
	[ -n "$value" ] && { printf '%s\n' "$value"; return 0; }

	board="$(mt798x_board_name)"
	case "$board" in
		glinet,gl-mt3000|glinet,mt3000-snand) printf 'eth0\n'; return 0 ;;
	esac

	uci -q get network.wan.device 2>/dev/null || uci -q get network.wan.ifname 2>/dev/null || true
}

mt798x_lan_port() {
	local value board

	value="$(mt798x_read_first /proc/gl-hw-info/lan 2>/dev/null || true)"
	[ -n "$value" ] && { printf '%s\n' "$value"; return 0; }

	board="$(mt798x_board_name)"
	case "$board" in
		glinet,gl-mt3000|glinet,mt3000-snand) printf 'eth1\n'; return 0 ;;
	esac

	uci -q get network.lan.device 2>/dev/null || uci -q get network.lan.ifname 2>/dev/null || true
}

mt798x_usb_ports() {
	local value board

	value="$(mt798x_read_first /proc/gl-hw-info/usb-port 2>/dev/null || true)"
	[ -n "$value" ] && { printf '%s\n' "$value"; return 0; }

	board="$(mt798x_board_name)"
	case "$board" in
		glinet,gl-mt3000|glinet,mt3000-snand) printf '1-1,2-1\n'; return 0 ;;
	esac
}

mt798x_radio_ids() {
	local value board phy

	value="$(mt798x_read_first /proc/gl-hw-info/radio 2>/dev/null || true)"
	[ -n "$value" ] && { printf '%s\n' "$value"; return 0; }

	board="$(mt798x_board_name)"
	case "$board" in
		glinet,gl-mt3000|glinet,mt3000-snand) printf 'radio0 radio1\n'; return 0 ;;
	esac

	for phy in /sys/class/ieee80211/*; do
		[ -e "$phy" ] || continue
		printf '%s ' "${phy##*/}"
	done | sed 's/[[:space:]]*$//'
	echo
}

mt798x_temperature_path() {
	local value path

	value="$(mt798x_read_first /proc/gl-hw-info/temperature 2>/dev/null || true)"
	[ -n "$value" ] && { printf '%s\n' "$value"; return 0; }

	for path in /sys/devices/virtual/thermal/thermal_zone*/temp; do
		[ -r "$path" ] || continue
		printf '%s\n' "$path"
		return 0
	done
}

mt798x_fan_present() {
	local value path name board

	value="$(mt798x_read_first /proc/gl-hw-info/fan 2>/dev/null || true)"
	[ -n "$value" ] && { echo 1; return 0; }

	board="$(mt798x_board_name)"
	case "$board" in
		glinet,gl-mt3000|glinet,mt3000-snand) echo 1; return 0 ;;
	esac

	for path in /sys/class/hwmon/*/name; do
		[ -r "$path" ] || continue
		name="$(mt798x_read_first "$path" 2>/dev/null || true)"
		case "$name" in
			*fan*|*pwm*) echo 1; return 0 ;;
		esac
	done

	echo 0
}

mt798x_flash_size() {
	local value

	value="$(mt798x_read_first /proc/gl-hw-info/flash_size 2>/dev/null || true)"
	[ -n "$value" ] && { printf '%s\n' "$value"; return 0; }

	awk 'NR > 1 { total += ("0x" $2) + 0 } END { if (total > 0) printf "%.0f MiB\n", total / 1048576 }' /proc/mtd 2>/dev/null
}

mt798x_reset_button() {
	local value

	value="$(mt798x_read_first /proc/gl-hw-info/reset-button 2>/dev/null || true)"
	[ -n "$value" ] && { printf '%s\n' "$value"; return 0; }

	[ -d /proc/device-tree/gpio-keys/reset ] && { echo "present"; return 0; }
	echo "unknown"
}

mt798x_switch_button() {
	local value

	value="$(mt798x_read_first /proc/gl-hw-info/switch-button 2>/dev/null || true)"
	[ -n "$value" ] && { printf '%s\n' "$value"; return 0; }

	[ -d /proc/device-tree/gpio-keys/mode ] && { echo "present"; return 0; }
	echo "unknown"
}

mt798x_private_value() {
	local name="$1"

	case "$name" in
		sn) mt798x_read_first /proc/gl-hw-info/device_sn 2>/dev/null || true ;;
		sn_bak) mt798x_read_first /proc/gl-hw-info/device_sn_bak 2>/dev/null || true ;;
		ddns) mt798x_read_first /proc/gl-hw-info/device_ddns 2>/dev/null || true ;;
	esac
}

mt798x_redacted_private_line() {
	local name="$1"
	local value len sha

	value="$(mt798x_private_value "$name")"
	len="${#value}"
	if [ "$len" -eq 0 ]; then
		printf '%s_present=0\n' "$name"
		return 0
	fi

	sha="$(printf '%s' "$value" | sha256sum 2>/dev/null | awk '{ print $1 }')"
	printf '%s_present=1\n' "$name"
	printf '%s_len=%s\n' "$name" "$len"
	[ -n "$sha" ] && printf '%s_sha256=%s\n' "$name" "$sha"
}
