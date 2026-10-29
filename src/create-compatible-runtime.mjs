/** Original compatibility glue; the upstream runtime is not bundled. */
export function createCompatibleRuntime(NativeRuntime, { platform = process.platform } = {}) {
  if (typeof NativeRuntime?.prototype?.selectContainmentMode !== 'function' ||
      typeof NativeRuntime?.prototype?.warnFallback !== 'function') {
    throw new TypeError('Unsupported DSH subprocess runtime API');
  }
  return class WindowsCompatibleSubprocessRuntime extends NativeRuntime {
    selectContainmentMode(kind) {
      if (platform === 'win32' && kind === 'ordinary') {
        this.warnFallback('win32', kind, 'Windows Job bootstrap spawn EPERM compatibility workaround');
        return 'fallback';
      }
      return super.selectContainmentMode(kind);
    }
  };
}
