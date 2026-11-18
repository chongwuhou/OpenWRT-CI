#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

set -euo pipefail

# Stage third-party package sources with one explicit precedence rule.
# The optional sixth argument locks a branch/tag to an exact commit.
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=${4:-}
	local EXTRA_PACKAGES=${5:-}
	local PKG_COMMIT=${6:-}
	local PKG_LIST=("$PKG_NAME" $EXTRA_PACKAGES)
	local REPO_NAME=${PKG_REPO#*/}
	local REPO_PATH="./tmp/package-sources/$REPO_NAME"

	for NAME in "${PKG_LIST[@]}"; do
		echo "Search directory: $NAME"
		local FOUND_DIRS
		FOUND_DIRS=$(find ./feeds/base/ ./feeds/luci/ ./feeds/packages/ \
			./package/feeds/base/ ./package/feeds/luci/ ./package/feeds/packages/ \
			-maxdepth 4 \( -type d -o -type l \) -iname "*$NAME*" 2>/dev/null || true)

		if [ -n "$FOUND_DIRS" ]; then
			while IFS= read -r DIR; do
				[ -n "$DIR" ] || continue
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "No existing directory: $NAME"
		fi

		if [ "$NAME" = "sing-box" ]; then
			for DIR in \
				./package/sing-box \
				./feeds/base/sing-box \
				./feeds/base/feeds/packages/sing-box \
				./package/feeds/base/sing-box \
				./feeds/packages/net/sing-box \
				./feeds/packages/sing-box; do
				if [ -e "$DIR" ] || [ -L "$DIR" ]; then
					rm -rf "$DIR"
					echo "Delete duplicate sing-box: $DIR"
				fi
			done
		fi
	done

	mkdir -p ./tmp/package-sources
	rm -rf "$REPO_PATH"
	git clone --depth=1 --single-branch --branch "$PKG_BRANCH" \
		"https://github.com/$PKG_REPO.git" "$REPO_PATH"
	if [ -n "$PKG_COMMIT" ]; then
		ACTUAL_COMMIT=$(git -C "$REPO_PATH" rev-parse HEAD)
		if [ "$ACTUAL_COMMIT" != "$PKG_COMMIT" ]; then
			echo "source-ref-drift: $PKG_REPO@$PKG_BRANCH expected $PKG_COMMIT got $ACTUAL_COMMIT" >&2
			exit 1
		fi
	fi

	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		for NAME in "${PKG_LIST[@]}"; do
			if [ "$NAME" = "sing-box" ]; then
				[ -f "$REPO_PATH/sing-box/Makefile" ] || {
					echo "required VIKINGYFY sing-box package is missing" >&2
					exit 1
				}
				rm -rf ./package/sing-box ./feeds/base/sing-box
				cp -rf "$REPO_PATH/sing-box" ./package/sing-box
				echo "Install VIKINGYFY sing-box: ./package/sing-box"
			elif [ -f "$REPO_PATH/Makefile" ] && grep -q "define Package/$NAME" "$REPO_PATH/Makefile"; then
				rm -rf "./package/$NAME"
				cp -rf "$REPO_PATH" "./package/$NAME"
			else
				rm -rf "./package/$NAME"
				find "$REPO_PATH" -mindepth 1 -maxdepth 4 -type d \
					-iname "*$NAME*" -prune -exec cp -rf {} ./package \;
			fi
		done
		rm -rf "$REPO_PATH"
	else
		rm -rf "./package/$REPO_NAME"
		cp -rf "$REPO_PATH" "./package/$REPO_NAME"
		rm -rf "$REPO_PATH"
	fi
}

# Themes and UI components.
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12"
UPDATE_PACKAGE "aurora" "eamonxg/luci-theme-aurora" "master"
UPDATE_PACKAGE "aurora-config" "eamonxg/luci-app-aurora-config" "master"
UPDATE_PACKAGE "fluent" "LazuliKao/luci-theme-fluent" "main"
UPDATE_PACKAGE "footstrap" "VizzleTF/luci-theme-footstrap" "main"
UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "master"
UPDATE_PACKAGE "kucat-config" "sirpdboy/luci-app-kucat-config" "master"
UPDATE_PACKAGE "shadcn" "eamonxg/luci-theme-shadcn" "main"
UPDATE_PACKAGE "vantage" "anothaDev/luci-theme-vantage" "main"

# Proxy cores and front ends.
UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg" "" "9e16fae39fac577a8f4c72be35a3fd3c3faeec4d"
UPDATE_PACKAGE "luci-app-ssr-plus" "fw876/helloworld" "v198.3" "pkg" "mihomo" "81c6320d40d455e6d623b6579f460d0665e1a421"
UPDATE_PACKAGE "dns2socks-rust" "fw876/helloworld" "v198.3" "pkg" "" "81c6320d40d455e6d623b6579f460d0665e1a421"
UPDATE_PACKAGE "naiveproxy" "Openwrt-Passwall/openwrt-passwall-packages" "main" "pkg" "shadowsocksr-libev" "8147e8bf8abc62b5357f76defa37f380e35f6e0a"
UPDATE_PACKAGE "kcptun-client" "permails/kcptun-client" "main" "pkg" "" "83fcdc81f31a43d496c9b24698b0b62c6fcf5cc4"
UPDATE_PACKAGE "luci-app-passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg" "" "4cca0dc9985d176733fe50c352c4163675af01fd"
UPDATE_PACKAGE "luci-app-passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg" "" "fbe2b6beac461bfaed6fd236ba2dde1230b94918"

# iStore and service components.
UPDATE_PACKAGE "luci-app-store" "linkease/istore" "main" "pkg" "luci-lib-taskd luci-lib-xterm taskd" "a97ace34f2da358a015b094d326bba2697697f2e"
UPDATE_PACKAGE "ddnsto" "linkease/nas-packages" "master" "pkg"
UPDATE_PACKAGE "luci-app-ddnsto" "linkease/nas-packages-luci" "main" "pkg"
UPDATE_PACKAGE "luci-app-oaf" "OpenWrt-Actions/OpenAppFilter" "master" "pkg" "appfilter oaf"
UPDATE_PACKAGE "luci-app-nps" "djylb/nps-openwrt" "main" "pkg" "npc nps"

# Docker management UI; runtime packages come from the ImmortalWrt feed.
UPDATE_PACKAGE "luci-lib-docker" "lisaac/luci-lib-docker" "master" "pkg" "" "98a663449208b65e68702ad0f3ad61c536bfa40c"
UPDATE_PACKAGE "luci-app-dockerman" "lisaac/luci-app-dockerman" "master" "pkg" "" "6fd9937954e0b080bf07967182d714ea21fe7eb1"

# Storage, modem, and utility components.
UPDATE_PACKAGE "diskmanager" "4IceG/luci-app-mini-diskmanager" "main"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
UPDATE_PACKAGE "diskman" "sbwml/luci-app-diskman" "main"
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"

# HomeProxy and companion packages share one source. This supplies the
# sing-box version required by HomeProxy.
UPDATE_PACKAGE "luci-app-homeproxy" "VIKINGYFY/packages" "main" "pkg" "axonhub gecoosac miniupnpd sing-box luci-app-timewol luci-app-upnp luci-app-wolplus luci-app-wolultra" "4a0f7553e5db085a5209b5ec0747b643716d6391"

UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "netspeedtest" "sirpdboy/netspeedtest" "main" "" "homebox ookla-speedtest"
UPDATE_PACKAGE "netwizard" "sirpdboy/luci-app-netwizard" "main"
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
UPDATE_PACKAGE "timecontrol" "sirpdboy/luci-app-timecontrol" "main"

UPDATE_PACKAGE "natmapt" "muink/openwrt-natmapt" "master"
UPDATE_PACKAGE "stuntman" "muink/openwrt-stuntman" "master"
UPDATE_PACKAGE "luci-app-natmapt" "muink/luci-app-natmapt" "master"

# S20P modem and hardware utilities.
UPDATE_PACKAGE "airpi3000m-fancontrol" "LianXia233/luci-app-airpi3000m-fancontrol" "main"
UPDATE_PACKAGE "chfs" "LianXia233/luci-app-chfs" "main"
UPDATE_PACKAGE "fm350" "LianXia233/luci-app-fm350" "main"
UPDATE_PACKAGE "h5000m-netmode" "LianXia233/luci-app-h5000m-netmode" "main"
UPDATE_PACKAGE "mt5700" "LianXia233/luci-app-mt5700" "main"
UPDATE_PACKAGE "mt5700m" "LianXia233/luci-app-mt5700m" "main"
UPDATE_PACKAGE "netmonitor" "LianXia233/luci-app-netmonitor" "main"
UPDATE_PACKAGE "qmodem-generic" "LianXia233/luci-app-qmodem-generic" "main"

# Optional local extensions are deliberately kept outside the public tree.
if [ -n "${GITHUB_WORKSPACE:-}" ] && [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
	source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi
