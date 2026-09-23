# rascal-intellij-debugger-development

Standalone home for the **Rascal Debugger** IntelliJ plugin
(`tools/intellij/rascal-debugger-plugin/`), plus a minimal Maven-based
Rascal project (`src/main/rascal/`) to develop and test it against.

This project exists to prove and use, in practice, what the plugin itself
guarantees: it works with **any** Maven-based Rascal project, not a
specific one. It used to be developed only inside `adept-base` (a large,
private, unrelated codebase); this repo is a clean, standalone,
public home for it instead.

## What's here

- `tools/intellij/rascal-debugger-plugin/` -- the actual IntelliJ plugin
  source (Java + Gradle). BSD 2-Clause licensed, see its own `LICENSE`.
  As of 0.1.0, installing this plugin auto-configures syntax
  highlighting, editing, and debugging on its own -- see
  `tools/intellij/README.md` for how.
- `.../src/main/resources/rascal-textmate-bundle/` -- the bundled
  syntax-highlighting grammar. **Not** covered by the plugin's own BSD
  2-Clause license above: its own `"about"` field states it started
  from [VS Code's Java grammar](https://github.com/microsoft/vscode/blob/master/extensions/java/syntaxes/java.tmLanguage.json),
  MIT licensed (c) Microsoft.
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
./build.sh
```

Then open this directory as a project in IntelliJ IDEA and follow
`tools/intellij/README.md`.
