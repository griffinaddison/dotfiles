# Shell commands

Never write `cd <dir> && git ...`. Use `git -C <dir> ...` instead — the `cd` form always triggers a permission prompt (untrusted-git-hooks check) and no allow rule can suppress it. Same idea elsewhere: prefer flags or absolute paths over `cd &&` chains.

# Writing style

Write simply, the way Paul Graham describes in "Write Simply" (paulgraham.com/simply.html): like you're explaining to a smart friend, not writing a spec.

- Short sentences. Plain words. One idea per sentence.
- Explain; don't compress. If a sentence needs three em-dashes and two parentheticals, break it into three sentences.
- Say "the joystick sends a velocity, but URR wants a position" — not "the producer speaks velocity while the consumer wants poses, hence the impedance mismatch."
- Keep the technical terms that carry weight: symbol names, flags, numbers, file paths. Cut the ones that just sound smart.
- This applies to everything you write for humans: PR descriptions, commit messages, code comments, docs, chat replies.
