#!/usr/bin/env bash
# Copyright (c) 2026, Periteleios
# All rights reserved. This file is licensed under the BSD 2-Clause
# License -- see the LICENSE file in this directory.
#
# Computes (and caches) this project's full Maven-resolved dependency
# classpath, for tools/intellij/run-rsc-lsp.sh, run-ptl-lsp.sh, and the
# rascal-terminal-plugin's "Run/Import in new Rascal terminal" action to
# share.
#
# Previously each of those three hand-maintained its own hardcoded jar
# list (rascal/rascal-lsp/typepal, then later also org.json/io.socket/Jetty
# for foreignFunctionInterface::FFI's RascalWebSock), duplicated across two
# bash scripts and one Java source file. They silently drifted out of sync
# -- a fix for a missing-jar NoClassDefFoundError landed in two of the three
# copies and the bug kept happening via the third. This script exists so
# there is exactly one place that computes the answer.
#
# Prints ONE line to stdout: the classpath (jar paths joined by the
# platform path separator). Does NOT include target/classes -- callers
# append that themselves (this script only knows about *dependencies*,
# not the project's own compiled output).
#
# Usage:
#   tools/intellij/compute-classpath.sh
#
# Caching: the computed classpath is cached in
# target/rascal-ide-classpath.txt and reused as long as it's newer than
# pom.xml (recomputing on every invocation would add several seconds to
# every LSP server launch and every "Run in new Rascal terminal" click).
# Delete that file, or touch pom.xml, to force a recompute.
#
# A fresh computation shells out to `mvn dependency:build-classpath`,
# which needs network access the first time any given dependency version
# hasn't been resolved into ~/.m2 before.
#
# Portable the same way run-rsc-lsp.sh/run-ptl-lsp.sh are: set
# ADEPT_BASE_ROOT to point this at an adept-base checkout other than the
# one this script happens to live in. See those scripts' own comments.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -n "${ADEPT_BASE_ROOT:-}" ]; then
  PROJECT_ROOT="$(cd "$ADEPT_BASE_ROOT" && pwd)"
else
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
POM="$PROJECT_ROOT/pom.xml"
CACHE_FILE="$PROJECT_ROOT/target/rascal-ide-classpath.txt"

if [ -f "$CACHE_FILE" ] && [ "$CACHE_FILE" -nt "$POM" ]; then
    cat "$CACHE_FILE"
    exit 0
fi

mkdir -p "$PROJECT_ROOT/target"

if ! mvn -q -f "$POM" dependency:build-classpath -Dmdep.outputFile="$CACHE_FILE" 1>&2; then
    echo "error: 'mvn dependency:build-classpath' failed -- see output above. A stale/incomplete $CACHE_FILE is not left behind." >&2
    rm -f "$CACHE_FILE"
    exit 1
fi

cat "$CACHE_FILE"
