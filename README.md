# IntelliJ setup for Rascal (highlighting + editing + debugging)

This directory makes Rascal (`.rsc`) files readable, editable, and
debuggable in IntelliJ IDEA. As of `rascal-debugger-plugin` 0.1.0,
**installing the plugin is all you need to do** -- it auto-configures
syntax highlighting, editing, and debugging on its own.

## Quick start

Prerequisite: build the project once so `target/classes` exists and the
Maven jars are in your local `~/.m2` repository:

```bash
./build.sh
```

Then install the plugin: Settings/Preferences > Plugins > gear icon (⚙) >
**Manage Plugin Repositories...** > **+** > add:

```
https://raw.githubusercontent.com/Periteleios/rascal-intellij-debugger-releases/main/updatePlugins.xml
```

Apply, then go to the **Marketplace** tab and search "Rascal Debugger"
(older releases may still show as "Rascal Terminal Commands") -- it should
show up (possibly labeled as coming from a custom repository rather than
the usual JetBrains vendor listing). Install it, restart when prompted.
Future releases show up as normal plugin updates from then on -- no manual
reinstalling.

If you're actively developing the plugin itself rather than just using it,
build and install it locally instead -- see "Building/updating the plugin
jar" below, then Settings > Plugins > gear icon > **Install Plugin from
Disk...**, restart when prompted.

That's it. Open any `.rsc` file -- e.g.
[Sanity.rsc](../../src/main/rascal/Sanity.rsc) -- and syntax highlighting,
diagnostics/hover/CodeLenses, and breakpoints/stepping should all just
work, against whichever Maven-based Rascal project is currently open (this
one included, but not required -- the classpath is computed from
whatever project is actually open, not hardcoded to this checkout).

### What gets auto-configured, and how

Three plugin classes, each registered via an IntelliJ or LSP4IJ extension
point -- worth knowing about if something doesn't work and you want to
know where to look in `idea.log`:

- **`RascalTextMateBundleProvider`** registers the syntax-highlighting
  grammar (`rascal-textmate-bundle/`, shipped as a plugin resource,
  extracted once to a real directory on first use -- TextMate bundles need
  an actual filesystem path, not a jar resource).
- **`RascalLanguageServerFactory`** registers the `.rsc` Language Server,
  computing its classpath from whichever project is currently open (the
  same computation "Import"/"Run in new Rascal terminal" already used).
- **`RascalProjectActivity`** auto-creates the "Rascal Attach" DAP
  Run/Debug configuration on project open, including the exact
  `*.rsc -> rascal` Mappings-tab entry that's easy to miss by hand and,
  when missed, causes a completely silent breakpoint failure (no error, no
  gutter dot). Idempotent: if a DAP configuration already exists (of any
  name), it leaves it alone rather than creating a duplicate.

If something doesn't work, check `idea.log` (Help > Show Log in
Files/Finder) for a `RascalTerminalSupport`/`RascalDebugPortFinder`/
`RascalDebugAttachConfigurator`/`RascalProjectActivity`/
`RascalLanguageServerFactory`/`RascalTextMateBundleProvider` entry -- every
failure path logs there.

`rascal-debugger-plugin/`'s own source is licensed under BSD 2-Clause --
see its [LICENSE](rascal-debugger-plugin/LICENSE) file.

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
export JAVA_HOME=~/.jdks/openjdk-26.0.2.1   # needs JDK 25+ (platform 2026.2.2's own jars are class v69); output still targets 17
./gradlew buildPlugin
```

Output: `build/distributions/rascal-debugger-<version>.zip` (version from
`build.gradle.kts`).

###### Other Gradle tasks worth knowing

**See the full list of available Gradle tasks**
```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/openjdk-26.0.2.1   # needs JDK 25+ (platform 2026.2.2's own jars are class v69); output still targets 17
./gradlew tasks
```

**Clean build output** -- deletes `build/` entirely: the compiled classes,
the instrumented bytecode, and the zip from `buildPlugin`. Use this if a
stale build is ever in doubt; `buildPlugin` alone does not wipe prior
output first.

```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/openjdk-26.0.2.1   # needs JDK 25+ (platform 2026.2.2's own jars are class v69); output still targets 17
./gradlew clean
```

**Launch a sandbox IDE with the plugin pre-installed** -- a disposable
IntelliJ instance, the fast loop for iterating without reinstalling into
your real IDE each time (see "Building/updating the plugin jar" above for
why a real install still needs a rebuild + "Install Plugin from Disk").
This is also the best way to verify the auto-configuration in "Quick
start" above actually works with zero prior setup, since the sandbox
starts with none of its own -- see this project's own commit history for
the exact log line (`RascalProjectActivity - Auto-created the "Rascal
Attach" DAP configuration for ...`) that proves the auto-creation path
actually ran, not just that a configuration happened to already exist.

```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/openjdk-26.0.2.1   # needs JDK 25+ (platform 2026.2.2's own jars are class v69); output still targets 17
./gradlew runIde
```

**Reset that sandbox instance** -- wipes its own state (config/plugins/
system dirs under `.intellijPlatform/sandbox/`) if `runIde` ever gets into
a broken state. Separate from `clean`, which doesn't touch it.

```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/openjdk-26.0.2.1   # needs JDK 25+ (platform 2026.2.2's own jars are class v69); output still targets 17
./gradlew cleanSandbox
```

**Verify IDE-version compatibility** -- runs the IntelliJ Plugin Verifier
against the `sinceBuild`/`untilBuild` range declared in `build.gradle.kts`.
Catches "this won't load on IDE version X" problems before shipping a
release.

```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/openjdk-26.0.2.1   # needs JDK 25+ (platform 2026.2.2's own jars are class v69); output still targets 17
./gradlew verifyPlugin
```

**Sanity-check the Gradle project setup** -- JDK version, `plugin.xml`
fields, target platform compatibility. Worth running after editing
`build.gradle.kts`.

```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/openjdk-26.0.2.1   # needs JDK 25+ (platform 2026.2.2's own jars are class v69); output still targets 17
./gradlew verifyPluginProjectConfiguration
```

**Run the unit test suite** -- none exist yet; this is the task to wire up
if/when tests are added under `src/test/java/`.

```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/openjdk-26.0.2.1   # needs JDK 25+ (platform 2026.2.2's own jars are class v69); output still targets 17
./gradlew test
```

To ship a new version to the rest of the team (rather than just testing
locally), see the release steps in
[Periteleios/rascal-intellij-debugger-releases](https://github.com/Periteleios/rascal-intellij-debugger-releases)'s
README -- that's the public repo hosting releases (see "Quick start"
above for why).

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
