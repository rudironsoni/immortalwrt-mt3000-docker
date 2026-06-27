#!/bin/sh

MT798X_FALLBACK_COUNTRY="${MT798X_FALLBACK_COUNTRY:-${MT3000_FALLBACK_COUNTRY:-US}}"

mt798x_lower() {
	tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz'
}

mt798x_upper() {
	tr 'abcdefghijklmnopqrstuvwxyz' 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
}

mt798x_alnum_only() {
	tr -cd 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
}

mt798x_board_name() {
	local board

	board="$(cat /tmp/sysinfo/board_name 2>/dev/null || true)"
	[ -n "$board" ] && {
		printf '%s\n' "$board"
		return 0
	}

	tr '\000' '\n' < /proc/device-tree/compatible 2>/dev/null | sed -n '1p'
}

mt798x_factory_dev() {
	local mtd

	[ -n "${MT798X_FACTORY_DEV:-}" ] && {
		printf '%s\n' "$MT798X_FACTORY_DEV"
		return 0
	}

	mtd="$(awk -F: '/"Factory"/ { print $1; exit }' /proc/mtd 2>/dev/null || true)"
	[ -n "$mtd" ] || return 1

	if [ -e "/dev/mtdblock${mtd#mtd}" ]; then
		printf '/dev/mtdblock%s\n' "${mtd#mtd}"
	else
		printf '/dev/%s\n' "$mtd"
	fi
}

mt798x_factory_read() {
	local offset="$1"
	local count="$2"
	local dev

	dev="$(mt798x_factory_dev)" || return 1
	[ -r "$dev" ] || return 1
	dd if="$dev" bs=1 skip="$offset" count="$count" 2>/dev/null
}

mt798x_factory_ascii() {
	mt798x_factory_read "$1" "$2" | tr '\000' '\n' | sed -n '1p' | tr -cd '[:print:]' | sed 's/[[:space:]]*$//'
}

mt798x_factory_key_field() {
	mt798x_factory_read "$1" "$2" | mt798x_alnum_only
}

mt798x_factory_hex() {
	mt798x_factory_read "$1" "$2" | hexdump -v -e '1/1 "%02x"'
}

mt798x_mac_from_hex() {
	local mac="$1"

	case "$mac" in
	????????????)
		printf '%s:%s:%s:%s:%s:%s\n' \
			"$(printf '%s' "$mac" | cut -c1-2)" \
			"$(printf '%s' "$mac" | cut -c3-4)" \
			"$(printf '%s' "$mac" | cut -c5-6)" \
			"$(printf '%s' "$mac" | cut -c7-8)" \
			"$(printf '%s' "$mac" | cut -c9-10)" \
			"$(printf '%s' "$mac" | cut -c11-12)" | mt798x_lower
		;;
	*)
		return 1
		;;
	esac
}

mt798x_valid_mac() {
	case "$1" in
	[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f])
		return 0
		;;
	esac

	return 1
}

mt798x_label_mac() {
	local mac path

	[ -n "${MT798X_LABEL_MAC:-}" ] && {
		printf '%s\n' "$MT798X_LABEL_MAC" | mt798x_lower
		return 0
	}

	for path in \
		/proc/gl-hw-info/device_mac \
		/sys/class/net/eth0/address \
		/sys/class/net/eth1/address \
		/sys/class/net/br-lan/address \
		/sys/class/net/wan/address \
		/sys/class/net/lan/address
	do
		mac="$(cat "$path" 2>/dev/null | sed -n '1p' | mt798x_lower)"
		mt798x_valid_mac "$mac" || continue
		printf '%s\n' "$mac"
		return 0
	done

	mac="$(mt798x_factory_hex $((0xa)) 6 2>/dev/null || true)"
	mac="$(mt798x_mac_from_hex "$mac" 2>/dev/null || true)"
	mt798x_valid_mac "$mac" || return 1
	printf '%s\n' "$mac"
}

mt798x_model_code() {
	printf 'MT3000\n'
}

mt798x_ssid_suffix() {
	local mac

	mac="$(mt798x_label_mac 2>/dev/null | tr -d ':' | mt798x_lower)"
	[ ${#mac} -ge 3 ] || return 1
	printf '%s\n' "${mac#?????????}"
}

mt798x_ssid_2g() {
	local suffix

	[ -n "${MT798X_WIFI_SSID:-}" ] && {
		printf '%s\n' "$MT798X_WIFI_SSID"
		return 0
	}

	suffix="$(mt798x_ssid_suffix 2>/dev/null || true)"
	if [ -n "$suffix" ]; then
		printf 'GL-MT3000-%s\n' "$suffix"
	else
		printf 'GL-MT3000\n'
	fi
}

mt798x_ssid_5g() {
	mt798x_ssid_2g
}

mt798x_valid_wifi_key() {
	case "$1" in
	''|*[!A-Za-z0-9]*)
		return 1
		;;
	esac

	[ ${#1} -ge 8 ] && [ ${#1} -le 63 ]
}

mt798x_wifi_key() {
	local key

	[ -n "${MT798X_WIFI_KEY:-}" ] && {
		mt798x_valid_wifi_key "$MT798X_WIFI_KEY" || return 1
		printf '%s\n' "$MT798X_WIFI_KEY"
		return 0
	}

	key="$(mt798x_factory_key_field $((0x40)) 10 2>/dev/null || true)"
	if mt798x_valid_wifi_key "$key"; then
		printf '%s\n' "$key"
		return 0
	fi

	key="$(mt798x_factory_key_field $((0x120)) 32 2>/dev/null || true)"
	if mt798x_valid_wifi_key "$key"; then
		printf '%s\n' "$key"
		return 0
	fi

	return 1
}

mt798x_wifi_key_source() {
	local key

	if [ -n "${MT798X_WIFI_KEY:-}" ] && mt798x_valid_wifi_key "$MT798X_WIFI_KEY"; then
		printf 'env\n'
		return 0
	fi

	key="$(mt798x_factory_key_field $((0x40)) 10 2>/dev/null || true)"
	if mt798x_valid_wifi_key "$key"; then
		printf 'factory-0x40\n'
		return 0
	fi

	key="$(mt798x_factory_key_field $((0x120)) 32 2>/dev/null || true)"
	if mt798x_valid_wifi_key "$key"; then
		printf 'factory-0x120\n'
		return 0
	fi

	printf 'none\n'
}

mt798x_country_code() {
	local country

	country="${MT798X_WIFI_COUNTRY:-$MT798X_FALLBACK_COUNTRY}"
	printf '%s\n' "$country" | mt798x_upper | cut -c1-2
}

mt798x_redacted_private_line() {
	local name="$1"
	local value=""

	case "$name" in
	sn) value="$(mt798x_factory_ascii $((0x20)) 32 2>/dev/null || true)" ;;
	sn_bak) value="$(mt798x_factory_ascii $((0xa0)) 32 2>/dev/null || true)" ;;
	ddns) value="$(mt798x_factory_ascii $((0x60)) 32 2>/dev/null || true)" ;;
	esac

	if [ -n "$value" ]; then
		printf '%s_present=yes len=%s\n' "$name" "$(printf '%s' "$value" | wc -c | tr -d ' ')"
	else
		printf '%s_present=no len=0\n' "$name"
	fi
}
