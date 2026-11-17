"""Exercise real Neovim checkpoints with an isolated, fake Rex endpoint."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('nvim'), 'Neovim required')
class EditorRecovery(unittest.TestCase):
    def test_layout_unsaved_buffers_and_clean_exit(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)
            fake = p / 'rex'
            fake.write_text('#!/usr/bin/env python3\nimport json,sys\nprint(json.dumps('
                            '{"host_id":"test", "instance_id":"before"} if sys.argv[1]=="whoami" '
                            'else {"foreground":{"name":"nvim"}}))\n')
            fake.chmod(0o700)
            (p/'one.txt').write_text('on disk\nsecond line\n')
            init = p/'init.lua'
            init.write_text('vim.opt.rtp:append(' + json.dumps(str(ROOT/'.config/nvim')) + ')\n'
                            "require('rex-session').setup()\n")
            env = dict(os.environ, PATH=tmp+':'+os.environ['PATH'], XDG_STATE_HOME=str(p/"state"),
                       REX_SESSION='session:test', REX_BLOCK='block:test')
            env.pop('CLAUDECODE', None)
            env.pop('TMUX', None)
            # Session save uses the installed helper, as the real config does.
            script = p/'save.lua'
            script.write_text('''
vim.cmd('edit one.txt')
vim.api.nvim_buf_set_lines(0,0,-1,false,{'unsaved edit','second line'})
vim.cmd('vsplit')
vim.cmd('enew')
vim.api.nvim_buf_set_lines(0,0,-1,false,{'unnamed draft'})
vim.cmd('tabnew one.txt')
vim.api.nvim_win_set_cursor(0,{2,3})
require('rex-session').save()
os.exit(0) -- Simulate process loss: no VimLeavePre cleanup.
''')
            saved=subprocess.run(['nvim','--headless','-u',str(init),'-c','luafile '+str(script)],
                           env=env,cwd=tmp,check=True,timeout=20,capture_output=True)
            self.assertTrue(list((p/'state/rex/claude-panes').glob('*.json')), repr(saved.stderr))
            state = next((p/'state/rex/claude-panes').glob('*.json'))
            data = json.loads(state.read_text())
            self.assertTrue(data['active'])
            self.assertEqual(len(data['editor']['buffers']),2)
            session=p/'session.vim';session.write_text(data['editor']['session'])
            env['REX_NVIM_RECOVER']=str(state)
            check=p/'check.lua'
            check.write_text('''
vim.cmd('source session.vim')
require('rex-session').recover()
assert(#vim.api.nvim_list_tabpages()==2, 'tabs lost')
assert(#vim.api.nvim_tabpage_list_wins(vim.api.nvim_list_tabpages()[1])==2, 'split lost')
assert(vim.api.nvim_get_current_line()=='second line', 'cursor line lost')
assert(vim.api.nvim_win_get_cursor(0)[2]==3, 'cursor column lost')
local named,draft=false,false
for _,buf in ipairs(vim.api.nvim_list_bufs()) do
 if vim.api.nvim_buf_is_loaded(buf) then
  local line=vim.api.nvim_buf_get_lines(buf,0,1,false)[1]
  if line=='unsaved edit' then named=vim.bo[buf].modified end
  if line=='unnamed draft' then draft=vim.bo[buf].modified end
 end
end
assert(named and draft, 'unsaved text/modified flags lost')
require('rex-session').save()
vim.cmd('qa!')
''')
            result=subprocess.run(['nvim','-n','--headless','-u',str(init),'-c','lua local ok,err=pcall(dofile,'+json.dumps(str(check))+'); if not ok then print(err); os.exit(1) end'],
                                  env=env,cwd=tmp,timeout=20,capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertFalse(json.loads(state.read_text())['active'])
            self.assertEqual((p/'one.txt').read_text(),'on disk\nsecond line\n')


if __name__=='__main__':
    unittest.main()
