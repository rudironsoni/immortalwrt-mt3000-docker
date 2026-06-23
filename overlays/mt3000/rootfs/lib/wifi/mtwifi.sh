#!/bin/sh
#
# Copyright (C) 2023, hanwckf <hanwckf@vip.qq.com>
#

append DRIVERS "mtwifi"

mtwifi_gl_mt3000_board() {
	case "$(cat /tmp/sysinfo/board_name 2>/dev/null)" in
		glinet,gl-mt3000|glinet,mt3000-snand) return 0 ;;
		*) return 1 ;;
	esac
}

mtwifi_gl_mt3000_mac_suffix() {
	mac=""
	for path in /sys/class/net/eth0/address /sys/class/net/eth1/address /sys/class/net/br-lan/address; do
		[ -r "$path" ] || continue
		mac="$(cat "$path" 2>/dev/null | sed -n "1p")"
		[ -n "$mac" ] && break
	done
	mac="$(printf "%s" "$mac" | tr -d ":[:space:]" | tr "[:upper:]" "[:lower:]")"
	[ ${#mac} -ge 3 ] && printf "%s\n" "${mac#${mac%???}}" && return 0
	printf "000\n"
}

mtwifi_default_ssid() {
	band="$1"
	if mtwifi_gl_mt3000_board; then
		suffix="$(mtwifi_gl_mt3000_mac_suffix)"
		case "$band" in
			2g) printf "GL-MT3000-%s\n" "$suffix" ;;
			5g) printf "GL-MT3000-%s\n" "$suffix" ;;
			6g) printf "GL-MT3000-%s-6G\n" "$suffix" ;;
		esac
		return 0
	fi
	case "$band" in
		2g) printf "ImmortalWrt-2.4G\n" ;;
		5g) printf "GL-MT3000-%s\n" "$(mtwifi_mac_suffix)" ;;
		6g) printf "ImmortalWrt-6G\n" ;;
	esac
}

mtwifi_valid_default_key() {
	local key="$1"
	local len=${#key}

	[ "$len" -ge 8 ] && [ "$len" -le 63 ]
}

mtwifi_default_key() {
	local key

	mtwifi_gl_mt3000_board || return 1

	key="$(/usr/bin/mt798x-board-info wifi-key 2>/dev/null || true)"
	if mtwifi_valid_default_key "$key"; then
		printf 'mt798x-board-info:%s\n' "$key"
		return 0
	fi


	return 1
}

detect_mtwifi() {
	local wifi_key_result wifi_key_source wifi_key

	wifi_key_result="$(mtwifi_default_key 2>/dev/null || true)"
	if [ -n "$wifi_key_result" ]; then
		wifi_key_source="${wifi_key_result%%:*}"
		wifi_key="${wifi_key_result#*:}"
		logger -t mtwifi-defaults "gl-mt3000 default wifi key_source=$wifi_key_source key_len=${#wifi_key}"
	fi

	local idx ifname
	local band htmode htbsscoex ssid dbdc_main
	# load wireless config explicitly
	config_load wireless

	if [ -d "/sys/module/mt_wifi" ]; then
		dev_list="$(l1util list)"
		for dev in $dev_list; do
			config_get type ${dev} type
			[ "$type" = "mtwifi" ] || {
				ifname="$(l1util get ${dev} main_ifname)"

				idx="$(l1util get ${dev} subidx)"
				[ $idx -eq 1 ] && dbdc_main="1" || dbdc_main="0"

				band="$(l1util get ${dev} band)"
				if [ -z "$band" ] || [ "$band" = "nil" ]; then
					[ $idx -eq 1 ] && band="2g" || band="5g"
				fi

				if [ "$band" = "2g" ]; then
					htmode="HE40"
					htbsscoex="1"
					ssid="$(mtwifi_default_ssid 2g)"
				elif [ "$band" = "5g" ]; then
					htmode="HE160"
					htbsscoex="0"
					ssid="$(mtwifi_default_ssid 5g)"
				elif [ "$band" = "6g" ]; then
					htmode="HE160"
					htbsscoex="0"
					ssid="$(mtwifi_default_ssid 6g)"
				fi

				uci -q batch <<-EOF
					set wireless.${dev}=wifi-device
					set wireless.${dev}.type=mtwifi
					set wireless.${dev}.phy=${ifname}
					set wireless.${dev}.band=${band}
					set wireless.${dev}.dbdc_main=${dbdc_main}
					set wireless.${dev}.channel=auto
					set wireless.${dev}.txpower=100
					set wireless.${dev}.htmode=${htmode}
					set wireless.${dev}.country=CN
					set wireless.${dev}.mu_beamformer=1
					set wireless.${dev}.noscan=${htbsscoex}
					set wireless.${dev}.serialize=1

					set wireless.default_${dev}=wifi-iface
					set wireless.default_${dev}.device=${dev}
					set wireless.default_${dev}.network=lan
					set wireless.default_${dev}.mode=ap
					set wireless.default_${dev}.ssid=${ssid}
					if [ -n "$wifi_key" ]; then
						set wireless.default_${dev}.encryption=psk2
						set wireless.default_${dev}.key="$wifi_key"
					else
						set wireless.default_${dev}.encryption=none
					fi
EOF
				uci -q commit wireless
			}
		done
	fi
}
