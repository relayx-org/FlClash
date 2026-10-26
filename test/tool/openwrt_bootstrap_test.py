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
    def test_http_login_completes_and_cleans_up_or_cancels_when_the_popup_closes(self):
        script = r'''
const fs=require('fs'), vm=require('vm'), assert=require('assert');
const source=fs.readFileSync(process.argv[1]+'/bridge.js','utf8');
(async()=>{
 for(const delivery of ['message','broadcast','closed']){
  const calls=[], timers=new Map(), intervals=new Map();let next=0, channel, message, closed=0;
  const state='s'.repeat(43), code='c'.repeat(43);
  const popup={closed:false,location:{replace:()=>{}},close:()=>{closed++;}};
  const sandbox={URL,AbortController,location:{origin:'http://router'},
   localStorage:{getItem:()=>null},addEventListener:(name,callback)=>{if(name==='message')message=callback;},open:()=>popup,
   setTimeout:fn=>{timers.set(++next,fn);return next;},clearTimeout:id=>timers.delete(id),
   setInterval:fn=>{intervals.set(++next,fn);return next;},clearInterval:id=>intervals.delete(id),
   BroadcastChannel:class{constructor(){channel=this;}close(){}},
   fetch:async(path,options)=>{
    const method=path.split('/').at(-1),args=JSON.parse(options.body);calls.push(method);
    if(method==='begin_login')assert.strictEqual(args.redirect_uri,'http://router/iping-login.html');
    if(method==='complete_login')assert.deepStrictEqual(args,{code,state});
    return{ok:true,json:async()=>({ok:true,data:method==='begin_login'?{state,url:'https://account/client-login'}:null})};
   }
  };
  sandbox.window=sandbox;vm.createContext(sandbox);vm.runInContext(source,sandbox);
  const pending=sandbox.ipingSignIn(false);
  await new Promise(setImmediate);
  assert.strictEqual(intervals.size,1);
  if(delivery!=='closed'){
   await channel.onmessage({data:{type:'iping-login',state:'x'.repeat(43),code}});
   assert.deepStrictEqual(calls,['begin_login']);
   if(delivery==='broadcast')await channel.onmessage({data:{type:'iping-login',state,code}});
   else{
    message({origin:'http://other',data:{type:'iping-login',state,code}});
    assert.deepStrictEqual(calls,['begin_login']);
    message({origin:'http://router',data:{type:'iping-login',state,code}});
   }
   assert.strictEqual(await pending,null);
   assert.deepStrictEqual(calls,['begin_login','complete_login','sync']);
  }else{
   popup.closed=true;
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

    @unittest.skipUnless(shutil.which('node'), 'Node.js is required for bootstrap tests')
    def test_engine_receives_the_supported_browser_configuration(self):
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
  for (const device of [
   {userAgent:'Chrome',platform:'MacIntel',maxTouchPoints:0},
   {userAgent:'iPhone CriOS/156',platform:'iPhone',maxTouchPoints:5},
   {userAgent:'Macintosh Safari',platform:'MacIntel',maxTouchPoints:5},
   {userAgent:'Android Chrome',platform:'Linux',maxTouchPoints:5},
  ]) {
  let received;
  let configuration;
  let started = false;
  let firstFrame;
  const context = {
   window: {
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
  assert.strictEqual(received.wasmAllowList.webkit, false);
  assert.strictEqual(received.wasmAllowList.blink, supported);
  assert(received.fontFallbackBaseUrl.includes('/fallback-fonts/'));
  assert.strictEqual(started, false);
  firstFrame();
  assert(started);
  for (const build of context._flutter.buildConfig.builds) {
   for (const path of Object.values(build)) assert(path.includes('?v='));
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
