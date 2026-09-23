# IntelliJ setup for Rascal (highlighting + editing + debugging)

This directory makes Rascal (`.rsc`) files readable and editable in
IntelliJ IDEA. 

1. **Syntax highlighting** (otherwise `.rsc` renders as plain,
   uncolored text) -- via a TextMate bundle, installed by a one-time script.
2. **Editing** (syntax errors, hover, completion, CodeLenses) -- via the
   [LSP4IJ](https://plugins.jetbrains.com/plugin/23257-lsp4ij) plugin and the
   `run-rsc-lsp.sh` launcher script.
3. **Debugging** (breakpoints, stepping, variable inspection) -- via
   `rascal-debugger-plugin/` (published as **Rascal Debugger** in its own
   [public releases repo](https://github.com/Periteleios/rascal-intellij-debugger-releases)),
   plus an LSP4IJ DAP ("Debug Adapter Protocol") Run/Debug configuration.

Installing the "Rascal Debugger" plugin by itself (part 3) gets you
breakpoints/stepping, the "Import"/"Run in new Rascal terminal" CodeLenses,
and "Go to Definition" into the standard library -- it does **not** give you
syntax highlighting or diagnostics/completion; those are parts 1 and 2,
done separately, once, in this same checkout. Do all three before expecting
anything to work end-to-end.

Prerequisite for both: build the project once so `target/classes` exists
and the Maven jars are in your local `~/.m2` repository:

```bash
./build.sh
```

---

# 1. Syntax highlighting

IntelliJ has no built-in Rascal support, so without this `.rsc` files render
as plain, uncolored text. <br>
It will look for your (most recently modified `IntelliJIdeaXXX`) profile file under `~/.config/JetBrains` or
`~/Library/Application Support/JetBrains`).<br>
Pass one explicitly only if you have place it elsewhere.

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
[docs/intellij_rascal_highlighting.md](docs/intellij_rascal_highlighting.md)
for what the script does and why the grammar needed patching.

---

# 2. Editing: LSP4IJ language servers

1. Install **LSP4IJ** from IntelliJ's Marketplace (Settings > Plugins >
   Marketplace > search "LSP4IJ").
2. Make the launcher script executable (one-time):
   ```bash
   chmod +x tools/intellij/run-rsc-lsp.sh
   ```
3. Settings > Languages & Frameworks > Language Servers > **+** (add a new
   server):

   | | `.rsc` server |
   |---|---|
   | Server tab, Command | absolute path to `tools/intellij/run-rsc-lsp.sh` |
   | Mappings tab, file name pattern | `*.rsc` |
   | Communication | stdio (default, leave as-is) |

4. Open any `.rsc` file under `src/main/rascal/` -- for example
   [Sanity.rsc](../../src/main/rascal/Sanity.rsc) (module `Sanity`). You
   should see diagnostics, hover, and (above the module/`main()`
   declarations) two CodeLenses: "Import in new Rascal terminal" and "Run
   in new Rascal terminal". Clicking either will error ("Cannot execute
   'rascalmpl.importModule' command! ... needs to be contributed by an
   IntelliJ plugin") until you also do part 3 below.

### Running these scripts from a copy outside this checkout

Both scripts (`run-rsc-lsp.sh`, `compute-classpath.sh`) resolve "this
project" from their own file location by default, but that's overridable:
set `RASCAL_PROJECT_ROOT` (that Language Server entry's **Environment
variables** field, not the Command field) to an absolute path to any
Maven-based Rascal project checkout -- the underlying language server jar
has no idea which project it's serving, so it works with any such
project, not just this one. A copy of these scripts living anywhere
else will use whatever it's pointed at instead of computing a location
from their own. This is how they're mirrored, still fully functional,
into the
[public rascal-debugger-plugin releases repo](https://github.com/Periteleios/rascal-intellij-debugger-releases)
alongside the syntax-highlighting bundle -- see that repo's own README.
There's no way around needing an actual Maven-built Rascal project
checkout somewhere on disk (the language server's own compiled
implementation and its interpreted modules both come from that build),
but the scripts no longer have to physically live inside it.

"Go to Definition" into standard library symbols (`IO::println`,
`List::size`, `Set`, `String`, `util::FileSystem`, etc.) needs
`rascal-debugger-plugin` **0.2.0+** (see part 3 below) -- Rascal's compiled
stdlib bakes `std:///`-scheme locations into its definitions, which LSP4IJ
has no built-in way to resolve; the plugin registers a `VirtualFileSystem`
that bridges it. Without that plugin (or on an older version), clicking
into a stdlib symbol silently does nothing.

<span style="color:orange">Both scripts take the jar versions from this project's`pom.xml`
e.g., `<rascal.version>`, `<rascal.lsp.version>`, `<typepal.version>`</span> <br>-- if those
change, update the `RASCAL_JAR`/`LSP_JAR`/`TYPEPAL_JAR` paths at the top of
each script to match.

---

# 3. Debugging: `rascal-debugger-plugin` + LSP4IJ DAP config

Unlike parts 1 and 2, nothing here is specific to this checkout: the
"Import"/"Run in new Rascal terminal" CodeLenses compute their classpath
from whatever project is currently open in IntelliJ, via that project's
own `pom.xml` (cached under its own `target/`) -- not from anything
hardcoded to `adept-base`. The DAP breakpoint-handling fix and the
`std:///` stdlib bridge were already fully generic. So this whole plugin
works against any Maven-based Rascal project, this one included.

`rascal-debugger-plugin/`'s own source (every Java file, plus
`build.gradle.kts`/`settings.gradle.kts`) is licensed under BSD 2-Clause
-- see its [LICENSE](rascal-debugger-plugin/LICENSE) file. The four
scripts directly in this directory (`setup-intellij-rascal-
highlighting.sh`, `run-rsc-lsp.sh`, `compute-classpath.sh`) are covered
the same way, under their own
[LICENSE](LICENSE) file one level up -- so any other project or company
can use, modify, or redistribute any of this freely. This is separate
from the syntax-highlighting bundle in part 1
(`rascal-textmate-bundle/`), which is a derivative of a
third-party project and not covered by either license (see that
project's own README for its provenance).

### 3a. Install the plugin

One-time setup: Settings/Preferences > Plugins > gear icon (⚙) > **Manage
Plugin Repositories...** > **+** > add:

```
https://raw.githubusercontent.com/Periteleios/rascal-intellij-debugger-releases/main/updatePlugins.xml
```

Apply, then go to the **Marketplace** tab and search "Rascal Debugger"
(older releases may still show as "Rascal Terminal Commands") -- it should
show up (possibly labeled as coming from a custom repository rather than
the usual JetBrains vendor listing). Install it, restart when prompted.
Future releases show up as normal plugin updates from then on -- no manual
reinstalling.

(This repo -- and the plugin's actual source in `rascal-debugger-plugin/`
-- is public too now, but releases are still hosted separately, in that
dedicated repo, since IntelliJ's plugin-repository feature needs a
static `updatePlugins.xml` + release assets to auto-update from, not a
source checkout. See that repo's own README for the release process if
you're cutting a new version.)

If you're actively developing the plugin itself rather than just using it,
build and install it locally instead -- see "Building/updating the plugin
jar" below, then Settings > Plugins > gear icon > **Install Plugin from
Disk...**, restart when prompted.

### 3b. Create one LSP4IJ DAP "Attach" Run/Debug configuration (one-time, per project)

This only needs a destination to attach to -- the plugin fills in the actual
port automatically every time you run something, so the port you enter here
is just a placeholder.

This Run/Debug configuration is stored per-project (under that project's
own `.idea/`), not per-machine or per-plugin-install -- it does **not**
carry over between different projects or fresh checkouts, even on the same
machine. If you see a notification like "No existing LSP4IJ DAP
configuration found -- create one, then paste this port in" (with a port
number already copied to your clipboard), it means you're hitting this
step for the first time in *this* project: do steps 1-5 below once, using
the clipboard port for step 4, and it won't ask again for this project.

1. Run > Edit Configurations... > **+** > **Debug Adapter Protocol** (added
   by LSP4IJ).
2. Give it a name (e.g. "Rascal Attach").
3. On the `Server` tab, at `Use an existing Adapter Server`
   - select "Rascal Debugger" from the drop-down menu. <br>
   it makes LSP4IJ construct `RascalDebugAdapterDescriptor` /
   `RascalBreakpointHandler` for the session (registered by this plugin via
   the `com.redhat.devtools.lsp4ij.debugAdapterServer` extension point)
   instead of its own stock descriptor/handler.
4. On the `Mappings` tab ("Declare file associations to allow setting
   breakpoints"), open the **File name patterns** sub-tab, click **+**, and
   add `*.rsc` with Language Id `rascal`. <br>
   For confirmation, check the `serverMappings` xml tag in
   `.idea/workspace.xml`
   ```xml
   <option name="serverMappings">
     <list>
       <ServerMappingSettings languageId="rascal">
         <option name="fileNamePatterns">
           <list><option value="*.rsc" /></list>
         </option>
       </ServerMappingSettings>
     </list>
   </option>
   ```
5. On the `Configuration` tab, 
   - set `Debug Mode` to **Attach**
   - address `localhost`
   - port anything (e.g. `0`) -- it gets overwritten before every launch.
6. Apply/OK, **then restart IntelliJ**. <br>
   The Mappings change above doesn't reliably take effect for an editor
   that's already open -- restarting is what made it actually work when
   this was set up. You do not need to run this configuration yourself
   afterward -- the plugin launches it automatically.

### 3c. Use it (also the verification step for 3a/3b)

Open any `.rsc` file with a `main()` function -- e.g.
[Sanity.rsc](../../src/main/rascal/Sanity.rsc) -- and click "Run in new
Rascal terminal" above it. A new terminal tab opens, imports the module,
and enables the interpreter's debugger; the plugin then:

- captures that terminal's real process id,
- polls for the new port `org.rascalmpl.dap.DebugSocketServer` opens,
- writes that port into the DAP Run/Debug configuration from 3b and launches it.

A notification balloon confirms this ("Attaching Rascal debugger on port
..."). Set a breakpoint and type `main(...)` (with whatever arguments you
want) at the terminal's `rascal>` prompt -- execution should stop there.
Try the walkthrough in `Sanity.rsc`'s own `@doc{}` comment for a
breakpoint + cross-module step + uncaught-exception scenario to test
against.

If the notification instead says the port lookup failed or was skipped, or
no DAP Run/Debug configuration was found, check `idea.log` (Help > Show Log in
Files/Finder) for a `RascalTerminalSupport`/`RascalDebugPortFinder`/
`RascalDebugAttachConfigurator` entry -- every failure path logs there.

---


<br>

### Further Reading

###### Building/updating the plugin jar

`rascal-debugger-plugin/` is a Gradle IntelliJ Platform plugin project.<br>
IntelliJ does not hot-reload plugins from disk.<br>
Whenever you change its source, you need to 
* rebuild the zip 
* reinstall it in IntelliJ 
  - Settings > Plugins > gear icon > Install Plugin from Disk..., then restart when prompted.

```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/openjdk-26.0.2.1   # any JDK 17+; Gradle itself needs 17+
./gradlew buildPlugin
```

Output: `build/distributions/rascal-debugger-<version>.zip` (version from
`build.gradle.kts`).

###### Other Gradle tasks worth knowing

**See the full list of available Gradle tasks**
```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/openjdk-26.0.2.1   # any JDK 17+; Gradle itself needs 17+
./gradlew tasks
```

**Clean build output** -- deletes `build/` entirely: the compiled classes,
the instrumented bytecode, and the zip from `buildPlugin`. Use this if a
stale build is ever in doubt; `buildPlugin` alone does not wipe prior
output first.

```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/openjdk-26.0.2.1   # any JDK 17+; Gradle itself needs 17+
./gradlew clean
```

**Launch a sandbox IDE with the plugin pre-installed** -- a disposable
IntelliJ instance, the fast loop for iterating without reinstalling into
your real IDE each time (see "Building/updating the plugin jar" above for
why a real install still needs a rebuild + "Install Plugin from Disk").

```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/openjdk-26.0.2.1   # any JDK 17+; Gradle itself needs 17+
./gradlew runIde
```

**Reset that sandbox instance** -- wipes its own state (config/plugins/
system dirs under `.intellijPlatform/sandbox/`) if `runIde` ever gets into
a broken state. Separate from `clean`, which doesn't touch it.

```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/openjdk-26.0.2.1   # any JDK 17+; Gradle itself needs 17+
./gradlew cleanSandbox
```

**Verify IDE-version compatibility** -- runs the IntelliJ Plugin Verifier
against the `sinceBuild`/`untilBuild` range declared in `build.gradle.kts`.
Catches "this won't load on IDE version X" problems before shipping a
release.

```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/openjdk-26.0.2.1   # any JDK 17+; Gradle itself needs 17+
./gradlew verifyPlugin
```

**Sanity-check the Gradle project setup** -- JDK version, `plugin.xml`
fields, target platform compatibility. Worth running after editing
`build.gradle.kts`.

```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/openjdk-26.0.2.1   # any JDK 17+; Gradle itself needs 17+
./gradlew verifyPluginProjectConfiguration
```

**Run the unit test suite** -- none exist yet; this is the task to wire up
if/when tests are added under `src/test/java/`.

```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/openjdk-26.0.2.1   # any JDK 17+; Gradle itself needs 17+
./gradlew test
```

To ship a new version to the rest of the team (rather than just testing
locally), see the release steps in
[Periteleios/rascal-intellij-debugger-releases](https://github.com/Periteleios/rascal-intellij-debugger-releases)'s
README -- that's the public repo hosting releases (see 3a above for why).

Notes:
- First build downloads a full IntelliJ IDEA IU platform artifact (matching
  `intellijIdea("...")` in `build.gradle.kts`) to populate the compile
  classpath -- this is slow once, cached after.
- `settings.gradle.kts` pins the IntelliJ Platform Gradle plugin version and
  wires up `dependencyResolutionManagement`; don't remove that in favor of a
  plain `repositories {}` block in `build.gradle.kts` without testing --
  this project needed it to resolve `intellijIdea(...)` at all.
- `.intellijPlatform/`, `.gradle/`, `.idea/`, and `build/` under
  `rascal-debugger-plugin/` are all gitignored -- if `git status` ever shows
  changes under any of those, you likely ran a build command from the wrong
  directory; don't commit them (one of them is a multi-MB local sandbox
  cache).
