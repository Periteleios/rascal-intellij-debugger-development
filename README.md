# IntelliJ setup for Rascal (highlighting + editing + debugging)

This directory makes Rascal (`.rsc`) files readable, editable, and
debuggable in IntelliJ IDEA. As of `rascal-debugger-plugin` 0.1.0,
**installing the plugin is all you need to do** -- it auto-configures
syntax highlighting, editing, and debugging on its own.

## Quick start


Prerequisite: a Project SDK of Java 11+ (File > Project Structure > Project >
SDK) -- IntelliJ injects this into every terminal's PATH/JAVA_HOME, and
`rascal-maven-plugin` requires 11+ to even load (an 8 SDK fails `mvn compile`
with `UnsupportedClassVersionError`). Then build the project once so
`target/classes` exists and the Maven jars are in your local `~/.m2`
repository:

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
Whenever you change its source, you need to:

* rebuild the zip
* reinstall it in IntelliJ
  - Settings > Plugins > gear icon > Install Plugin from Disk..., then restart when prompted.

This build needs a JDK **25 or higher** (platform 2026.2.2's own jars are class v69; the plugin's own bytecode still targets 17).

**Easiest option -- use IntelliJ's Gradle tool window instead of a manual `export`:**

Gradle tool window > gear icon > Gradle Settings > "Gradle JVM" dropdown. Pick or download a JDK 25+ there; it applies to every Gradle task run through the tool window, no terminal command needed.

**If you prefer the command line:**

1. Check what JDKs you already have -- the exact path varies by OS and by how the JDK was installed, so check more than one place:

```bash
ls ~/.jdks/                              # JetBrains-managed downloads (all platforms)
ls /Library/Java/JavaVirtualMachines/    # macOS system location (Homebrew, vendor installers, some IntelliJ downloads)
/usr/libexec/java_home -V                # macOS only -- lists JDKs registered with the system
```

2. If nothing 25+ shows up, download one via File > Project Structure > SDKs > + > Download JDK. **Amazon Corretto 26** is what this team standardizes on -- pick that if it's offered (any other 25+ vendor works too: OpenJDK, Temurin, etc.).
3. Set `JAVA_HOME` to the path IntelliJ actually installed it at (shown in the SDK's "JDK home path" field). On both Mac and Linux, IntelliJ's downloader lands the folder itself under `~/.jdks/<vendor-version>` with no OS/arch suffix in the name -- so once you've downloaded the same Corretto 26 build on both machines, that top-level folder name matches. Confirm it with `ls ~/.jdks/` on each machine (patch/build strings can drift slightly if you download weeks apart) rather than assuming it matches this README verbatim. One platform wrinkle: on **Mac**, the actual JDK (`bin/java`) sits nested under `<folder>/Contents/Home/`, not at the folder's top level (Linux's tarball is flat, so `bin/java` is right at the top there). The blocks below handle this automatically -- they set `JAVA_HOME` to the bare folder, then fall through to the nested path only if it exists -- so the same block works unmodified on both OSes:

```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/corretto-26.0.2.1
[ -d "$JAVA_HOME/Contents/Home" ] && export JAVA_HOME="$JAVA_HOME/Contents/Home"
./gradlew buildPlugin
```

Output: `build/distributions/rascal-debugger-<version>.zip` (version from
`build.gradle.kts`).

> Note: this JDK 25+ requirement is separate from the sample Rascal project's own JDK requirement (11+, for `mvn`/`rascal-maven-plugin`). Both can surface as "wrong JDK" errors, but they're two different projects with two different needs.

###### Other Gradle tasks worth knowing

**See the full list of available Gradle tasks**
```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/corretto-26.0.2.1
[ -d "$JAVA_HOME/Contents/Home" ] && export JAVA_HOME="$JAVA_HOME/Contents/Home"
./gradlew tasks
```

**Clean build output** -- deletes `build/` entirely: the compiled classes,
the instrumented bytecode, and the zip from `buildPlugin`. Use this if a
stale build is ever in doubt; `buildPlugin` alone does not wipe prior
output first.

```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/corretto-26.0.2.1
[ -d "$JAVA_HOME/Contents/Home" ] && export JAVA_HOME="$JAVA_HOME/Contents/Home"
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
export JAVA_HOME=~/.jdks/corretto-26.0.2.1
[ -d "$JAVA_HOME/Contents/Home" ] && export JAVA_HOME="$JAVA_HOME/Contents/Home"
./gradlew runIde
```

**Reset that sandbox instance** -- wipes its own state (config/plugins/
system dirs under `.intellijPlatform/sandbox/`) if `runIde` ever gets into
a broken state. Separate from `clean`, which doesn't touch it.

```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/corretto-26.0.2.1
[ -d "$JAVA_HOME/Contents/Home" ] && export JAVA_HOME="$JAVA_HOME/Contents/Home"
./gradlew cleanSandbox
```

**Verify IDE-version compatibility** -- runs the IntelliJ Plugin Verifier
against the `sinceBuild`/`untilBuild` range declared in `build.gradle.kts`.
Catches "this won't load on IDE version X" problems before shipping a
release.

```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/corretto-26.0.2.1
[ -d "$JAVA_HOME/Contents/Home" ] && export JAVA_HOME="$JAVA_HOME/Contents/Home"
./gradlew verifyPlugin
```

**Sanity-check the Gradle project setup** -- JDK version, `plugin.xml`
fields, target platform compatibility. Worth running after editing
`build.gradle.kts`.

```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/corretto-26.0.2.1
[ -d "$JAVA_HOME/Contents/Home" ] && export JAVA_HOME="$JAVA_HOME/Contents/Home"
./gradlew verifyPluginProjectConfiguration
```

**Run the unit test suite** -- none exist yet; this is the task to wire up
if/when tests are added under `src/test/java/`.

```bash
cd tools/intellij/rascal-debugger-plugin
export JAVA_HOME=~/.jdks/corretto-26.0.2.1
[ -d "$JAVA_HOME/Contents/Home" ] && export JAVA_HOME="$JAVA_HOME/Contents/Home"
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
- `gradle.properties` sets `org.gradle.java.installations.auto-detect=false`
  -- without it, Gradle scans every JDK on the machine
  (`/Library/Java/JavaVirtualMachines/`, `~/.jdks/`, SDKMAN, etc.) on every
  build looking for one matching its toolchain requirement, which is slow
  and can trigger macOS Gatekeeper "Verifying ..." popups for old JDKs it
  hasn't touched in a while. We always set `JAVA_HOME` explicitly before
  building, so auto-detection has nothing to add -- if a build ever
  legitimately needs a JDK found only by auto-detection, flip this back to
  `true` (or delete the line) rather than fighting it.
