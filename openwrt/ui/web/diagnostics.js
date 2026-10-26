'use strict';

(() => {
  window.ipingDiagnosticsEnabled = new URLSearchParams(location.search).get('diagnostics') === '1';
  if (!window.ipingDiagnosticsEnabled) return;
  window.ipingDiagnosticRenderer = new URLSearchParams(location.search).get('renderer') === 'wasm' ? 'wasm' : 'default';
  const nativeDensity = devicePixelRatio;
  const version = new URL(document.currentScript.src).searchParams.get('v');
  const started = performance.now();
  let previousTime = started;
  let timerResolution = Infinity;
  for (let sample = 0; sample < 5000; sample++) {
    const time = performance.now();
    if (time > previousTime) timerResolution = Math.min(timerResolution, time - previousTime);
    previousTime = time;
  }
  const contexts = new Map();
  const graphics = new Map();
  const restore = [];
  const frames = { browser: [], build: [], raster: [], total: [], interacting: [] };
  const errors = [];
  let active = true;
  let last;
  let interaction = -Infinity;
  let inputs = 0;
  let posts = 0;
  let request;
  let interval;
  let timeout;
  const limit = (values, value) => {
    if (values.length < 2400 && Number.isFinite(value) && value >= 0) values.push(value);
  };
  const record = (build, raster, total) => {
    if (!active) return;
    limit(frames.build, build);
    limit(frames.raster, raster);
    limit(frames.total, total);
  };
  window.ipingRecordFrame = record;
  const measure = (context, name) => {
    const call = context[name];
    if (typeof call !== 'function') return;
    context[name] = function(...values) {
      const begin = performance.now();
      try { return call.apply(this, values); }
      finally {
        const duration = performance.now() - begin;
        const value = graphics.get(name) ?? {count: 0, total: 0, max: 0};
        value.count++; value.total += duration; value.max = Math.max(value.max, duration);
        graphics.set(name, value);
      }
    };
    restore.push(() => { context[name] = call; });
  };
  if (window.ImageBitmapRenderingContext) measure(ImageBitmapRenderingContext.prototype, 'transferFromImageBitmap');
  if (window.OffscreenCanvas) measure(OffscreenCanvas.prototype, 'transferToImageBitmap');
  for (const type of [window.HTMLCanvasElement, window.OffscreenCanvas]) {
    if (!type) continue;
    const original = type.prototype.getContext;
    type.prototype.getContext = function(kind, ...args) {
      const context = original.call(this, kind, ...args);
      if (context && !contexts.has(this) && contexts.size < 8) {
        contexts.set(this, { kind, context });
        for (const name of ['readPixels', 'drawElements', 'drawArrays', 'texImage2D', 'texSubImage2D', 'compileShader', 'linkProgram', 'getProgramParameter', 'getShaderParameter', 'getError', 'flush', 'finish']) {
          measure(context, name);
        }
      }
      return context;
    };
    restore.push(() => { type.prototype.getContext = original; });
  }
  const onInput = () => { interaction = performance.now(); inputs++; };
  const onError = event => {
    if (errors.length < 8) errors.push(String(event.message || 'unhandled_rejection').replace(/https?:\/\/\S+/g, '[url]').slice(0, 200));
  };
  for (const name of ['pointerdown', 'pointermove', 'scroll']) addEventListener(name, onInput, {capture: true, passive: true});
  addEventListener('error', onError);
  addEventListener('unhandledrejection', onError);
  const tick = time => {
    if (document.visibilityState === 'visible' && last !== undefined) {
      const duration = time - last;
      limit(frames.browser, duration);
      if (time - interaction < 700) limit(frames.interacting, duration);
    }
    last = document.visibilityState === 'visible' ? time : undefined;
    if (active) request = requestAnimationFrame(tick);
  };
  const summarize = values => {
    values.sort((a, b) => a - b);
    return {count: values.length, p50: values[Math.floor(values.length * .5)] ?? 0,
      p95: values[Math.floor(values.length * .95)] ?? 0, max: values.at(-1) ?? 0,
      over32: values.filter(value => value > 32).length};
  };
  const canvasInfo = () => [...contexts].map(([canvas, {kind, context}]) => {
    const result = {kind, width: canvas.width, height: canvas.height,
      attached: canvas.isConnected ?? null,
      position: canvas instanceof HTMLCanvasElement ? getComputedStyle(canvas).position : null};
    if (kind.startsWith('webgl') || kind === 'experimental-webgl') {
      try {
        result.lost = context.isContextLost();
        if (!result.lost) {
          const debug = context.getExtension('WEBGL_debug_renderer_info');
          result.gpu = String(context.getParameter(debug?.UNMASKED_RENDERER_WEBGL ?? context.RENDERER)).slice(0, 200);
        }
      } catch (_) { result.unavailable = true; }
    }
    return result;
  });
  const post = phase => {
    let preferences = {};
    try { preferences = JSON.parse(window.ipingReadPreferences?.() ?? '{}'); } catch (_) {}
    const report = {version, phase, elapsed: performance.now() - started,
      rendererRequested: window.ipingDiagnosticRenderer,
      wasmSupported: window.ipingSupportsDartWasm?.() ?? false,
      environment: {secureContext: window.isSecureContext === true, crossOriginIsolated: window.crossOriginIsolated === true,
        sharedArrayBuffer: typeof SharedArrayBuffer !== 'undefined',
        scheme: location.protocol, protocol: performance.getEntriesByType('navigation')[0]?.nextHopProtocol ?? '',
        timerResolution: Number.isFinite(timerResolution) ? timerResolution : 0},
      density: devicePixelRatio, nativeDensity, viewport: [innerWidth, innerHeight], inputs,
      effects: {glass: preferences.glass ?? 'none', animation: preferences.animation ?? 'slide', floatingBar: preferences.floatingBar !== false},
      graphics: Object.fromEntries(graphics),
      frames: Object.fromEntries(Object.entries(frames).map(([key, values]) => [key, summarize(values)])),
      canvases: canvasInfo(), errors: [...errors],
      assets: performance.getEntriesByType('resource').filter(entry => /\/(main\.dart\.(js|wasm|mjs)|canvaskit[^?]*\.wasm)(\?|$)/.test(entry.name))
        .map(entry => ({name: new URL(entry.name).pathname.split('/').at(-1), duration: entry.duration,
          protocol: entry.nextHopProtocol ?? '', transferred: entry.transferSize ?? 0}))};
    for (const values of Object.values(frames)) values.length = 0;
    graphics.clear();
    posts++;
    return fetch('/api/web_diagnostics', {method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({report}), credentials: 'same-origin', keepalive: true}).then(response => response.ok).catch(() => false);
  };
  const stop = () => {
    if (!active) return;
    active = false;
    post('complete');
    cancelAnimationFrame(request);
    clearInterval(interval);
    clearTimeout(timeout);
    for (const undo of restore) undo();
    restore.length = 0;
    for (const name of ['pointerdown', 'pointermove', 'scroll']) removeEventListener(name, onInput, true);
    removeEventListener('error', onError);
    removeEventListener('unhandledrejection', onError);
    removeEventListener('pagehide', stop);
    contexts.clear();
    window.ipingRecordFrame = () => {};
    window.ipingDiagnosticsEnabled = false;
  };
  addEventListener('pagehide', stop);
  request = requestAnimationFrame(tick);
  interval = setInterval(() => { if (posts < 6) post('sample'); }, 10000);
  timeout = setTimeout(stop, 60000);
})();
