#!/bin/ash
# shellcheck shell=dash

JAVA_BIN="/usr/lib/jvm/java-17-openjdk/bin/java"
PIPED="/home/piped/piped.jar"

"$JAVA_BIN" -server \
    -Xmx2G \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+OptimizeStringConcat \
    -XX:+UseStringDeduplication \
    -XX:+UseCompressedOops \
    -XX:+UseNUMA \
    -XX:+UseG1GC \
    -Xshare:on \
    -jar "$PIPED"
