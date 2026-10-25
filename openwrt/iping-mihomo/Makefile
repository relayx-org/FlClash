include $(TOPDIR)/rules.mk

PKG_NAME:=iping-mihomo
PKG_VERSION:=1.19.32
PKG_RELEASE:=1
PKG_SOURCE:=mihomo-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/MetaCubeX/mihomo/tar.gz/refs/tags/v$(PKG_VERSION)?
PKG_HASH:=ab130b7fab3893d01aa44c0d39be34a26da716c1d36832fbac9fa054a1d862a0
PKG_BUILD_DIR:=$(BUILD_DIR)/mihomo-$(PKG_VERSION)
PKG_LICENSE:=GPL-3.0-only
PKG_LICENSE_FILES:=LICENSE
PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16

GO_PKG:=github.com/metacubex/mihomo
GO_PKG_BUILD_PKG:=$(GO_PKG)
GO_PKG_TAGS:=with_gvisor
GO_PKG_LDFLAGS_X:=$(GO_PKG)/constant.Version=v$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

define Package/iping-mihomo
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Mihomo core for iPing
  URL:=https://github.com/MetaCubeX/mihomo
  DEPENDS:=$(GO_ARCH_DEPENDS) +ca-bundle
endef

define Package/iping-mihomo/install
	$(INSTALL_DIR) $(1)/usr/libexec/iping
	$(INSTALL_BIN) $(GO_PKG_BUILD_BIN_DIR)/mihomo $(1)/usr/libexec/iping/mihomo
endef

$(eval $(call GoBinPackage,iping-mihomo))
$(eval $(call BuildPackage,iping-mihomo))
