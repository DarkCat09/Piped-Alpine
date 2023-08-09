#!/usr/bin/env bash

patch_backend () {
    patcher \
        build.gradle \
        -e "s/implementation 'rocks.kavin:reqwest4j:.*'/implementation files('libs\/reqwest4j.jar')/"
    
    patcher \
        src/main/java/me/kavin/piped/Main.java \
        -e 's/options\.setDsn\(Constants\.SENTRY_DSN\)/options.setDsn("")/'
}

patch_reqwest4j () {
    patcher \
        build.gradle \
        -e '/rust\(project\(":reqwest-jni"\)\)/d'
    
    patcher \
        reqwest-jni/build.gradle.kts \
        -e 's/command\.set\("cross"\)/command.set("cargo")/' \
        -e ' /command\.set\("cargo"\)/a targets += target("x86_64-unknown-linux-musl", "libreqwest.so")' \
        -e ' /targets \+= target\(".*-unknown-linux-gnu", "libreqwest\.so"\)/d' \
        -e ' /targets \+= target\(".*-pc-windows-gnu", "libreqwest\.dll"\)/d'
}

patcher () {
    if grep '//patched' "$1" >/dev/null
    then
        echo "$1: already patched"
        return
    fi

    file="$1"
    shift
    sed -i -E "$@" -e '1i //patched' "$file"
}
