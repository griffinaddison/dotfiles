#!/usr/bin/env python3
"""Save Claude, Codex and Neovim per Rex pane; resume after a restart.

The original filename and state directory are kept for existing installations.
"""
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import uuid


def rex(*args):
    return json.loads(subprocess.check_output(
        ['rex', *args], timeout=5, stderr=subprocess.DEVNULL))


def location():
    session, block = os.getenv('REX_SESSION'), os.getenv('REX_BLOCK')
    if not session or not block:
        return None
    server = rex('whoami', '--json')
    identity = [server['host_id'], session, block]
    key = hashlib.sha256(json.dumps(identity).encode()).hexdigest()
    root = Path(os.getenv('XDG_STATE_HOME', str(Path.home() / '.local/state')))
    directory = root / 'rex/claude-panes'
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    return directory / (key + '.json'), server, session, block


@contextlib.contextmanager
def locked(path):
    with open(str(path) + '.lock', 'a', opener=lambda p, f: os.open(p, f, 0o600)) as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def read(path):
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        return {}


def write(path, data):
    # fsync + atomic rename: a power cut cannot leave a half-written mapping.
    fd, name = tempfile.mkstemp(dir=path.parent, prefix='.pending-')
    try:
        with os.fdopen(fd, 'w') as out:
            json.dump(data, out, indent=2)
            out.flush()
            os.fsync(out.fileno())
        os.replace(name, path)
        directory = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def codex_owns_pane(session, block):
    """Shared app servers inherit stale REX_*; only trust the pane's process tree."""
    process = rex('block', 'call', '-s', session, '-b', block, 'process')
    foreground = process.get('foreground') or {}
    if foreground.get('name') != 'codex':
        return False
    target, pid = foreground['pid'], os.getppid()
    for _ in range(32):
        if pid == target:
            return True
        if pid <= 1:
            return False
        parent = subprocess.check_output(['ps', '-o', 'ppid=', '-p', str(pid)],
                                         text=True, timeout=2).strip()
        if not parent:
            return False
        pid = int(parent)
    return False


def save(data, app="claude"):
    where = location()
    if not where:
        return
    path, server, session, block = where
    if app == 'codex' and not codex_owns_pane(session, block):
        return
    sid = str(data['session_id']) if app == 'nvim' else str(uuid.UUID(data['session_id']))
    with locked(path):
        previous = read(path)
        event = data['hook_event_name']
        if event == 'SessionEnd':
            # Shutdown/signal exits must remain recoverable. Ignore late exits
            # from an older conversation after /resume or /clear.
            if (previous.get('app', 'claude') == app and
                    previous.get('conversation', previous.get('claude_session')) == sid and
                    (data.get('reason') in ('prompt_input_exit', 'logout', 'clear', 'resume')
                     or app == 'codex' and data.get('reason') == 'other')):
                previous['active'] = False
                write(path, previous)
            return
        if event not in ('SessionStart', 'UserPromptSubmit'):
            return
        write(path, dict(version=2, app=app, conversation=sid,
                         editor=data.get('editor'),
                         host=server['host_id'], session=session,
                         block=block, claude_session=sid, cwd=data['cwd'],
                         transcript=data.get('transcript_path'), active=True,
                         auth='api' if os.getenv('ANTHROPIC_API_KEY') else 'default',
                         instance=server['instance_id']))


def restore(shell_pid, force=False):
    where = location()
    if not where:
        return
    path, server, session, block = where
    # Only the pane's original shell may restore, never a nested shell, agent
    # tool subprocess, or a shell running inside another terminal multiplexer.
    process = rex('block', 'call', '-s', session, '-b', block, 'process')
    if (process.get('child', {}).get('pid') != shell_pid or
            process.get('foreground', {}).get('pid') not in (shell_pid, os.getpid())):
        return
    with locked(path):
        data = read(path)
        if not data.get('active'):
            return
        instance = server['instance_id']
        if not force and (data.get('instance') == instance or data.get('attempt') == instance):
            return
        app = data.get('app', 'claude')
        sid = data.get('conversation', data.get('claude_session'))
        if app != 'nvim':
            sid = str(uuid.UUID(sid))
        if not Path(data['cwd']).is_dir():
            raise ValueError('saved working directory is missing: ' + data['cwd'])
        data['attempt'] = instance
        write(path, data)
    print('Restoring ' + app + ' session ' + sid, flush=True)
    if app == 'nvim':
        snapshot = path.with_suffix('.vim')
        # Session text comes only from our local Neovim mksession checkpoint.
        fd, temporary = tempfile.mkstemp(dir=path.parent)
        with os.fdopen(fd, 'w') as out:
            out.write(data['editor']['session'])
            out.flush()
            os.fsync(out.fileno())
        os.replace(temporary, snapshot)
        env = dict(os.environ, REX_NVIM_RECOVER=str(path))
        result = subprocess.run(['nvim', '-n', '-S', str(snapshot), '-c',
                                 "lua require('rex-session').recover()"],
                                cwd=data['cwd'], env=env)
    else:
        # Positional arguments, never eval saved state. Load the user's aliases
        # and API wrapper without generating a new prompt or model request.
        if app == 'codex':
            command = 'cd -- "$1" || exit; codex --no-daemon resume "$2"'
        elif app == 'claude':
            command = 'cd -- "$1" || exit; if [[ "$3" == api ]]; then (( $+functions[claude] )) || { print -u2 "Missing claude API wrapper in .zshrc"; exit 1; }; claude --resume "$2"; else command claude --resume "$2"; fi'
        else:
            raise ValueError('unknown application: ' + app)
        result = subprocess.run(['zsh', '-ic', command, 'rex-pane-restore',
                                 data['cwd'], sid, data['auth']])
    if result.returncode:
        print('Restore failed; use rex-pane-resume to retry.', file=sys.stderr)


def main():
    try:
        if sys.argv[1] == 'hook':
            save(json.load(sys.stdin), sys.argv[2] if len(sys.argv) > 2 else 'claude')
        else:
            restore(int(sys.argv[2]), force=sys.argv[1] == 'retry')
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print('Rex Claude restore: ' + str(error), file=sys.stderr)


if __name__ == '__main__':
    main()
