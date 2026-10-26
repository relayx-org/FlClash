# Bundled Chinese fallback fonts

These unmodified Noto Sans SC WOFF2 subsets come from the Google Fonts URLs in
Flutter's `font_fallback_data.dart`. They use the SIL Open Font License in `OFL.txt`.
`manifest.json` records the Flutter engine revision and each file's SHA-256.

The engine selects and loads only the subsets needed for visible text. The local
Agent serves these files; Chinese rendering does not require access to Google Fonts.
Other fallback families retain the engine's Google Fonts source through a redirect.

After upgrading Flutter, refresh with:

```sh
python3 tool/ci/openwrt_fonts.py --flutter-sdk /path/to/flutter
```

The Web build verifies the engine revision and checksums before embedding the fonts.
