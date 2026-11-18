# OpenWRT-CI

[IPQ技术讨论群](https://qm.qq.com/q/v7nMhzB4oU)

## 相关项目

本地编译工具：[OWRT-Tools](https://github.com/VIKINGYFY/OWRT-Tools)

配套插件：[packages](https://github.com/VIKINGYFY/packages)

上游源码：[ImmortalWrt](https://github.com/immortalwrt/immortalwrt)

定制源码：[VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt)

## U-Boot

高通版（沉心）：[uboot-qsdk12.5-build](https://github.com/chenxin527/uboot-qsdk12.5-build)

高通版（小猪）：[u-boot-2016](https://github.com/1980490718/u-boot-2016)

联发科（新版）：[UBOOT-CI Releases](https://github.com/VIKINGYFY/UBOOT-CI/releases)

联发科（官方）：[wrt.moe](https://drive.wrt.moe/uboot/mediatek)

## 固件说明

平台工作流按矩阵管理；S20P 使用 `S20P` 工作流手动触发，避免诊断和修复提交自动消耗 runner。

S20P 同时锁定源码和关键第三方软件包提交号；上游发生漂移时会在下载阶段直接停止。

固件信息中的时间为编译开始时间，可用于核对上游源码提交。

当前配置覆盖 MediaTek、Qualcomm、Rockchip 和 x86 系列。

## 目录

`.github/workflows`：GitHub Actions 工作流

`Scripts`：包源和源码调整脚本

`Config`：平台与软件包配置

## Star History

<a href="https://www.star-history.com/?repos=vikingyfy%2Fopenwrt-ci&type=date&legend=top-left">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=vikingyfy/openwrt-ci&type=date&theme=dark&legend=top-left" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=vikingyfy/openwrt-ci&type=date&legend=top-left" />
    <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=vikingyfy/openwrt-ci&type=date&legend=top-left" />
  </picture>
</a>
