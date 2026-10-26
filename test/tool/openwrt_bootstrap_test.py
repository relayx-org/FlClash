import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / 'openwrt/ui/web'


class OpenWrtBootstrapTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which('node'), 'Node.js is required for bridge tests')
    def test_isolated_login_accepts_broadcast_without_treating_a_severed_popup_as_cancellation(self):
        script = r'''
const fs=require('fs'), vm=require('vm'), assert=require('assert');
const source=fs.readFileSync(process.argv[1]+'/bridge.js','utf8');
(async()=>{
 for(const isolated of [false,true]){
  const calls=[], timers=new Map(), intervals=new Map();let next=0, channel, closed=0;
  const state='s'.repeat(43), code='c'.repeat(43);
  const popup={closed:true,location:{replace:()=>{}},close:()=>{closed++;if(isolated)throw new Error('severed');}};
  const sandbox={URL,AbortController,location:{origin:'https://router'},crossOriginIsolated:isolated,
   localStorage:{getItem:()=>null},addEventListener:()=>{},open:()=>popup,
   setTimeout:fn=>{timers.set(++next,fn);return next;},clearTimeout:id=>timers.delete(id),
   setInterval:fn=>{intervals.set(++next,fn);return next;},clearInterval:id=>intervals.delete(id),
   BroadcastChannel:class{constructor(){channel=this;}close(){}},
   fetch:async(path,options)=>{
    const method=path.split('/').at(-1),args=JSON.parse(options.body);calls.push(method);
    if(method==='begin_login')assert.strictEqual(args.redirect_uri,'https://router/iping-login.html');
    if(method==='complete_login')assert.deepStrictEqual(args,{code,state});
    return{ok:true,json:async()=>({ok:true,data:method==='begin_login'?{state,url:'https://account/client-login'}:null})};
   }
  };
  sandbox.window=sandbox;vm.createContext(sandbox);vm.runInContext(source,sandbox);
  const pending=sandbox.ipingSignIn(false);
  await new Promise(setImmediate);
  if(isolated){
   assert.strictEqual(intervals.size,0);
   await channel.onmessage({data:{type:'iping-login',state:'x'.repeat(43),code}});
   assert.deepStrictEqual(calls,['begin_login']);
   await channel.onmessage({data:{type:'iping-login',state,code}});
   assert.strictEqual(await pending,null);
   assert.deepStrictEqual(calls,['begin_login','complete_login','sync']);
  }else{
   assert.strictEqual(intervals.size,1);
   [...intervals.values()][0]();
   assert.strictEqual(await pending,null);
   assert.deepStrictEqual(calls,['begin_login','cancel_login']);
  }
  assert.strictEqual(closed,1);
  await new Promise(setImmediate);
  assert.strictEqual(timers.size,0);assert.strictEqual(intervals.size,0);
 }
})().catch(error=>{console.error(error);process.exit(1);});
'''
        subprocess.run(['node', '-e', script, str(WEB)], check=True)

    @unittest.skipUnless(shutil.which('node'), 'Node.js is required for diagnostics tests')
    def test_optional_diagnostics_collect_timings_and_release_all_hooks(self):
        script = r'''
const fs = require('fs'), vm = require('vm'), assert = require('assert');
const source = fs.readFileSync(process.argv[1] + '/diagnostics.js', 'utf8');
for (const [enabled, density] of [[false, 1], [true, 0], [true, 1]]) {
 let now = 0, animation, interval, timeout, posts = [], cancelled = false, broken = false;
 const listeners = new Map();
 const draw = () => {now+=4;return 7;};
 class Canvas {
  constructor() { this.width=1320; this.height=2580; this.isConnected=true; }
  getContext() { return {drawElements:draw, RENDERER:1, getExtension:()=> {if(broken)throw new Error('disposed');return null;}, getParameter:()=> 'Test GPU', isContextLost:()=>false}; }
 }
 class Offscreen extends Canvas { transferToImageBitmap() {now+=3;return 'bitmap';} }
 const offscreenOriginal = Offscreen.prototype.transferToImageBitmap;
 class Bitmap { transferFromImageBitmap() {now+=2;return 'frame';} }
 const bitmapOriginal = Bitmap.prototype.transferFromImageBitmap;
 const original = Canvas.prototype.getContext;
 const sandbox = {
  URL, URLSearchParams, HTMLCanvasElement:Canvas, OffscreenCanvas:Offscreen, ImageBitmapRenderingContext:Bitmap, devicePixelRatio:3, innerWidth:440, innerHeight:860,
  isSecureContext:false, crossOriginIsolated:false, SharedArrayBuffer:undefined,
  location:{search:(enabled?'?diagnostics=1':'?diagnostics=0')+'&density='+density+'&renderer=wasm&shadows='+(density===1?'0':'1')},
  document:{currentScript:{src:'http://router/diagnostics.js?v=revision'},visibilityState:'visible'},
  performance:{now:()=>now,getEntriesByType:()=>[{name:'http://router/main.dart.js?v=private-query',duration:5}]},
  getComputedStyle:()=>({position:'static'}),
  requestAnimationFrame:callback=> {animation=callback;return 1;},
  cancelAnimationFrame:()=> {cancelled=true;},
  setInterval:(callback,ms)=> {assert.strictEqual(ms,10000);interval=callback;return 2;},
  clearInterval:id=> {assert.strictEqual(id,2);interval=null;},
  setTimeout:(callback,ms)=> {assert.strictEqual(ms,60000);timeout=callback;return 3;},
  clearTimeout:id=> {assert.strictEqual(id,3);timeout=null;},
  addEventListener:(name,callback)=>listeners.set(name,callback),
  removeEventListener:(name,callback)=> {assert.strictEqual(listeners.get(name),callback);listeners.delete(name);},
  fetch:(path,options)=> {assert.strictEqual(path,'/api/web_diagnostics');posts.push(JSON.parse(options.body).report);return Promise.reject(new Error('offline'));},
 };
 sandbox.window=sandbox;
 vm.createContext(sandbox);
 vm.runInContext(source,sandbox);
 assert.strictEqual(sandbox.ipingDiagnosticsEnabled,enabled);
 if (!enabled) {
  assert.strictEqual(Canvas.prototype.getContext,original);
  assert.strictEqual(Bitmap.prototype.transferFromImageBitmap,bitmapOriginal);
  assert.strictEqual(Offscreen.prototype.transferToImageBitmap,offscreenOriginal);
  assert.strictEqual(sandbox.devicePixelRatio,3);
  assert.strictEqual(animation,undefined);
  assert.strictEqual(listeners.size,0);
  continue;
 }
 const gl = new Canvas().getContext('webgl2');
 assert.strictEqual(gl.drawElements(),7);
 assert.strictEqual(new Bitmap().transferFromImageBitmap(),'frame');
 assert.strictEqual(new Offscreen().transferToImageBitmap(),'bitmap');
 now=0;
 sandbox.ipingRecordFrame(2,3,5);
 animation(0);now=20;animation(20);
 listeners.get('pointermove')();now=80;animation(80);
 interval();
 const report=posts[0];
 assert.strictEqual(report.version,'revision');
 assert.strictEqual(report.density,3);
 assert.strictEqual(report.nativeDensity,3);
 assert.strictEqual(report.graphics.drawElements.count,1);
 assert.strictEqual(report.graphics.drawElements.total,4);
 assert.strictEqual(report.graphics.transferFromImageBitmap.total,2);
 assert.strictEqual(report.graphics.transferToImageBitmap.total,3);
 assert.strictEqual(report.environment.secureContext,false);
 assert.strictEqual(report.environment.crossOriginIsolated,false);
 assert.strictEqual(report.environment.sharedArrayBuffer,false);
 assert.strictEqual(report.rendererRequested,'wasm');
 assert.strictEqual(report.effects.glass,'none');
 assert.strictEqual(report.frames.browser.count,2);
 assert.strictEqual(report.frames.browser.p95,60);
 assert.strictEqual(report.frames.interacting.count,1);
 assert.strictEqual(report.frames.build.p50,2);
 assert.strictEqual(report.frames.raster.p50,3);
 assert.strictEqual(report.frames.total.p50,5);
 assert.strictEqual(report.canvases[0].gpu,'Test GPU');
 assert.strictEqual(report.canvases[0].position,'static');
 assert.strictEqual(report.assets[0].name,'main.dart.js');
 assert(!JSON.stringify(report).includes('private-query'));
 for(let n=0;n<2500;n++) {now+=17;animation(now);}
 broken=true;
 timeout();
 assert.strictEqual(posts[1].frames.browser.count,2400);
 assert.strictEqual(posts[1].phase,'complete');
 assert.strictEqual(posts[1].canvases[0].unavailable,true);
 assert.strictEqual(Canvas.prototype.getContext,original);
 assert.strictEqual(sandbox.ipingDiagnosticsEnabled,false);
 assert.strictEqual(gl.drawElements,draw);
 assert.strictEqual(Bitmap.prototype.transferFromImageBitmap,bitmapOriginal);
 assert.strictEqual(Offscreen.prototype.transferToImageBitmap,offscreenOriginal);
 assert.strictEqual(listeners.size,0);
 assert.strictEqual(cancelled,true);
 assert.strictEqual(interval,null);
 assert.strictEqual(timeout,null);
 sandbox.ipingRecordFrame(9,9,9);
 assert.strictEqual(posts.length,2);
}
'''
        subprocess.run(['node', '-e', script, str(WEB)], check=True)

    @unittest.skipUnless(shutil.which('node'), 'Node.js is required for bootstrap tests')
    def test_engine_receives_configuration_and_keeps_apple_mobile_on_canvaskit(self):
        script = r'''
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const root = process.argv[1];
const support = fs.readFileSync(root + '/wasm_support.js', 'utf8');
const bootstrap = fs.readFileSync(root + '/flutter_bootstrap.js', 'utf8').replace(/\{\{[^}]+\}\}/g, '');
(async () => {
 for (const capability of ['all', 'none', 'no_strings', 'no_exceptions']) {
  const supported = capability === 'all';
  for (const diagnostic of [{enabled:false,renderer:'default'}, {enabled:false,renderer:'wasm'}, {enabled:true,renderer:'default'}, {enabled:true,renderer:'wasm'}]) {
  for (const device of [
   {userAgent:'Chrome',platform:'MacIntel',maxTouchPoints:0,appleMobile:false},
   {userAgent:'iPhone CriOS/156',platform:'iPhone',maxTouchPoints:5,appleMobile:true},
   {userAgent:'Macintosh Safari',platform:'MacIntel',maxTouchPoints:5,appleMobile:true},
   {userAgent:'Android Chrome',platform:'Linux',maxTouchPoints:5,appleMobile:false},
  ]) {
  let received;
  let configuration;
  let started = false;
  let firstFrame;
  const styles = [];
  const context = {
   window: {ipingDiagnosticsEnabled:diagnostic.enabled,ipingDiagnosticRenderer:diagnostic.renderer,
    addEventListener: (name, callback, options) => {
     assert.strictEqual(name, 'flutter-first-frame');
     assert.strictEqual(options.once, true);
     firstFrame = callback;
    }}, Uint8Array, navigator: device,
   WebAssembly: { validate: (bytes, options) => {
    if (capability === 'none') return false;
    if (capability === 'no_strings') return true;
    if (capability === 'no_exceptions' && bytes.includes(31)) return false;
    return !options;
   } },
   document: {
    getElementById: () => ({remove: () => {started = true;}}),
    createElement: tag => { assert.strictEqual(tag, 'style'); return {}; },
    querySelectorAll: selector => {
     assert.strictEqual(selector, 'flt-glass-pane');
     return [{shadowRoot:{append: style => styles.push(style)}}, {}];
    },
   },
   _flutter: {
    buildConfig: {builds: [{mainWasmPath:'main.dart.wasm',jsSupportRuntimePath:'main.dart.mjs'},{mainJsPath:'main.dart.js'}]},
    loader: {load: options => {
     configuration = options.config;
     return options.onEntrypointLoaded({initializeEngine: async value => {
      received = value;
      return {runApp: async () => {}};
     }});
    }}
   }
  };
  vm.createContext(context);
  vm.runInContext(support, context);
  await vm.runInContext(bootstrap, context);
  assert.strictEqual(received, configuration);
  const diagnosticWasm = supported && diagnostic.enabled && diagnostic.renderer === 'wasm';
  assert.strictEqual(received.wasmAllowList.webkit, diagnosticWasm);
  assert.strictEqual(received.canvasKitForceMultiSurfaceRasterizer, device.appleMobile);
  assert.strictEqual(received.wasmAllowList.blink, supported && (!device.appleMobile || diagnosticWasm));
  assert(received.fontFallbackBaseUrl.includes('/fallback-fonts/'));
  assert.strictEqual(started, false);
  firstFrame();
  assert(started);
  assert.strictEqual(styles.length, device.appleMobile ? 1 : 0);
  if (device.appleMobile) {
   assert(styles[0].textContent.includes('flt-canvas-container:only-child > canvas:only-child'));
   assert(styles[0].textContent.includes('position: static !important'));
  }
  for (const build of context._flutter.buildConfig.builds) {
   for (const path of Object.values(build)) assert(path.includes('?v='));
  }
  }
  }
 }
})().catch(error => {console.error(error); process.exit(1);});
'''
        subprocess.run(['node', '-e', script, str(WEB)], check=True)

    @unittest.skipUnless(shutil.which('node'), 'Node.js is required for bootstrap tests')
    def test_startup_errors_release_the_loading_animation_and_remain_errors(self):
        script = r'''
const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync(process.argv[1]+'/flutter_bootstrap.js','utf8').replace(/\{\{[^}]+\}\}/g,'');
(async()=>{
 for(const phase of ['load','initialize','run']){
  let removed=false;
  const context={window:{ipingSupportsDartWasm:()=>false,addEventListener:()=>{}},
   navigator:{userAgent:'Chrome',platform:'MacIntel',maxTouchPoints:0},
   document:{getElementById:()=>({remove:()=>{removed=true;}})},
   _flutter:{buildConfig:{builds:[]},loader:{load:async options=>{
    if(phase==='load')throw new Error('startup failed');
    await options.onEntrypointLoaded({initializeEngine:async()=>{
     if(phase==='initialize')throw new Error('startup failed');
     return{runApp:async()=>{throw new Error('startup failed');}};
    }});
   }}}
  };
  vm.createContext(context);
  await assert.rejects(vm.runInContext(source,context),/startup failed/);
  assert(removed);
 }
})().catch(error=>{console.error(error);process.exit(1);});
'''
        subprocess.run(['node', '-e', script, str(WEB)], check=True)

    def test_bundled_chinese_fonts_match_the_manifest(self):
        directory = WEB / 'fallback-fonts'
        manifest = json.loads((directory / 'manifest.json').read_text())
        self.assertEqual(len(manifest['engineRevision']), 40)
        self.assertGreater(len(manifest['files']), 0)
        for name, expected in manifest['files'].items():
            data = (directory / name).read_bytes()
            self.assertEqual(data[:4], b'wOF2', name)
            self.assertEqual(hashlib.sha256(data).hexdigest(), expected, name)


if __name__ == '__main__':
    unittest.main()
