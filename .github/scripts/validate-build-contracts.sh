#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

set -euo pipefail

fail() {
	echo "build-contract-failed: $*" >&2
	exit 1
}

selected() {
	grep -Eq "^CONFIG_PACKAGE_${1}=(y|m)$" .config
}

if grep -Eq '^CONFIG_PACKAGE_iptables-nft=(y|m)$' .config \
	&& grep -Eq '^CONFIG_PACKAGE_iptables-zz-legacy=(y|m)$' .config; then
	fail "iptables-nft and iptables-zz-legacy are mutually exclusive"
fi

SING_BOX_MAKE=./package/sing-box/Makefile
HOME_PROXY_MAKE=./package/luci-app-homeproxy/Makefile

if selected sing-box || selected luci-app-homeproxy; then
	[ -f "$SING_BOX_MAKE" ] || fail "sing-box source missing: $SING_BOX_MAKE"
	[ -f "$HOME_PROXY_MAKE" ] || fail "HomeProxy source missing: $HOME_PROXY_MAKE"

	grep -q 'CONFIG_SING_BOX_BUILD_NAIVE_OUTBOUND' "$SING_BOX_MAKE" \
		|| fail "sing-box Naive outbound config is missing"
	grep -q '+SING_BOX_BUILD_NAIVE_OUTBOUND:libcronet' "$SING_BOX_MAKE" \
		|| fail "sing-box libcronet dependency is missing"
	grep -q 'with_naive_outbound' "$SING_BOX_MAKE" \
		|| fail "sing-box Naive outbound build tag is missing"
	grep -q 'TARGET_LDFLAGS.*-lcronet' "$SING_BOX_MAKE" \
		|| fail "sing-box libcronet linker flag is missing"
	grep -q 'GO_PKG_LDFLAGS.*-checklinkname=0' "$SING_BOX_MAKE" \
		|| fail "sing-box Go linker compatibility flag is missing"

	HOME_PROXY_MIN=$(sed -n 's/^LUCI_EXTRA_DEPENDS:=sing-box (>=\([^)]*\)).*/\1/p' "$HOME_PROXY_MAKE")
	[ "$HOME_PROXY_MIN" = "1.15.0_alpha10" ] \
		|| fail "unexpected HomeProxy sing-box minimum: ${HOME_PROXY_MIN:-missing}"

	[ -s tmp/.packageinfo ] || fail "OpenWrt package metadata is missing: tmp/.packageinfo"
	SING_BOX_VERSION=$(awk '
		$0 == "Package: sing-box" { found=1; next }
		found && /^Package:/ { exit }
		found && /^Version:/ { print $2; exit }
	' tmp/.packageinfo)
	[ -n "$SING_BOX_VERSION" ] || fail "sing-box version is missing from tmp/.packageinfo"

	# Compare the APK version after converting the prerelease separator to Debian syntax.
	COMPARE_VERSION=${SING_BOX_VERSION//_alpha/~alpha}
	COMPARE_VERSION=${COMPARE_VERSION//_beta/~beta}
	COMPARE_VERSION=${COMPARE_VERSION//_rc/~rc}
	command -v dpkg >/dev/null 2>&1 || fail "dpkg version comparator is unavailable"
	dpkg --compare-versions "$COMPARE_VERSION" ge '1.15.0~alpha10' \
		|| fail "sing-box $SING_BOX_VERSION is below HomeProxy minimum 1.15.0_alpha10"
fi

echo "build dependency contracts: passed"
