{{flutter_js}}
{{flutter_build_config}}

const dismissLoading = () => document.getElementById('loading')?.remove();
const loadingFailed = error => { dismissLoading(); throw error; };
window.addEventListener('flutter-first-frame', dismissLoading, {once: true});

for (const build of _flutter.buildConfig.builds) {
  for (const key of ['mainJsPath', 'mainWasmPath', 'jsSupportRuntimePath']) {
    if (build[key]) build[key] += '?v=__IPING_UI_REVISION__';
  }
}

const supportsWasm = window.ipingSupportsDartWasm();
const config = {
  canvasKitBaseUrl: '/canvaskit/__IPING_ENGINE_REVISION__/',
  assetBase: '/ui/__IPING_UI_REVISION__/',
  fontFallbackBaseUrl: '/ui/__IPING_UI_REVISION__/fallback-fonts/',
  wasmAllowList: { blink: supportsWasm, webkit: false }
};

_flutter.loader.load({
  config,
  onEntrypointLoaded: async initializer => {
    try {
      const runner = await initializer.initializeEngine(config);
      await runner.runApp();
    } catch (error) {
      loadingFailed(error);
    }
  }
}).catch(loadingFailed);
