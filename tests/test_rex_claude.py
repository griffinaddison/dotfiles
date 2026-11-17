import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[1] / '.config/rex/claude-session.py'
spec = importlib.util.spec_from_file_location('restore', MODULE)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
SID = '34309af4-bc7c-461d-9a55-d9c1b3ea0ea5'
OTHER = '842c9c1e-0e08-4a61-9efb-29fd62e0adc3'


class Recovery(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.env = patch.dict(os.environ, {'XDG_STATE_HOME': self.tmp.name,
            'REX_SESSION': 'session:test', 'REX_BLOCK': 'block:test',
            'ANTHROPIC_API_KEY': 'test-only'})
        self.env.start()
        self.addCleanup(self.env.stop)
        ownership = patch.object(m, 'codex_owns_pane', return_value=True)
        ownership.start()
        self.addCleanup(ownership.stop)
        self.instance = 'before-reboot'
        self.shell_pid = 1234
        self.rex = patch.object(m, 'rex', self.fake_rex)
        self.rex.start()
        self.addCleanup(self.rex.stop)
        self.launch = patch.object(m.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0))
        self.run = self.launch.start()
        self.addCleanup(self.launch.stop)

    def fake_rex(self, *args):
        if args[0] == 'whoami':
            return dict(host_id='host', instance_id=self.instance)
        return dict(child={'pid':self.shell_pid}, foreground={'pid':self.shell_pid})

    def save(self, sid=SID, event='SessionStart', **kw):
        m.save(dict(session_id=sid, hook_event_name=event, cwd=self.tmp.name, **kw))

    def test_reboot_resumes_exact_conversation_once(self):
        self.save()
        m.restore(1234)
        self.run.assert_not_called()
        self.instance = 'after-reboot'
        m.restore(1234)
        self.assertEqual(self.run.call_args.args[0][-3:], [self.tmp.name, SID, 'api'])
        m.restore(1234)
        self.assertEqual(self.run.call_count, 1)

    def test_explicit_exit_does_not_reopen(self):
        self.save()
        self.save(event='SessionEnd', reason='prompt_input_exit')
        self.instance = 'after-reboot'
        m.restore(1234)
        self.run.assert_not_called()

    def test_shutdown_exit_remains_recoverable(self):
        self.save()
        self.save(event='SessionEnd', reason='other')
        self.instance = 'after-reboot'
        m.restore(1234)
        self.run.assert_called_once()

    def test_session_switch_and_late_exit(self):
        self.save()
        self.save(sid=OTHER)
        self.save(event='SessionEnd', reason='resume')
        self.instance = 'after-reboot'
        m.restore(1234)
        self.assertEqual(self.run.call_args.args[0][-2], OTHER)

    def test_nested_shell_never_restores(self):
        self.save()
        self.instance = 'after-reboot'
        m.restore(9999)
        self.run.assert_not_called()

    def test_foreground_helper_is_allowed(self):
        self.save()
        self.instance = 'after-reboot'
        def current(*args):
            if args[0] == 'whoami':
                return dict(host_id='host', instance_id=self.instance)
            return dict(child={'pid':1234}, foreground={'pid':os.getpid()})
        with patch.object(m, 'rex', current):
            m.restore(1234)
        self.run.assert_called_once()

    def test_different_pane_never_restores(self):
        self.save()
        self.instance = 'after-reboot'
        with patch.dict(os.environ, {'REX_BLOCK': 'block:other'}):
            m.restore(1234)
        self.run.assert_not_called()

    def test_failure_does_not_loop_and_manual_retry_works(self):
        self.save()
        self.instance = 'after-reboot'
        self.run.return_value = subprocess.CompletedProcess([], 1)
        m.restore(1234)
        m.restore(1234)
        self.assertEqual(self.run.call_count, 1)
        m.restore(1234, force=True)
        self.assertEqual(self.run.call_count, 2)

    def test_subscription_and_unusual_directory(self):
        weird = Path(self.tmp.name) / 'space $HOME `touch NO`'
        weird.mkdir()
        with patch.dict(os.environ, {'ANTHROPIC_API_KEY': ''}):
            m.save(dict(session_id=SID,hook_event_name='SessionStart',cwd=str(weird)))
        self.instance = 'after-reboot'
        m.restore(1234)
        self.assertEqual(self.run.call_args.args[0][-3:], [str(weird), SID, 'default'])

    def test_codex_replaces_claude_and_resumes_exact_thread(self):
        self.save()
        m.save(dict(session_id=OTHER, hook_event_name='SessionStart', cwd=self.tmp.name), 'codex')
        self.instance = 'after-reboot'
        m.restore(1234)
        args = self.run.call_args.args[0]
        self.assertIn('codex --no-daemon resume "$2"', args[2])
        self.assertEqual(args[-2], OTHER)
        self.assertEqual(self.run.call_count, 1)

    def test_shared_codex_daemon_cannot_overwrite_pane(self):
        self.save()
        with patch.object(m, 'codex_owns_pane', return_value=False):
            m.save(dict(session_id=OTHER, hook_event_name='SessionStart', cwd=self.tmp.name), 'codex')
        self.assertEqual(m.read(m.location()[0])['conversation'], SID)

    def test_codex_exit_disables_recovery(self):
        m.save(dict(session_id=OTHER, hook_event_name='SessionStart', cwd=self.tmp.name), 'codex')
        m.save(dict(session_id=OTHER, hook_event_name='SessionEnd', cwd=self.tmp.name, reason='other'), 'codex')
        self.instance = 'after-reboot'
        m.restore(1234)
        self.run.assert_not_called()

    def test_nvim_checkpoint_and_exit(self):
        m.save(dict(session_id='4567', hook_event_name='SessionStart', cwd=self.tmp.name,
                    editor={'session':'set number\n', 'buffers':[], 'windows':[]}), 'nvim')
        self.instance = 'after-reboot'
        m.restore(1234)
        args = self.run.call_args.args[0]
        self.assertEqual(args[0], 'nvim')
        self.assertEqual(Path(args[3]).read_text(), 'set number\n')
        self.assertEqual(Path(args[3]).stat().st_mode & 0o777, 0o600)
        m.save(dict(session_id='4567', hook_event_name='SessionEnd', cwd=self.tmp.name,
                    reason='prompt_input_exit'), 'nvim')
        m.restore(1234, force=True)
        self.assertEqual(self.run.call_count, 1)

    def test_private_valid_state(self):
        self.save()
        path = m.location()[0]
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertNotIn('test-only', path.read_text())
        self.assertEqual(json.loads(path.read_text())['claude_session'], SID)


if __name__ == '__main__':
    unittest.main()
