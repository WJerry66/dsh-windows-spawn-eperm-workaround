import test from 'node:test';
import assert from 'node:assert/strict';
import { createCompatibleRuntime } from '../src/create-compatible-runtime.mjs';

class Native {
  static inject = { subprocess: 'service' };
  constructor() { this.warnings = []; this.nativeCalls = []; }
  warnFallback(...args) { this.warnings.push(args); }
  selectContainmentMode(kind) { this.nativeCalls.push(kind); return `native:${kind}`; }
}
test('Windows ordinary launches use fallback while preserving service inheritance', () => {
  const Runtime = createCompatibleRuntime(Native, { platform: 'win32' });
  const runtime = new Runtime();
  assert.ok(runtime instanceof Native);
  assert.equal(Runtime.inject, Native.inject);
  assert.equal(runtime.selectContainmentMode('ordinary'), 'fallback');
  assert.deepEqual(runtime.nativeCalls, []);
  assert.equal(runtime.warnings.length, 1);
});
test('terminal and non-Windows containment delegate to native runtime', () => {
  for (const [platform, kind] of [['win32', 'terminal'], ['linux', 'ordinary'], ['darwin', 'terminal']]) {
    const Runtime = createCompatibleRuntime(Native, { platform });
    const runtime = new Runtime();
    assert.equal(runtime.selectContainmentMode(kind), `native:${kind}`);
    assert.deepEqual(runtime.nativeCalls, [kind]);
    assert.equal(runtime.warnings.length, 0);
  }
});
test('changed upstream API fails explicitly', () => {
  assert.throws(() => createCompatibleRuntime(class {}), /Unsupported/);
});
