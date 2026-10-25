include $(TOPDIR)/rules.mk

PKG_NAME:=iping
PKG_VERSION:=0.1.0
PKG_RELEASE:=3
PKG_LICENSE:=GPL-3.0-only
PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16

GO_PKG:=github.com/relayx-org/FlClash/openwrt/iping
GO_PKG_BUILD_PKG:=$(GO_PKG)
GO_PKG_INSTALL_ALL:=1

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

define Package/iping
  SECTION:=net
  CATEGORY:=Network
  TITLE:=iPing router agent
  URL:=https://github.com/relayx-org/FlClash
  DEPENDS:=$(GO_ARCH_DEPENDS) +ca-bundle +curl +jsonfilter +unzip +flock +iping-mihomo +ip-full +nftables-json +firewall4 +kmod-tun +kmod-inet-diag +kmod-nft-tproxy +kmod-nft-socket
endef

define Package/iping/conffiles
/etc/config/iping
/etc/iping/
endef

define Build/Prepare
	test -f ./src/webui/dist/index.html || \
		{ echo 'Run bash openwrt/build_ui.sh before compiling the OpenWrt package.'; exit 1; }
	$(call Build/Prepare/Default)
	$(CP) ./src/. $(PKG_BUILD_DIR)/
endef

define Package/iping/install
	$(INSTALL_DIR) $(1)/usr/libexec/iping
	$(INSTALL_BIN) $(GO_PKG_BUILD_BIN_DIR)/iping $(1)/usr/libexec/iping/agent
	$(INSTALL_BIN) ./files/iping-update $(1)/usr/libexec/iping/update
	$(INSTALL_DIR) $(1)/usr/bin $(1)/usr/share/iping
	$(LN) ../libexec/iping/update $(1)/usr/bin/iping-update
	printf '%s\n' '$(PKG_VERSION)+$(PKG_RELEASE)' > $(1)/usr/share/iping/version
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/iping.init $(1)/etc/init.d/iping
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/iping.conf $(1)/etc/config/iping
	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	$(INSTALL_DATA) ./files/iping.upgrade $(1)/lib/upgrade/keep.d/iping
endef

define Package/iping/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
mkdir -p /var/lock
exec 9>/var/lock/iping-update.lock
flock -n 9 || exit 0
/etc/init.d/iping enable
/etc/init.d/iping restart
/usr/libexec/iping/update schedule
exit 0
endef

define Package/iping/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
[ -x /usr/libexec/iping/update ] && exit 0
if [ -f /etc/crontabs/root ]; then
	sed -i '\|# iping-auto-update$$|d' /etc/crontabs/root
	/etc/init.d/cron restart
fi
exit 0
endef

$(eval $(call GoBinPackage,iping))
$(eval $(call BuildPackage,iping))
