#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

FEEDS_PATH="./feeds"
PACKAGE_PATH="./package"

#修补命令统一入口：FIX <名称> <守卫目录> <命令...>
#守卫目录不存在时直接跳过，保证在 bash -e 下不中断
FIX() {
	local NAME=$1
	local GUARD=$2
	shift 2

	[ -d "$GUARD" ] || return 0

	echo " "
	if "$@"; then
		echo "$NAME has been fixed!"
	else
		echo "$NAME fix failed; continuing!"
	fi
}

#修改argon主题字体和颜色
FIX "theme-argon" "$PACKAGE_PATH/luci-theme-argon" sed -i \
	"s/primary '.*'/primary '#31a1a1'/g; s/'0.2'/'0.5'/g; s/'none'/'bing'/g; s/'600'/'normal'/g" \
	"$PACKAGE_PATH/luci-theme-argon/luci-app-argon-config/root/etc/config/argon"

#修改aurora菜单式样
FIX "theme-aurora" "$PACKAGE_PATH/luci-app-aurora-config" find \
	"$PACKAGE_PATH/luci-app-aurora-config/root/usr/share/aurora/" -type f -name '*.template' -exec sed -i \
	"s/nav_type '.*'/nav_type 'dropdown'/g; s/struct_radius_base '.*'/struct_radius_base '0.125rem'/g" {} +

#修改vantage进度条标签字体（anothaDev/luci-theme-vantage#52）
FIX "theme-vantage" "$PACKAGE_PATH/luci-theme-vantage" sed -i \
	-e '/^\/\* progress bars: thin track/,$ { /^\.cbi-progressbar::before {/,/^}/ { s/^[[:space:]]*font: 500 var(--fs-micro)\/1\.2 var(--mono);/\tfont: inherit; line-height: normal;/; } }' \
	"$PACKAGE_PATH/luci-theme-vantage/luci-theme-vantage/htdocs/luci-static/vantage/vantage.css"

#修改mini-diskmanager菜单位置
FIX "mini-diskmanager" "$PACKAGE_PATH/luci-app-mini-diskmanager" sed -i "s/services/system/g" \
	"$PACKAGE_PATH/luci-app-mini-diskmanager/luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json"

#修改natmapt菜单位置
FIX "natmapt" "$PACKAGE_PATH/luci-app-natmapt" sed -i "s/network/services/g" \
	"$PACKAGE_PATH/luci-app-natmapt/root/usr/share/luci/menu.d/luci-app-natmap.json"

# sing-box 完整版补齐 Naive outbound：VIKINGYFY 配套包默认未启用该构建标签。
# 使用 ImmortalWrt 的系统 libcronet，避免依赖内置平台库；PassWall 才会显示 sing-box/Naive 协议。
SING_BOX_DIR="$PACKAGE_PATH/sing-box"
SING_BOX_MAKE="$SING_BOX_DIR/Makefile"
if [ ! -f "$SING_BOX_MAKE" ] && [ -f "$FEEDS_PATH/base/sing-box/Makefile" ]; then
	SING_BOX_DIR="$FEEDS_PATH/base/sing-box"
	SING_BOX_MAKE="$SING_BOX_DIR/Makefile"
fi
if [ -f "$SING_BOX_MAKE" ] && grep -q '^  GO_PKG_TAGS:=http2legacy,' "$SING_BOX_MAKE" && ! grep -q 'with_naive_outbound' "$SING_BOX_MAKE"; then
	FIX "sing-box-naive-dep" "$SING_BOX_DIR" sed -i \
		's|^  DEPENDS+= +kmod-netlink-diag +kmod-tun$|  DEPENDS+= +kmod-netlink-diag +kmod-tun +libcronet|' \
		"$SING_BOX_MAKE"
	FIX "sing-box-checklinkname" "$SING_BOX_DIR" sed -i \
		'/^GO_PKG_LDFLAGS_X:=/i GO_PKG_LDFLAGS:=-checklinkname=0' \
		"$SING_BOX_MAKE"
	FIX "sing-box-naive-tag" "$SING_BOX_DIR" sed -i \
		's|^  GO_PKG_TAGS:=http2legacy,with_acme,with_clash_api,with_dhcp,with_gvisor,with_quic,with_tailscale,with_utls,with_wireguard$|  GO_PKG_TAGS:=http2legacy,with_acme,with_clash_api,with_dhcp,with_gvisor,with_naive_outbound,with_quic,with_tailscale,with_utls,with_wireguard|' \
		"$SING_BOX_MAKE"
	if ! grep -q 'TARGET_LDFLAGS += -lcronet' "$SING_BOX_MAKE"; then
		# 以完整三行条件块插入，避免 sed 多次插入导致孤立 endif 使 Makefile 无法注册包。
		FIX "sing-box-naive-link" "$SING_BOX_DIR" sed -i '/^define Package\/sing-box\/conffiles/i\
ifneq ($(findstring with_naive_outbound,$(GO_PKG_TAGS)),)\
  TARGET_LDFLAGS += -lcronet\
endif' "$SING_BOX_MAKE"
	fi
	mkdir -p "$SING_BOX_DIR/patches"
	if [ ! -f "$SING_BOX_DIR/patches/100-use-system-libcronet.patch" ]; then
		printf '%s\n' \
			'--- a/protocol/naive/outbound.go' \
			'+++ b/protocol/naive/outbound.go' \
			'@@ -9,7 +9,6 @@ import (' \
			$'\t"github.com/sagernet/cronet-go"' \
			$'-\t_ "github.com/sagernet/cronet-go/all"' \
			$'\t"github.com/sagernet/sing-box/adapter"' \
			> "$SING_BOX_DIR/patches/100-use-system-libcronet.patch"
	fi
fi
# OpenAppFilter：Linux 6.18 将 del_timer_sync() 更名为 timer_delete_sync()。
# 同时补入 timer.h，并递归处理实际复制后的源码路径。
while IFS= read -r OAF_SRC; do
	if grep -q 'del_timer_sync' "$OAF_SRC"; then
		if ! grep -q '^#include <linux/timer.h>$' "$OAF_SRC"; then
			FIX "oaf-kernel-6.18-timer-header" "$(dirname "$OAF_SRC")" sed -i \
				'1i #include <linux/timer.h>' \
				"$OAF_SRC"
		fi
		FIX "oaf-kernel-6.18-timer-api" "$(dirname "$OAF_SRC")" sed -i \
			's/del_timer_sync(&oaf_timer);/timer_delete_sync(\&oaf_timer);/' \
			"$OAF_SRC"
	fi
done < <(find "$PACKAGE_PATH" -type f -name 'app_filter.c' 2>/dev/null)

# v2ray-geodata：Download 宏在多个子包并行 Prepare 时仍可能重复触发网络下载。
# Download Packages 阶段已完成强校验预取，这里只消费本地缓存，避免编译阶段再次访问 GitHub。
GEO_MAKE="$FEEDS_PATH/packages/net/v2ray-geodata/Makefile"
if [ -f "$GEO_MAKE" ] && grep -q '\$(call Download,geoip)' "$GEO_MAKE"; then
	PATCH_GEODATA() {
		awk '
			index($0, "$(call Download,geoip)") { print sprintf("%c",9) "@test -s $(DL_DIR)/$(GEOIP_FILE) || { echo v2ray-geoip-prefetch-missing; exit 1; }"; next }
			index($0, "$(call Download,geosite)") { print sprintf("%c",9) "@test -s $(DL_DIR)/$(GEOSITE_FILE) || { echo v2ray-geosite-prefetch-missing; exit 1; }"; next }
			index($0, "$(call Download,geosite-ir)") { print sprintf("%c",9) "@test -s $(DL_DIR)/$(GEOSITE_IRAN_FILE) || { echo v2ray-geosite-ir-prefetch-missing; exit 1; }"; next }
			{ print }
		' "$GEO_MAKE" > "$GEO_MAKE.tmp" && mv "$GEO_MAKE.tmp" "$GEO_MAKE"
	}
	FIX "v2ray-geodata-prefetch-only" "$FEEDS_PATH/packages/net/v2ray-geodata" PATCH_GEODATA
fi

# Docker + fw4：避免 dockerd 每次开机都重复 uciadd/reload_config，触发重复的 docker_devices 定义。
DOCKER_INIT="$FEEDS_PATH/packages/utils/dockerd/files/dockerd.init"
if [ -f "$DOCKER_INIT" ] && grep -q $'^\tuciadd$' "$DOCKER_INIT"; then
	FIX "dockerd-fw4-boot" "$FEEDS_PATH/packages/utils/dockerd" sed -i \
		'/^boot() {/,/^}/ s/^[[:space:]]*uciadd$/	if ! uci_quiet get network.docker || ! uci_quiet get firewall.docker; then\n		uciadd\n	fi/' \
		"$DOCKER_INIT"
fi
