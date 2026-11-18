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

# netspeedtest：当前 ImmortalWrt Python feed 已移除 python3-pkg-resources，且插件源码未使用 pkg_resources。
NETSPEED_MAKE="$PACKAGE_PATH/netspeedtest/luci-app-netspeedtest/Makefile"
if [ -f "$NETSPEED_MAKE" ] && grep -q 'python3-pkg-resources' "$NETSPEED_MAKE"; then
	FIX "netspeedtest-stale-python-dep" "$PACKAGE_PATH/netspeedtest/luci-app-netspeedtest" sed -i 		's/[[:space:]]*+python3-pkg-resources//g' 		"$NETSPEED_MAKE"
fi


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


# luci-lib-docker 仍使用 v0.3.4；ImmortalWrt 当前 APK 打包器拒绝带 v 前缀的版本号。
# 只改打包版本字段，不改 LuCI 代码或运行时 API。
DOCKER_LIB_MAKE="$PACKAGE_PATH/luci-lib-docker/Makefile"
if [ -f "$DOCKER_LIB_MAKE" ] && grep -q '^PKG_VERSION:=v' "$DOCKER_LIB_MAKE"; then
	FIX "luci-lib-docker-apk-version" "$PACKAGE_PATH/luci-lib-docker" sed -i \
		's/^PKG_VERSION:=v/PKG_VERSION:=/' \
		"$DOCKER_LIB_MAKE"
fi


# luci-app-dockerman 也沿用 v0.5.26；APK 版本字段必须使用无 v 前缀的规范版本。
DOCKERMAN_MAKE="$PACKAGE_PATH/luci-app-dockerman/Makefile"
if [ -f "$DOCKERMAN_MAKE" ] && grep -q '^PKG_VERSION:=v' "$DOCKERMAN_MAKE"; then
	FIX "luci-app-dockerman-apk-version" "$PACKAGE_PATH/luci-app-dockerman" sed -i \
		's/^PKG_VERSION:=v/PKG_VERSION:=/' \
		"$DOCKERMAN_MAKE"
fi
# OpenClash：OpenWrt Makefile 中的 shell 变量必须写成 $CORE_ARCH。
# 单个 $CORE_ARCH 会被 GNU make 当作 $C + ORE_ARCH，最终生成错误的 clash-ORE_ARCH.tar.gz。
OPENCLASH_MAKE="$PACKAGE_PATH/luci-app-openclash/Makefile"
if [ -f "$OPENCLASH_MAKE" ] && grep -Eq '([^$]|^)\$CORE_ARCH' "$OPENCLASH_MAKE"; then
	FIX "openclash-core-arch-make-escape" "$PACKAGE_PATH/luci-app-openclash" sed -E -i 		's/([^$])\$CORE_ARCH/\1\$\$CORE_ARCH/g' 		"$OPENCLASH_MAKE"
fi

# nps-openwrt 当前 main 将预编译包版本占位为 null；这会生成无效下载/打包元数据。
# 固定到官方最新发布，并同步 S20P aarch64 的 client/server 校验值。
NPS_VERSION="0.35.3"
NPS_CLIENT_ARM64_HASH="e6577403c90926f280224969863fc952c50d01608168acbb40332f0d5c3a4e51"
NPS_SERVER_ARM64_HASH="2a4f161eb8c768d597361d8a75a355ab67e0ce541bbb958bd21704df4176ceeb"
PATCH_NPS_MAKEFILE() {
	local MAKEFILE=$1
	local ARM64_HASH=$2
	sed -i "s/^PKG_VERSION:=null$/PKG_VERSION:=$NPS_VERSION/" "$MAKEFILE"
	sed -i -E "s/^([[:space:]]*arm64=)[0-9a-f]+/\\1$ARM64_HASH/" "$MAKEFILE"
}
if [ -f "$PACKAGE_PATH/npc/Makefile" ] && grep -q "^PKG_VERSION:=null$" "$PACKAGE_PATH/npc/Makefile"; then
	FIX "npc-release-metadata" "$PACKAGE_PATH/npc" PATCH_NPS_MAKEFILE "$PACKAGE_PATH/npc/Makefile" "$NPS_CLIENT_ARM64_HASH"
fi
if [ -f "$PACKAGE_PATH/nps/Makefile" ] && grep -q "^PKG_VERSION:=null$" "$PACKAGE_PATH/nps/Makefile"; then
	FIX "nps-release-metadata" "$PACKAGE_PATH/nps" PATCH_NPS_MAKEFILE "$PACKAGE_PATH/nps/Makefile" "$NPS_SERVER_ARM64_HASH"
fi

# mihomo：fw876/helloworld 的 UPX 调用仍指向旧的 host/bin；ImmortalWrt 的 upx/host 安装在 hostpkg/bin。
# 这是构建系统路径兼容修正，不改 mihomo 源码和功能；在 S20P 阶段强制断言，避免再次编译数十分钟后才暴露。
MIHOMO_MAKE="$PACKAGE_PATH/mihomo/Makefile"
if [ -f "$MIHOMO_MAKE" ] && grep -qF '$(STAGING_DIR_HOST)/bin/upx' "$MIHOMO_MAKE"; then
	FIX "mihomo-upx-hostpkg-path" "$PACKAGE_PATH/mihomo" sed -i 		's|\$(STAGING_DIR_HOST)/bin/upx|\$(STAGING_DIR_HOSTPKG)/bin/upx|g' 		"$MIHOMO_MAKE"
fi


# Docker + fw4：避免 dockerd 每次开机都重复 uciadd/reload_config，触发重复的 docker_devices 定义。
DOCKER_INIT="$FEEDS_PATH/packages/utils/dockerd/files/dockerd.init"
if [ -f "$DOCKER_INIT" ] && grep -q $'^\tuciadd$' "$DOCKER_INIT"; then
	FIX "dockerd-fw4-boot" "$FEEDS_PATH/packages/utils/dockerd" sed -i \
		'/^boot() {/,/^}/ s/^[[:space:]]*uciadd$/	if ! uci_quiet get network.docker || ! uci_quiet get firewall.docker; then\n		uciadd\n	fi/' \
		"$DOCKER_INIT"
fi

# S20P 的关键修补必须在 Custom Packages 阶段失败即止，不能把错误拖到数小时后的 APK 打包阶段。
if [[ "${WRT_CONFIG:-}" == S20P* ]]; then
	for MAKEFILE in "$DOCKER_LIB_MAKE" "$DOCKERMAN_MAKE"; do
		if [ ! -f "$MAKEFILE" ]; then
			echo "required S20P Docker Makefile missing: $MAKEFILE"
			exit 1
		fi
		if grep -q '^PKG_VERSION:=v' "$MAKEFILE"; then
			echo "S20P Docker APK version normalization assertion failed: $MAKEFILE"
			exit 1
		fi
	done
	if [ ! -f "$MIHOMO_MAKE" ]; then
		echo "required S20P mihomo Makefile missing: $MIHOMO_MAKE"
		exit 1
	fi
	if grep -qF '$(STAGING_DIR_HOST)/bin/upx' "$MIHOMO_MAKE"; then
		echo "S20P mihomo UPX path assertion failed: still references STAGING_DIR_HOST"
		exit 1
	fi
	if ! grep -qF '$(STAGING_DIR_HOSTPKG)/bin/upx' "$MIHOMO_MAKE"; then
		echo "S20P mihomo UPX path assertion failed: missing STAGING_DIR_HOSTPKG"
		exit 1
	fi
	if [ ! -f "$OPENCLASH_MAKE" ]; then
		echo "required S20P OpenClash Makefile missing: $OPENCLASH_MAKE"
		exit 1
	fi
	if ! grep -Eq '\$\$CORE_ARCH' "$OPENCLASH_MAKE" 		|| ! grep -Eq 'clash-\$\$CORE_ARCH\.tar\.gz' "$OPENCLASH_MAKE"; then
		echo "S20P OpenClash core architecture expansion assertion failed: expected \\$CORE_ARCH in $OPENCLASH_MAKE"
		exit 1
	fi
fi

