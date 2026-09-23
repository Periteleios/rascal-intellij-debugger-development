/*
 * Copyright (c) 2026, Periteleios
 * All rights reserved. This file is licensed under the BSD 2-Clause
 * License -- see the LICENSE file in this directory.
 */
package com.periteleios.rascalterminal;

import java.io.IOException;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

/**
 * Finds the TCP port org.rascalmpl.dap.DebugSocketServer bound for a given
 * process, without shelling out to `ps`/`ss`. DebugSocketServer picks the
 * port itself via `new ServerSocket(0)` (an OS-assigned ephemeral port) and,
 * per the decompiled bytecode of org.rascalmpl.ideservices.IDEServices,
 * never reports it anywhere a bare org.rascalmpl.shell.RascalShell process
 * can surface it (registerDebugServerPort/startDebuggingSession are no-op
 * default methods unless the caller supplies its own IDEServices, which
 * RascalShell doesn't). So the only way to learn the port is to look at the
 * OS's own view of that process's sockets directly -- this reads it straight
 * out of /proc rather than parsing `ss`/`lsof` output.
 */
final class RascalDebugPortFinder {

    private RascalDebugPortFinder() {
    }

    /**
     * Snapshot of ports the process currently has LISTENing, before triggering
     * debug mode. Always mutable (even when empty) -- waitForNewListeningPort
     * calls removeAll() on results of this method, which throws
     * UnsupportedOperationException against an immutable Set.of() (confirmed
     * live: this was actually happening on every call before a debug port
     * existed yet, i.e. essentially always, since we snapshot immediately
     * after the terminal launches).
     */
    static Set<Integer> listeningPorts(long pid) {
        Set<Integer> ports = new HashSet<>();
        Set<Long> inodes = socketInodes(pid);
        if (inodes.isEmpty()) {
            return ports;
        }
        for (String procNetFile : List.of("/proc/net/tcp", "/proc/net/tcp6")) {
            readListeningPorts(procNetFile, inodes, ports);
        }
        return ports;
    }

    /** Polls until a LISTEN port not present in {@code before} appears, or the timeout elapses. */
    static Optional<Integer> waitForNewListeningPort(long pid, Set<Integer> before, Duration timeout) {
        long deadline = System.nanoTime() + timeout.toNanos();
        while (System.nanoTime() < deadline) {
            Set<Integer> now = listeningPorts(pid);
            now.removeAll(before);
            if (!now.isEmpty()) {
                return Optional.of(now.iterator().next());
            }
            try {
                Thread.sleep(200);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return Optional.empty();
            }
        }
        return Optional.empty();
    }

    private static void readListeningPorts(String procNetFile, Set<Long> inodesOfInterest, Set<Integer> out) {
        Path path = Path.of(procNetFile);
        if (!Files.isReadable(path)) {
            return;
        }
        try {
            List<String> lines = Files.readAllLines(path);
            // Format (whitespace-separated, header on line 0):
            // sl local_address rem_address st tx_queue:rx_queue tr:tm->when retrnsmt uid timeout inode ...
            for (int i = 1; i < lines.size(); i++) {
                String[] fields = lines.get(i).trim().split("\\s+");
                if (fields.length < 10) {
                    continue;
                }
                String state = fields[3];
                if (!"0A".equalsIgnoreCase(state)) { // TCP_LISTEN
                    continue;
                }
                long inode;
                try {
                    inode = Long.parseLong(fields[9]);
                } catch (NumberFormatException e) {
                    continue;
                }
                if (!inodesOfInterest.contains(inode)) {
                    continue;
                }
                String localAddress = fields[1];
                int colon = localAddress.indexOf(':');
                if (colon < 0) {
                    continue;
                }
                out.add(Integer.parseInt(localAddress.substring(colon + 1), 16));
            }
        } catch (IOException ignored) {
        }
    }

    private static Set<Long> socketInodes(long pid) {
        Path fdDir = Path.of("/proc/" + pid + "/fd");
        Set<Long> inodes = new HashSet<>();
        try (DirectoryStream<Path> entries = Files.newDirectoryStream(fdDir)) {
            for (Path fd : entries) {
                try {
                    String target = Files.readSymbolicLink(fd).toString();
                    if (target.startsWith("socket:[") && target.endsWith("]")) {
                        inodes.add(Long.parseLong(target.substring(8, target.length() - 1)));
                    }
                } catch (IOException ignored) {
                }
            }
        } catch (IOException ignored) {
        }
        return inodes;
    }
}
