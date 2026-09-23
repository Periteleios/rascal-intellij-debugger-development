# IntelliJ syntax highlighting for `.rsc` (Rascal) files

IntelliJ has no built-in support for Rascal. This wires up real syntax
highlighting via IntelliJ's TextMate Bundles feature.

## Setup

```bash
tools/intellij/setup-intellij-rascal-highlighting.sh
```

Run it once per machine, then restart IntelliJ. It edits your local
IntelliJ settings (not tracked in git) to register the bundle in
`scripts/intellij-rascal-bundle/` and makes sure nothing else (a stray
"Plain Text" mapping, an old custom file type) is claiming the `.rsc`
extension instead.

Safe to re-run. If you previously set this up by hand pointing at some
other path, re-running the script migrates the registration to point at
this repo instead, without leaving a duplicate behind.

If IntelliJ is open when you run it, restart it afterward — editing its
settings files while it's running risks IntelliJ overwriting the change
with its own in-memory state when it next saves.

To verify: Settings → Editor → TextMate Bundles should list `rascal-basic`
enabled, and Settings → Editor → File Types → search `rsc` should show it
owned by that bundle rather than Plain Text.

## Why the grammar is patched

`scripts/intellij-rascal-bundle/` is derived from
[thron7/vsc-rascal](https://github.com/thron7/vsc-rascal)'s TextMate
grammar, with fixes applied directly to `syntaxes/rascal.tmLanguage.json`:

- **Keyword coverage.** The upstream grammar turned out to be VS Code's
  stock Java grammar with scope names relabeled `.rascal` — it has real
  rules for Java constructs (classes, enums, records, `instanceof`, Java's
  primitive types) that don't exist in Rascal, but had *no* rule at all for
  Rascal's actual keywords and collection/basic types (`list`, `set`,
  `map`, `rel`, `lrel`, `tuple`, `bag`, `str`, `bool`, `loc`, `node`, `num`,
  `real`, `rat`, `datetime`, `value`, `data`, `syntax`, `lexical`, `anno`,
  `alias`, `visit`, etc.). Two new rules were added to the `keywords`
  repository section covering the real Rascal keyword list (extracted from
  `keyword RascalKeywords` in the actual Rascal grammar source, in
  `org.rascalmpl:rascal`'s sources jar).
- **Doc-comment bodies.** `@doc{...}` / `@synopsis{...}` (and any other
  `@Name{...}` tag) bodies are free-text documentation, but the upstream
  grammar just kept tokenizing their contents as ordinary code — common
  words in the prose (`it`, `in`, `one`, capitalized words like `JSON`)
  were getting colored as keywords or types. The `annotations` repository
  section now treats `@Name{...}` as an opaque region (with recursive
  brace matching, so nested `{}` doesn't end the match early), so the body
  text is left alone.
- **String splicing (`"<expr>"`).** Rascal string literals can embed real
  code via `<...>` (e.g. `"<replaceAll(schemaId, "\"", "")>"`), a feature
  that doesn't exist in Java, so the upstream string rule had no concept
  of it — it only knows `"..."` and `\.` escapes. Once a splice contained
  its own nested string literal, the tokenizer's string/non-string state
  desynced and coloring broke for the rest of the line. The `strings`
  repository section now treats `<...>` inside a double-quoted string as
  an embedded-code region (recursing back into the full `#code` patterns,
  so a nested string like `"\""` is tokenized as its own real string
  rather than confused with the outer one). This doesn't handle every
  case a real parser would (e.g. a bare `<`/`>` used as a comparison
  operator directly inside a splice can still end the region early), but
  fixes the common case of nested strings/escapes inside a splice.

The Java-shaped structural rules (classes, records, lambdas, etc.) were
left in place rather than removed — they're dead weight since Rascal code
never triggers them, but harmless.

If you need to patch the grammar further, edit
`scripts/intellij-rascal-bundle/syntaxes/rascal.tmLanguage.json` directly
and restart IntelliJ (or reopen the file) to see the change — no need to
re-run the setup script unless you're changing *which* directory is
registered as the bundle.
