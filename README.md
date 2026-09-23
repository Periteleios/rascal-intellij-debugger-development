# rascal-intellij-debugger

Standalone home for the **Rascal Debugger** IntelliJ plugin
(`tools/intellij/rascal-terminal-plugin/`) and its supporting scripts
(`tools/intellij/`), plus a minimal Maven-based Rascal project
(`src/main/rascal/`) to develop and test them against.

This project exists to prove and use, in practice, what the plugin itself
guarantees: it works with **any** Maven-based Rascal project, not a
specific one. It used to be developed only inside `adept-base` (a large,
private, unrelated codebase); this repo is a clean, standalone,
public home for it instead.

## What's here

- `tools/intellij/rascal-terminal-plugin/` -- the actual IntelliJ plugin
  source (Java + Gradle). BSD 2-Clause licensed, see its own `LICENSE`.
- `tools/intellij/{run-rsc-lsp.sh,compute-classpath.sh,
  setup-intellij-rascal-highlighting.sh}` -- the supporting scripts (LSP
  language server + syntax highlighting setup). BSD 2-Clause licensed,
  see `tools/intellij/LICENSE`.
- `scripts/intellij-rascal-bundle/` + `docs/intellij_rascal_highlighting.md`
  -- the TextMate syntax-highlighting grammar. This one is a derivative of
  a separate third-party project (`thron7/vsc-rascal`, itself unlicensed
  upstream) and is **not** covered by the BSD 2-Clause license above --
  see that doc for its provenance.
- `pom.xml` + `src/main/rascal/{Sanity.rsc,Helper.rsc}` -- a minimal
  Rascal project, just enough to compile and to exercise the plugin
  against: `Sanity::main` imports `Helper`, so you can test breakpoints,
  stepping across modules, and an uncaught exception whose stack trace
  correctly surfaces the *other* module as the failure site. See the
  `@doc{}` comment at the top of `Sanity.rsc` for the exact walkthrough.

See [tools/intellij/README.md](tools/intellij/README.md) for full setup
instructions (syntax highlighting, editing, debugging) -- everything
there is self-contained to this repo now, no `adept-base` needed for any
of it.

## Getting started

```bash
mvn clean compile dependency:resolve
```

Then open this directory as a project in IntelliJ IDEA and follow
`tools/intellij/README.md`.
