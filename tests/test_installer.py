"""Dependency-free integration tests. Uses synthetic ASAR and temporary profiles only."""
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts' / 'Manage-Workaround.ps1'


def make_asar(path, version='0.2.1-rc.3', code=None):
    contents = {
        'dsh/node_modules/@deepseek-ai/dsh-subprocess-local/package.json': json.dumps({
            'name': '@deepseek-ai/dsh-subprocess-local', 'version': version}).encode(),
        'dsh/node_modules/@deepseek-ai/dsh-subprocess-local/lib/index.js': (
            code if code is not None else 'selectContainmentMode(kind) {} warnFallback() {} launchWindowsJob() {}'
        ).encode(),
    }
    header = {'files': {}}
    payload = b''
    for name, data in contents.items():
        node = header
        parts = name.split('/')
        for part in parts[:-1]:
            node = node['files'].setdefault(part, {'files': {}})
        node['files'][parts[-1]] = {'size': len(data), 'offset': str(len(payload))}
        payload += data
    encoded = json.dumps(header, separators=(',', ':')).encode()
    padding = b'\0' * ((-len(encoded)) % 4)
    header_size = 8 + len(encoded) + len(padding)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(struct.pack('<IIII', 4, header_size, header_size - 4, len(encoded)) + encoded + padding + payload)


@unittest.skipUnless(os.name == 'nt', 'Installer requires Windows PowerShell')
class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dsh-workaround-test-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.app = self.base / 'App with space 测试'
        self.asar = self.app / 'resources' / 'app.asar'
        make_asar(self.asar)
        self.profile = self.base / 'profile'
        self.profile.mkdir()
        self.config = self.profile / 'cordis.patch.yml'
        self.original = '# 自定义配置\r\n- id: ui-settings\r\n  config:\r\n    enabled: true\r\n'
        self.config.write_bytes(self.original.encode())

    def run_script(self, action, *extra, ok=True):
        result = subprocess.run([
            'powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(SCRIPT),
            '-Action', action, '-AppRoot', str(self.app), '-ProfilePath', str(self.profile), *extra,
        ], capture_output=True, timeout=30)
        if ok:
            self.assertEqual(result.returncode, 0, (result.stdout + result.stderr).decode(errors='replace'))
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def test_install_repeat_rollback_preserves_later_edits(self):
        self.run_script('Check')
        self.run_script('Install')
        installed = self.config.read_bytes()
        self.assertTrue(installed.startswith(self.original.encode()))
        self.assertEqual(installed.count(b'# BEGIN dsh-'), 1)
        loader = (self.profile / 'compat/dsh-windows-spawn-eperm-workaround/loader.mjs').read_text()
        self.assertIn('%20', loader)
        self.assertIn(self.app.as_uri(), loader)
        self.run_script('Check')
        self.run_script('Install')
        self.assertEqual(installed, self.config.read_bytes())
        later = b'- id: later-user-edit\r\n  disabled: true\r\n'
        self.config.write_bytes(installed + later)
        self.run_script('Uninstall')
        self.assertEqual(self.config.read_bytes(), self.original.encode() + later)
        self.assertEqual(len(list(self.profile.glob('cordis.patch.yml.backup-*'))), 2)
        self.run_script('Uninstall')

    def test_whatif_never_writes(self):
        self.run_script('Install', '-WhatIf')
        self.assertEqual(self.config.read_bytes(), self.original.encode())
        self.assertFalse((self.profile / 'compat').exists())

    def test_version_and_api_mismatch_fail_before_mutation(self):
        make_asar(self.asar, version='99.0.0')
        self.run_script('Install', ok=False)
        make_asar(self.asar, code='changed API')
        self.run_script('Install', ok=False)
        self.assertEqual(self.config.read_bytes(), self.original.encode())
        self.assertFalse((self.profile / 'compat').exists())

    def test_invalid_archive_fails_before_mutation(self):
        self.asar.write_bytes(b'bad archive')
        self.run_script('Install', ok=False)
        self.assertEqual(self.config.read_bytes(), self.original.encode())

    def test_conflicting_config_rejected(self):
        for text in ('[]\n', 'key: value\n', '- id: subprocess\n  disabled: true\n',
                     '- id: "subprocess"\n', '- id: subprocess-windows-compat\n'):
            self.config.write_bytes(text.encode())
            self.run_script('Install', ok=False)
            self.assertEqual(self.config.read_bytes(), text.encode())

    def test_edited_or_duplicate_block_not_removed(self):
        self.run_script('Install')
        valid = self.config.read_bytes()
        for changed in (valid.replace(b'disabled: true', b'disabled: false'),
                        valid + valid, valid.replace(b'# END dsh-', b'# REMOVED dsh-')):
            self.config.write_bytes(changed)
            self.run_script('Uninstall', ok=False)
            self.assertEqual(self.config.read_bytes(), changed)

    def test_uninstall_does_not_need_app(self):
        self.run_script('Install')
        shutil.rmtree(self.app)
        self.run_script('Uninstall')
        self.assertEqual(self.config.read_bytes(), self.original.encode())

    def test_new_config_and_no_trailing_newline(self):
        self.config.unlink()
        self.run_script('Install')
        self.run_script('Uninstall')
        self.assertEqual(self.config.read_bytes(), b'')
        shutil.rmtree(self.profile / 'compat')
        self.config.write_bytes(b'# original without newline')
        self.run_script('Install')
        self.run_script('Uninstall')
        self.assertEqual(self.config.read_bytes(), b'# original without newline\n')


if __name__ == '__main__':
    unittest.main(verbosity=2)
