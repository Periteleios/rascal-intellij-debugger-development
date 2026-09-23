#!/usr/bin/env bash
# Copyright (c) 2026, Periteleios
# All rights reserved. This file is licensed under the BSD 2-Clause
# License -- see the LICENSE file in this directory.
#
# Launches Rascal's base LSP server (for editing .rsc files) over stdio,
# for use as an LSP4IJ "Language Server" definition in IntelliJ.
#
#   Settings > Languages & Frameworks > Language Servers > +
#     Server tab:   Command = <path to this script>
#     Mappings tab: file name pattern *.rsc
#     (communication stays stdio, the default)
#
# Two system properties are required, both taken from how this project's own
# VS Code extension launches the same jar (see lsp-client/src/extension.ts,
# buildPtlServerOptions):
#  1. -Drascal.lsp.deploy=true switches BaseLanguageServer from its dev-mode
#     TCP-socket-on-port-8888 path (which collides with this project's own
#     `hue` docker container) to stdio.
#  2. -Drascal.fallbackResolver=...FallbackResolver tells the server which
#     class to construct as its FallbackResolver singleton. Without it, the
#     server crashes immediately on any request with "FallbackResolver
#     accessed before initialization" -- that singleton is otherwise only
#     ever constructed by VS Code-extension-side glue, which doesn't exist
#     when launching the jar standalone like this.
#
# The classpath comes from compute-classpath.sh -- this project's full
# Maven-resolved dependency list, cached under target/. This whole JVM
# process also hosts every "Run in new Rascal terminal" REPL
# (rascal-terminal-plugin drives it through this same server), so it needs
# not just rascal/rascal-lsp/typepal but everything any interpreted module
# might touch via @javaClass -- e.g. foreignFunctionInterface/FFI.rsc's
# RascalWebSock needs org.json/io.socket/Jetty. Hardcoding that list by hand
# here (and separately in run-ptl-lsp.sh, and separately again in the
# plugin's RascalTerminalSupport.java) is exactly how this broke before: a
# fix landed in two of the three copies and the bug kept happening via the
# third. See compute-classpath.sh's own comment for the full story.
#
# This script itself is portable -- it can be run from a location other
# than tools/intellij/ inside this checkout (e.g. hosted alongside the
# rascal-terminal-plugin's own public releases repo) by setting
# ADEPT_BASE_ROOT (in this Language Server's "Environment variables" field
# in IntelliJ, not the Command field) to an absolute path to an actual
# adept-base checkout. There's no way around needing one somewhere on
# disk -- this server's own compiled implementation (rascal-lsp) and this
# project's interpreted modules both come from that checkout's Maven
# build -- but the script no longer has to physically live inside it.
# Unset (the default when run from within this checkout), it resolves the
# project root from its own location exactly as before.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -n "${ADEPT_BASE_ROOT:-}" ]; then
  PROJECT_ROOT="$(cd "$ADEPT_BASE_ROOT" && pwd)"
else
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
PROJECT_CLASSES="$PROJECT_ROOT/target/classes"

CP="$("$SCRIPT_DIR/compute-classpath.sh"):$PROJECT_CLASSES"

exec java \
  -Drascal.lsp.deploy=true \
  -Drascal.fallbackResolver=org.rascalmpl.vscode.lsp.uri.FallbackResolver \
  -cp "$CP" org.rascalmpl.vscode.lsp.rascal.RascalLanguageServer
