// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found at https://github.com/flutter/flutter/blob/main/LICENSE.

window.ipingSupportsDartWasm = () => {
  if (typeof WebAssembly === 'undefined') return false;
  const validate = (bytes, options) => WebAssembly.validate(new Uint8Array(bytes), options);
  const gc = validate([0,97,115,109,1,0,0,0,1,5,1,95,1,120,0]);
  const simd = validate([0,97,115,109,1,0,0,0,1,5,1,96,0,1,123,3,2,1,0,10,10,1,8,0,65,0,253,15,253,98,11]);
  const strings = !validate([0,97,115,109,1,0,0,0,1,4,1,96,0,0,2,23,1,14,119,97,115,109,58,106,115,45,115,116,114,105,110,103,4,99,97,115,116,0,0], {builtins:['js-string']});
  const exceptions = validate([0,97,115,109,1,0,0,0,1,4,1,96,0,0,3,2,1,0,10,13,1,11,0,2,64,31,64,1,2,0,11,11,11]);
  return gc && simd && strings && exceptions;
};
