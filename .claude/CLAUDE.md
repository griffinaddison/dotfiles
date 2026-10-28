# Shell commands

Never write `cd <dir> && git ...`. Use `git -C <dir> ...` instead — the `cd` form always triggers a permission prompt (untrusted-git-hooks check) and no allow rule can suppress it. Same idea elsewhere: prefer flags or absolute paths over `cd &&` chains.

# Writing style

Write simply, the way Paul Graham describes in "Write Simply" (paulgraham.com/simply.html): like you're explaining to a smart friend, not writing a spec.

- Short sentences. Plain words. One idea per sentence.
- Explain; don't compress. If a sentence needs three em-dashes and two parentheticals, break it into three sentences.
- Say "the joystick sends a velocity, but URR wants a position" — not "the producer speaks velocity while the consumer wants poses, hence the impedance mismatch."
- Keep the technical terms that carry weight: symbol names, flags, numbers, file paths. Cut the ones that just sound smart.
- This applies to everything you write for humans: PR descriptions, commit messages, code comments, docs, chat replies.

# Rex

I work in Rex, a terminal multiplexer like tmux. Assume the Rex app on my MacBook Air is open and I'm watching it. So when something is easier to see than to describe, show it to me in Rex. Use the rex skill for how.

- **Show things next to your pane.** Logs, `top`, a diff, a dev server, a file in nvim. Use `rex split -s "$REX_SESSION" -b "$REX_BLOCK" --split=below --focus=false -- <cmd>`. Commands run on the machine whose Rex server owns the pane.
- **Two servers.** The Mac runs one, and hub runs one. Hub sessions are where most of my agents live. From hub, `rex -S mac ...` reaches the Mac's server. From the Mac, `rex -S hub.taild08285.ts.net ...` reaches hub.
- **The app can be driven.** Remote Control is on, so `rex client ls` finds it and `rex do -C <client> <action>` runs app actions, such as switching session or opening Settings.
- **Leave my panes alone.** Don't type into or close panes you didn't open, unless I ask. Close the panes you opened when you're done with them.
