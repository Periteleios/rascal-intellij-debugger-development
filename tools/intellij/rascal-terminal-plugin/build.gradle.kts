/*
 * Copyright (c) 2026, Periteleios
 * All rights reserved. This file is licensed under the BSD 2-Clause
 * License -- see the LICENSE file in this directory.
 */

plugins {
    id("java")
    id("org.jetbrains.intellij.platform")
}

group = "com.periteleios"
version = "0.6.0"

dependencies {
    intellijPlatform {
        intellijIdea("2026.2.2")
        bundledPlugin("org.jetbrains.plugins.terminal")
        plugin("com.redhat.devtools.lsp4ij", "0.21.0")
    }
}

intellijPlatform {
    pluginConfiguration {
        id = "com.periteleios.rascal-terminal"
        name = "Rascal Debugger"
        version = project.version.toString()
        description = "Adds Rascal debugging support to IntelliJ via LSP4IJ: 'Import'/'Run in new Rascal terminal' CodeLenses that open a real Rascal REPL (and, for 'Run', turn on the interpreter's debugger), plus a 'Rascal Debugger' DAP server that fixes a per-file breakpoint sync bug in LSP4IJ 0.21.0's stock DAP breakpoint handler. Works with any Maven-based Rascal project."
        ideaVersion {
            sinceBuild = "242"
        }
    }
}

tasks {
    withType<JavaCompile> {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }
}
