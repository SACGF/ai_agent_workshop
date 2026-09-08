The smallest possible end-to-end task: prove you can go from an empty repo to a
working command, with an agent driving.

## Goal

`mytools --version` prints a version string and exits 0.

## Acceptance criteria

- [ ] `mytools --version` prints something like `mytools 0.1.0`
- [ ] Exit code is 0
- [ ] `mytools` with no arguments prints usage and exits 2
- [ ] Committed, with a message referencing this issue

## Notes

- Pick any language. Python is fine; so is anything else.
- One file is fine. Do not build a package, a CLI framework, or a plugin system.
- Do **not** implement any subcommands yet — that's what the rest of the issues are
  for. Stop when `--version` works.

Scope discipline is the actual lesson. Agents will happily build you a full CLI
skeleton with five stub subcommands if you let them.
