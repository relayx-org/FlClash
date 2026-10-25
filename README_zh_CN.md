# iPing 客户端

基于 [FlClash](https://github.com/chen08209/FlClash) 和 Mihomo，支持 Android、macOS、Windows、Linux。通过浏览器使用 iping 的邮箱、Google 或通行密钥登录，回到客户端后自动加载订阅。默认使用简体中文。保留原 GPL-3.0 许可证和组件开源声明。

另有实验性 [iOS 版本](ios/README.md)，用于签名后的真机开发与内测。

[OpenWrt 版本](openwrt/README.md) 使用独立 Agent、内嵌 Flutter Web 界面和专用 Mihomo 内核，与客户端共享界面和后端接口，不依赖 LuCI 或 Nikki 插件。

## 开发与构建

使用 Flutter 3.47.6、Go 1.27 和项目固定的 Rust 版本。构建命令与环境变量见 [README](README.md)。在使用浏览器登录前，需要部署 iping 网站新增的 `/client-login` 页面。客户端只保存订阅凭证，无需 Stack Auth SDK、项目配置或令牌刷新接口。

本机界面调试使用 `flutter run --dart-define=SAFE_MODE=true`。真实代理连接在受控设备上验证。客户端不保存密码，登录令牌使用系统安全存储，退出后清理账号订阅。
