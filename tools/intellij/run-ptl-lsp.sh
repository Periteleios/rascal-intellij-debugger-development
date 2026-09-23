#!/usr/bin/env bash
# Copyright (c) 2026, Periteleios
# All rights reserved. This file is licensed under the BSD 2-Clause
# License -- see the LICENSE file in this directory.
#
# Launches Rascal's ParametricLanguageServer registered for PTL (.ptl) files,
# over stdio, for use as an LSP4IJ "Language Server" definition in IntelliJ.
#
#   Settings > Languages & Frameworks > Language Servers > +
#     Server tab:   Command = <path to this script>
#     Mappings tab: file name pattern *.ptl
#     (communication stays stdio, the default)
#
# LIMITATION: the PATH_CONFIG below only puts this checkout's own
# src/main/rascal on the module search path -- fine for editing the PTL
# language's own example/test fixtures (e.g.
# src/main/rascal/lang/ptl/examples/accounting.ptl), but NOT for editing a
# milestone's own PTL files under milestones/<name>/ -- those `import staging`
# (or any other bare project-relative import) can never resolve, since that
# milestone's own staging.ptl isn't on this server's srcs list at all. This
# is a real gap, not a caching/stale-server issue -- restarting the server
# will never fix it. `ptl build`/gen-build-run.sh don't hit this because they
# compute a fresh PathConfig scoped to the one milestone being built each
# time, which this static script-launched server doesn't do.
#
# Set PTL_MILESTONE_ROOT (in this Language Server's "Environment variables"
# field in IntelliJ, not the Command field) to one milestone's absolute path
# to scope this server to that milestone instead, e.g.:
#   PTL_MILESTONE_ROOT=/home/jan-abt/Code/adept-base/milestones/002_dimaccount_rank_churn_top_level_views
# Only one milestone at a time -- each milestone has its own staging.ptl, and
# putting more than one on the srcs list at once would make bare imports like
# `staging` ambiguous rather than resolving to the right one. Switching which
# milestone you're editing means changing this variable and restarting the
# server (see this project's tools/intellij/README.md for how).
#
# See run-rsc-lsp.sh for why -Drascal.lsp.deploy=true and
# -Drascal.fallbackResolver=... are both required -- verified live against
# this project: initialize/didOpen/publishDiagnostics all confirmed working
# for src/main/rascal/lang/ptl/examples/accounting.ptl. Both flags are taken
# from how this project's own VS Code extension launches the same jar (see
# lsp-client/src/extension.ts, buildPtlServerOptions) -- that extension
# additionally bundles a project-specific ptl-lsp.jar for distribution to
# users without a checkout; this script instead points srcs/libs straight at
# this checkout's own Maven build, which is simpler for local development.
#
# PATH_CONFIG below is the actual, resolved PathConfig this project's
# lang::ptl::LanguageServer::ptlLangForIDE() produces -- captured by running
# it directly via RascalShell against this checkout, not a guess. The
# checkout-specific bits (this project's own target/classes and
# src/main/rascal, plus the two jars also referenced by file:// rather than
# mvn://) are substituted in below from $PROJECT_ROOT/$RASCAL_JAR/$LSP_JAR,
# so this works from any checkout location/machine without editing. Only the
# STRUCTURE needs recapturing (which libs/srcs/mvn:// entries appear at all)
# if PTL's language server dependencies actually change:
#
#   1. Add a throwaway module, e.g. src/main/rascal/ScratchProbe.rsc:
#        module ScratchProbe
#        import lang::ptl::LanguageServer;
#        import IO;
#        void main(list[str] args) { println(ptlLangForIDE()); }
#
#   2. From the project root:
#        CP="$HOME/.m2/repository/org/rascalmpl/rascal/0.42.2/rascal-0.42.2.jar:\
#$HOME/.m2/repository/org/rascalmpl/rascal-lsp/2.22.4/rascal-lsp-2.22.4.jar:\
#$HOME/.m2/repository/org/rascalmpl/typepal/0.16.7/typepal-0.16.7.jar:target/classes"
#        java -cp "$CP" org.rascalmpl.shell.RascalShell ScratchProbe
#
#   3. The printed value is `language(pathConfig(...), "PTL Grammar", ...)` --
#      copy just the `pathConfig(...)` part into PATH_CONFIG below, then
#      replace this machine's absolute paths with the ${PROJECT_ROOT}/
#      ${RASCAL_JAR}/${LSP_JAR} substitutions (see occurrences below) so it
#      stays portable, then delete the throwaway module.
#
# Jar versions below must match <rascal.version>/<rascal.lsp.version>/
# <typepal.version> in the project's pom.xml.
#
# CP (the actual -cp this JVM launches with) comes from compute-classpath.sh
# -- this project's full Maven-resolved dependency list, cached under
# target/. This is a separate concern from PATH_CONFIG further down (that's
# Rascal's own module-resolution bookkeeping for `mvn://...` imports, with
# no bearing on what's actually on this JVM's classpath): interpreted code
# that touches `@javaClass{com.periteleios.websocket.RascalWebSock}`
# (declared in foreignFunctionInterface/FFI.rsc -- PATH_CONFIG below already
# lists its dependencies, confirming they're needed here too) needs those
# jars for real, on -cp, or class loading fails with NoClassDefFoundError.
# See compute-classpath.sh's own comment for the full story.
#
# Portable the same way run-rsc-lsp.sh is: set ADEPT_BASE_ROOT (in this
# Language Server's "Environment variables" field in IntelliJ, not the
# Command field) to point this script at an adept-base checkout other than
# the one it happens to live in -- see run-rsc-lsp.sh's own comment on why
# an actual checkout is still required somewhere.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -n "${ADEPT_BASE_ROOT:-}" ]; then
  PROJECT_ROOT="$(cd "$ADEPT_BASE_ROOT" && pwd)"
else
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

RASCAL_JAR="$HOME/.m2/repository/org/rascalmpl/rascal/0.42.2/rascal-0.42.2.jar"
LSP_JAR="$HOME/.m2/repository/org/rascalmpl/rascal-lsp/2.22.4/rascal-lsp-2.22.4.jar"
PROJECT_CLASSES="$PROJECT_ROOT/target/classes"

CP="$("$SCRIPT_DIR/compute-classpath.sh"):$PROJECT_CLASSES"

# Optional: scope this server to one milestone's own PTL project root (see the
# LIMITATION note above) instead of only this checkout's src/main/rascal.
MILESTONE_SRC=""
if [ -n "${PTL_MILESTONE_ROOT:-}" ]; then
    if [ ! -d "$PTL_MILESTONE_ROOT" ]; then
        echo "Warning: PTL_MILESTONE_ROOT='$PTL_MILESTONE_ROOT' is not a directory; ignoring, falling back to this checkout's own src/main/rascal only." >&2
    else
        MILESTONE_SRC="|file://$(cd "$PTL_MILESTONE_ROOT" && pwd)|,"
    fi
fi

PATH_CONFIG="pathConfig(bin=|file://${PROJECT_CLASSES}|,libs=[|lib://ptl-lsp|,|lib://rascal-lsp|,|lib://rascal|,|file://${RASCAL_JAR}|,|mvn://com.fasterxml.jackson.core--jackson-databind--2.15.2|,|mvn://com.networknt--json-schema-validator--1.0.87|,|mvn://org.rascalmpl--typepal--0.16.7|,|mvn://io.socket--socket.io-server--3.0.2|,|mvn://commons-io--commons-io--2.11.0|,|mvn://org.eclipse.jetty--jetty-server--9.4.19.v20190610|,|mvn://org.eclipse.jetty--jetty-servlet--9.4.19.v20190610|,|mvn://org.eclipse.jetty--jetty-servlets--9.4.19.v20190610|,|mvn://org.eclipse.jetty.websocket--websocket-server--9.4.19.v20190610|,|mvn://io.socket--engine.io-server--5.0.0|,|mvn://io.socket--engine.io-server-jetty--5.0.0|,|mvn://org.apache.commons--commons-configuration2--2.11.0|,|mvn://commons-beanutils--commons-beanutils--1.9.4|,|mvn://com.fasterxml.jackson.core--jackson-annotations--2.15.2|,|mvn://com.fasterxml.jackson.core--jackson-core--2.15.2|,|mvn://junit--junit--4.13.1|,|mvn://javax.servlet--javax.servlet-api--3.1.0|,|mvn://org.eclipse.jetty--jetty-http--9.4.19.v20190610|,|mvn://org.eclipse.jetty--jetty-io--9.4.19.v20190610|,|mvn://org.eclipse.jetty--jetty-security--9.4.19.v20190610|,|mvn://org.eclipse.jetty--jetty-continuation--9.4.19.v20190610|,|mvn://org.eclipse.jetty--jetty-util--9.4.19.v20190610|,|mvn://org.eclipse.jetty.websocket--websocket-common--9.4.19.v20190610|,|mvn://org.eclipse.jetty.websocket--websocket-client--9.4.19.v20190610|,|mvn://org.eclipse.jetty.websocket--websocket-servlet--9.4.19.v20190610|,|mvn://org.json--json--20190722|,|mvn://org.apache.commons--commons-lang3--3.14.0|,|mvn://org.apache.commons--commons-text--1.12.0|,|mvn://commons-logging--commons-logging--1.3.2|,|mvn://commons-collections--commons-collections--3.2.2|,|mvn://org.hamcrest--hamcrest-core--1.3|,|mvn://org.eclipse.jetty.websocket--websocket-api--9.4.19.v20190610|,|mvn://org.eclipse.jetty--jetty-client--9.4.19.v20190610|,|mvn://org.eclipse.jetty--jetty-xml--9.4.19.v20190610|,|file://${LSP_JAR}|],srcs=[|std:///|,${MILESTONE_SRC}|mvn://org.rascalmpl--typepal--0.16.7/src|,|file://${PROJECT_ROOT}/src/main/rascal|,|jar+file://${LSP_JAR}!/library|])"

JSON=$(cat <<EOF
{"pathConfig":"${PATH_CONFIG}","name":"PTL Grammar","extensions":["ptl"],"mainModule":"lang::ptl::LanguageServer","mainFunction":"ptlContributions"}
EOF
)

exec java \
  -Drascal.lsp.deploy=true \
  -Drascal.fallbackResolver=org.rascalmpl.vscode.lsp.uri.FallbackResolver \
  -cp "$CP" org.rascalmpl.vscode.lsp.parametric.ParametricLanguageServer "$JSON"
