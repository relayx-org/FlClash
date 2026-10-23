cask "flclash" do
  version "VERSION"

  on_macos do
    arch arm: "arm64", intel: "amd64"

    sha256 arm:   "ARM_SHA256",
           intel: "AMD_SHA256"

    url "https://github.com/long2ice/FlClash/releases/download/v#{version}/iPing-#{version}-macos-#{arch}.dmg"
  end

  name "iPing"
  desc "Multi-platform proxy client based on ClashMeta"
  homepage "https://github.com/long2ice/FlClash"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on :macos

  app "iPing.app"

  postflight_steps do
    run "/usr/bin/xattr",
        args:           ["-rd", "com.apple.quarantine", "{{appdir}}/iPing.app"],
        writable_paths: ["iPing.app"],
        writable_base:  :appdir
  end

  uninstall quit: "my.iping.client"

  zap trash: [
    "~/Library/Application Support/my.iping.client",
    "~/Library/Caches/my.iping.client",
    "~/Library/Preferences/my.iping.client.plist",
    "~/Library/Saved Application State/my.iping.client.savedState",
  ]
end
