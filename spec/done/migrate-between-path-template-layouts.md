## **Story: Migrate an existing journal directory to the nested layout**

**Use Case:** Moving an existing flat `YYYY-MM-DD.md` journal directory to the nested `%Y/%m/%Y-%m-%d.md` layout is a one-off, personal task, not a plugin feature — nothing reusable, tested, or committed to jjournal.nvim itself. Just a command to run manually, once, against a real journal directory.

(Two related ideas came up while discussing this and were split out separately: a more elaborate interactive checklist-buffer workflow, `spec/backlog/interactive-checklist-migration-buffer.md`, and a longer-term question of whether migration tooling belongs in a separate, more generic plugin, `spec/backlog/consider-extracting-migrate-plugin.md`. Both are deferred, not part of this story.)

### **The command**

Preferred: `zmv` (zsh), since it already provides dry-run preview and refuses to overwrite an existing destination by default.

```zsh
cd ~/notes/journals
# preview only, touches nothing:
zmv -n -p 'mkdir -p' '([0-9][0-9][0-9][0-9])-([0-9][0-9])-([0-9][0-9]).md' '$1/$2/$1-$2-$3.md'
# once the plan looks right, run for real:
zmv    -p 'mkdir -p' '([0-9][0-9][0-9][0-9])-([0-9][0-9])-([0-9][0-9]).md' '$1/$2/$1-$2-$3.md'
```

(`autoload -Uz zmv` first if it's not already autoloaded in your shell.)

Fallback: a standalone `migrate-to-nested.lua` script, run via `nvim -l migrate-to-nested.lua` (dry run) or `nvim -l migrate-to-nested.lua apply` (executes), with the same safety properties (dry run by default, never overwrites an existing destination, keeps going and reports per-file outcome if one move fails). Not part of this repo — a one-off file handed over directly, not committed.

### **Busted Test Cases**

None — this is a manual, one-off operation against a real journal directory, not plugin code.
