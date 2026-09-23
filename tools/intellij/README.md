# IntelliJ setup for Rascal (highlighting + editing + debugging)

This directory makes Rascal (`.rsc`) and PTL (`.ptl`) files readable and
editable in IntelliJ IDEA. None of this is automatic and none of it is
bundled into any single install -- there are three independent pieces,
and you need all three, done in order, before things actually work:

0. **Syntax highlighting** (otherwise `.rsc`/`.ptl` render as plain,
   uncolored text) -- via a TextMate bundle, installed by a one-time script.
1. **Editing** (syntax errors, hover, completion, CodeLenses) -- via the
   [LSP4IJ](https://plugins.jetbrains.com/plugin/23257-lsp4ij) plugin and the
   `run-rsc-lsp.sh` / `run-ptl-lsp.sh` launcher scripts.
2. **Debugging** (breakpoints, stepping, variable inspection) -- via
   `rascal-terminal-plugin/` (published as **Rascal Debugger** in its own
   [public releases repo](https://github.com/Periteleios/intellij-plugin-rascal-debug)),
   plus an LSP4IJ DAP ("Debug Adapter Protocol") run configuration.

Installing the "Rascal Debugger" plugin by itself (part 2) gets you
breakpoints/stepping, the "Import"/"Run in new Rascal terminal" CodeLenses,
and "Go to Definition" into the standard library -- it does **not** give you
syntax highlighting or diagnostics/completion; those are parts 0 and 1,
done separately, once, in this same checkout. Do all three before expecting
anything to work end-to-end.

Prerequisite for both: build the project once so `target/classes` exists
and the Maven jars are in your local `~/.m2` repository:

```bash
mvn clean compile dependency:resolve
```

---

## 0. Syntax highlighting

IntelliJ has no built-in Rascal support, so without this `.rsc` files render
as plain, uncolored text. One-time setup -- no arguments needed, it
auto-detects your IntelliJ profile (the most recently modified
`IntelliJIdea*` directory under `~/.config/JetBrains` or
`~/Library/Application Support/JetBrains`); pass one explicitly only if
you have several installs and it picks the wrong one:

```bash
tools/intellij/setup-intellij-rascal-highlighting.sh
# or, explicitly:
tools/intellij/setup-intellij-rascal-highlighting.sh /path/to/IntelliJIdea2026.2
```

If IntelliJ is currently running, the script warns and asks for
confirmation before editing its settings files -- safest to close
IntelliJ first, run the script, then reopen it. Restart IntelliJ, then
verify: Settings > Editor > TextMate Bundles should
list `rascal-basic` enabled. See
[docs/intellij_rascal_highlighting.md](../../docs/intellij_rascal_highlighting.md)
for what the script does and why the grammar needed patching.

---

## 1. Editing: LSP4IJ language servers

1. Install **LSP4IJ** from IntelliJ's Marketplace (Settings > Plugins >
   Marketplace > search "LSP4IJ").
2. Make both launcher scripts executable (one-time):
   ```bash
   chmod +x tools/intellij/run-rsc-lsp.sh tools/intellij/run-ptl-lsp.sh
   ```
3. Settings > Languages & Frameworks > Language Servers > **+** (add a new
   server), twice -- once per file type:

   | | `.rsc` server | `.ptl` server |
   |---|---|---|
   | Server tab, Command | absolute path to `tools/intellij/run-rsc-lsp.sh` | absolute path to `tools/intellij/run-ptl-lsp.sh` |
   | Mappings tab, file name pattern | `*.rsc` | `*.ptl` |
   | Communication | stdio (default, leave as-is) | stdio (default, leave as-is) |

4. Open any `.rsc` file under `src/main/rascal/` -- for example
   [Sanity.rsc](../../src/main/rascal/Sanity.rsc) (module `Sanity`). You
   should see diagnostics, hover, and (above the module/`main()`
   declarations) two CodeLenses: "Import in new Rascal terminal" and "Run
   in new Rascal terminal". Clicking either will error ("Cannot execute
   'rascalmpl.importModule' command! ... needs to be contributed by an
   IntelliJ plugin") until you also do part 2 below.

### Running these scripts from a copy outside this checkout

All three scripts (`run-rsc-lsp.sh`, `run-ptl-lsp.sh`,
`compute-classpath.sh`) resolve "this project" from their own file
location by default, but that's overridable: set `ADEPT_BASE_ROOT` (same
place as `PTL_MILESTONE_ROOT` below -- that Language Server entry's
**Environment variables** field, not the Command field) to an absolute
path to a Maven-based Rascal project checkout -- despite the name, it
doesn't have to be `adept-base` specifically, any such project works
(the underlying language server jar has no idea which project it's
serving); `adept-base` is just what this variable was named after and
what this checkout's own team will actually point it at. A copy of these
scripts living anywhere else will use whatever it's pointed at instead of
computing a location from their own. This is how they're mirrored, still
fully functional, into the
[public rascal-terminal-plugin releases repo](https://github.com/Periteleios/intellij-plugin-rascal-debug)
alongside the syntax-highlighting bundle -- see that repo's own README.
There's no way around needing an actual Maven-built Rascal project
checkout somewhere on disk (the language server's own compiled
implementation and its interpreted modules both come from that build),
but the scripts no longer have to physically live inside it.

The `.ptl` server as set up above puts this checkout's own `src/main/rascal`
on its module search path -- there's no `.ptl` file here yet to try it on
(this project's own sanity check, `Sanity.rsc`/`Helper.rsc`, is plain
`.rsc`), but the setup is ready for whenever one is added. (`adept-base`,
where this setup originally lived, additionally supports a
`PTL_MILESTONE_ROOT` environment variable on this Language Server entry
to scope editing to one of its own PTL "milestones" -- not applicable
here, since this project has no such concept.)

"Go to Definition" into standard library symbols (`IO::println`,
`List::size`, `Set`, `String`, `util::FileSystem`, etc.) needs
`rascal-terminal-plugin` **0.2.0+** (see part 2 below) -- Rascal's compiled
stdlib bakes `std:///`-scheme locations into its definitions, which LSP4IJ
has no built-in way to resolve; the plugin registers a `VirtualFileSystem`
that bridges it. Without that plugin (or on an older version), clicking
into a stdlib symbol silently does nothing.

<span style="color:orange">Both scripts take the jar versions from this project's`pom.xml`
e.g., `<rascal.version>`, `<rascal.lsp.version>`, `<typepal.version>`</span> <br>-- if those
change, update the `RASCAL_JAR`/`LSP_JAR`/`TYPEPAL_JAR` paths at the top of
each script to match.

`run-ptl-lsp.sh` additionally embeds a captured `PathConfig` value. If PTL's
language server dependencies change (new library jar, new source root) and
`.ptl` editing stops working, that file's own header comment has the exact
recapture steps (run a throwaway `ScratchProbe.rsc` module that prints
`lang::ptl::LanguageServer::ptlLangForIDE()` and copy the new value in).

---

## 2. Debugging: `rascal-terminal-plugin` + LSP4IJ DAP config

Unlike parts 0 and 1, nothing here is specific to this checkout: the
"Import"/"Run in new Rascal terminal" CodeLenses compute their classpath
from whatever project is currently open in IntelliJ, via that project's
own `pom.xml` (cached under its own `target/`) -- not from anything
hardcoded to `adept-base`. The DAP breakpoint-handling fix and the
`std:///` stdlib bridge were already fully generic. So this whole plugin
works against any Maven-based Rascal project, this one included.

`rascal-terminal-plugin/`'s own source (every Java file, plus
`build.gradle.kts`/`settings.gradle.kts`) is licensed under BSD 2-Clause
-- see its [LICENSE](rascal-terminal-plugin/LICENSE) file. The four
scripts directly in this directory (`setup-intellij-rascal-
highlighting.sh`, `run-rsc-lsp.sh`, `run-ptl-lsp.sh`,
`compute-classpath.sh`) are covered the same way, under their own
[LICENSE](LICENSE) file one level up -- so any other project or company
can use, modify, or redistribute any of this freely. This is separate
from the syntax-highlighting bundle in part 0
(`scripts/intellij-rascal-bundle/`), which is a derivative of a
third-party project and not covered by either license (see that
project's own README for its provenance).

### 2a. Install the plugin

One-time setup: Settings/Preferences > Plugins > gear icon (⚙) > **Manage
Plugin Repositories...** > **+** > add:

```
https://raw.githubusercontent.com/Periteleios/intellij-plugin-rascal-debug/main/updatePlugins.xml
```

Apply, then go to the **Marketplace** tab and search "Rascal Debugger"
(older releases may still show as "Rascal Terminal Commands") -- it should
show up (possibly labeled as coming from a custom repository rather than
the usual JetBrains vendor listing). Install it, restart when prompted.
Future releases show up as normal plugin updates from then on -- no manual
reinstalling.

(This repo -- and the plugin's actual source in `rascal-terminal-plugin/`
-- is public too now, but releases are still hosted separately, in that
dedicated repo, since IntelliJ's plugin-repository feature needs a
static `updatePlugins.xml` + release assets to auto-update from, not a
source checkout. See that repo's own README for the release process if
you're cutting a new version.)

If you're actively developing the plugin itself rather than just using it,
build and install it locally instead -- see "Building/updating the plugin
jar" below, then Settings > Plugins > gear icon > **Install Plugin from
Disk...**, restart when prompted.

### 2b. Create one LSP4IJ DAP "Attach" run configuration (one-time, per project)

This only needs a destination to attach to -- the plugin fills in the actual
port automatically every time you run something, so the port you enter here
is just a placeholder.

1. Run > Edit Configurations... > **+** > **Debug Adapter Protocol** (added
   by LSP4IJ).
2. Give it a name (e.g. "Rascal Attach").
3. **Set the Server dropdown to "Rascal Debugger"** -- not the default/
   generic entry. This is the one setting that actually matters here: it's
   what makes LSP4IJ construct `RascalDebugAdapterDescriptor` /
   `RascalBreakpointHandler` for the session (registered by this plugin via
   the `com.redhat.devtools.lsp4ij.debugAdapterServer` extension point)
   instead of its own stock descriptor/handler. Without it, breakpoints
   still work, but disabling/removing one while any other breakpoint is
   active anywhere else in the project won't stop the debugger from
   breaking at the one you just disabled -- a real bug in LSP4IJ 0.21.0's
   `BreakpointHandlerBase.unregisterBreakpoint` (it checks the whole
   project's breakpoint list for emptiness, not just the affected file's).
   If that symptom shows up, this dropdown is the first thing to check --
   IntelliJ can silently leave it on the default even if you're sure you
   picked "Rascal Debugger" (this has happened before); confirm by grepping
   `idea.log` for `RascalBreakpointHandler` after setting a breakpoint --
   silence there means the setting didn't take.
4. Set the connection to **Attach**, address `localhost`, port anything
   (e.g. `0`) -- it gets overwritten before every launch.
5. Apply/OK. You do not need to run this configuration yourself; the plugin
   finds it by type and launches it for you.

### 2c. Use it (also the verification step for 2a/2b)

Open any `.rsc` file with a `main()` function -- e.g.
[Sanity.rsc](../../src/main/rascal/Sanity.rsc) -- and click "Run in new
Rascal terminal" above it. A new terminal tab opens, imports the module,
and enables the interpreter's debugger; the plugin then:

- captures that terminal's real process id,
- polls for the new port `org.rascalmpl.dap.DebugSocketServer` opens,
- writes that port into the DAP run configuration from 2b and launches it.

A notification balloon confirms this ("Attaching Rascal debugger on port
..."). Set a breakpoint and type `main(...)` (with whatever arguments you
want) at the terminal's `rascal>` prompt -- execution should stop there.
Try the walkthrough in `Sanity.rsc`'s own `@doc{}` comment for a
breakpoint + cross-module step + uncaught-exception scenario to test
against.

If the notification instead says the port lookup failed or was skipped, or
no DAP run configuration was found, check `idea.log` (Help > Show Log in
Files/Finder) for a `RascalTerminalSupport`/`RascalDebugPortFinder`/
`RascalDebugAttachConfigurator` entry -- every failure path logs there.

---


<br>

### Further Reading

###### Building/updating the plugin jar

`rascal-terminal-plugin/` is a Gradle IntelliJ Platform plugin project.
Whenever you change its source, rebuild the zip and reinstall it in
IntelliJ (Settings > Plugins > gear icon > Install Plugin from Disk...,
then restart when prompted) to pick up the change -- IntelliJ does not
hot-reload plugins from disk.

```bash
cd tools/intellij/rascal-terminal-plugin
export JAVA_HOME=~/.jdks/openjdk-26.0.2.1   # any JDK 17+; Gradle itself needs 17+
./gradlew buildPlugin
```

Output: `build/distributions/rascal-debugger-<version>.zip` (version from
`build.gradle.kts`).

To ship a new version to the rest of the team (rather than just testing
locally), see the release steps in
[Periteleios/intellij-plugin-rascal-debug](https://github.com/Periteleios/intellij-plugin-rascal-debug)'s
README -- that's the public repo hosting releases (see 2a above for why).

Notes:
- First build downloads a full IntelliJ IDEA IU platform artifact (matching
  `intellijIdea("...")` in `build.gradle.kts`) to populate the compile
  classpath -- this is slow once, cached after.
- `settings.gradle.kts` pins the IntelliJ Platform Gradle plugin version and
  wires up `dependencyResolutionManagement`; don't remove that in favor of a
  plain `repositories {}` block in `build.gradle.kts` without testing --
  this project needed it to resolve `intellijIdea(...)` at all.
- `./gradlew runIde` launches a disposable sandbox IntelliJ instance with the
  plugin pre-installed, useful for iterating without reinstalling into your
  real IDE each time.
- `.intellijPlatform/`, `.gradle/`, `.idea/`, and `build/` under
  `rascal-terminal-plugin/` are all gitignored -- if `git status` ever shows
  changes under any of those, you likely ran a build command from the wrong
  directory; don't commit them (one of them is a multi-MB local sandbox
  cache).
