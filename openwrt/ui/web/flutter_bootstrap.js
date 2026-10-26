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
const diagnosticWasm = supportsWasm && window.ipingDiagnosticsEnabled === true &&
  window.ipingDiagnosticRenderer === 'wasm';
const isAppleMobile = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
  (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
const config = {
  canvasKitBaseUrl: '/canvaskit/__IPING_ENGINE_REVISION__/',
  canvasKitForceMultiSurfaceRasterizer: isAppleMobile,
  assetBase: '/ui/__IPING_UI_REVISION__/',
  fontFallbackBaseUrl: '/ui/__IPING_UI_REVISION__/fallback-fonts/',
  wasmAllowList: { blink: supportsWasm && (!isAppleMobile || diagnosticWasm), webkit: diagnosticWasm }
};

_flutter.loader.load({
  config,
  onEntrypointLoaded: async initializer => {
    try {
      const runner = await initializer.initializeEngine(config);
      await runner.runApp();
      if (isAppleMobile) {
        for (const pane of document.querySelectorAll('flt-glass-pane')) {
          const layout = document.createElement('style');
          // Flutter #188337: WebKit scrolls a lone canvas without overlay positioning.
          layout.textContent = 'flt-scene-host > flt-scene:only-child > flt-canvas-container:only-child > canvas:only-child { position: static !important; }';
          pane.shadowRoot?.append(layout);
        }
      }
    } catch (error) {
      loadingFailed(error);
    }
  }
}).catch(loadingFailed);
