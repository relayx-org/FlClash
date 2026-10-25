{{flutter_js}}
{{flutter_build_config}}

for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) build.mainJsPath += '?v=__IPING_UI_REVISION__';
}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: '/canvaskit/'
  },
  onEntrypointLoaded: async initializer => {
    const runner = await initializer.initializeEngine();
    await runner.runApp();
    document.getElementById('loading')?.remove();
  }
});
