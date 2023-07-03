#!/usr/bin/env ash
# shellcheck shell=dash

BOLD=$(tput bold)
RESET=$(tput sgr0)

WORKDIR=$(pwd)


# ---
dep () {
    which "$1" || (echo "$1 not found" && exit 1)
}

clone () {
    git clone --single-branch --depth 1 "$1" "$2" || exit 2
}

cd_and_exec () {
    old=$(pwd)
    cd "$1" || exit 3
    shift
    "$@" || exit 4
    cd "$old" || exit 3
}

try_exec () {
    "$@"
    return 0
}

title () {
    echo
    echo "$BOLD$1$RESET"
}


# ---
title 'Checking dependencies...'
dep git
dep java
dep cargo
dep 7z

title 'Cloning repositories...'
[ -e backend   ] || clone https://github.com/TeamPiped/Piped-Backend backend
[ -e reqwest4j ] || clone https://github.com/TeamPiped/reqwest4j reqwest4j

title 'Applying patches...'
cd_and_exec backend try_exec git apply ../backend.patch
cd_and_exec reqwest4j try_exec git apply ../reqwest4j.patch


# ---
export RUSTFLAGS="-C target-feature=-crt-static"

title 'Building reqwest-jni...'
cd_and_exec reqwest4j/reqwest-jni cargo build --release

title 'Building reqwest4j...'
cd_and_exec reqwest4j ./gradlew shadowJar
cd_and_exec reqwest4j ./gradlew --stop


# ---
title 'Adding built reqwest-jni into reqwest4j...'

# Copy JAR into workdir
REQ4J_NAME="reqwest4j.jar"
REQ4J="$WORKDIR/$REQ4J_NAME"
cd_and_exec reqwest4j/build/libs \
    find . -maxdepth 1 -name 'reqwest4j-*-all.jar' -exec \
    cp {} "$REQ4J" \;

# Copy built reqwest-jni into workdir
REQJNI_NAME="libreqwest_jni.so"
REQJNI="$WORKDIR/$REQJNI_NAME"
cd_and_exec reqwest4j/reqwest-jni/target/release cp libreqwest_jni.so "$REQJNI"

# Create JAR native libraries tree
NATIVES="META-INF/natives/linux/x86_64"
mkdir -p "$NATIVES"

# Move reqwest-jni to native libraries directory
mv "$REQJNI" "$NATIVES/$REQJNI_NAME"

# Add native libraries into JAR
7z u "$REQ4J" META-INF

# Clean up
rm -rf META-INF
rm -f "$REQJNI"


# ---
title 'Adding reqwest4j JAR into Piped...'
cd_and_exec backend mkdir libs
cd_and_exec backend/libs mv "$REQ4J" ./

title 'Building Piped...'
cd_and_exec backend ./gradlew shadowJar
cd_and_exec backend ./gradlew --stop


# ---
title 'Copying Piped JAR...'
cd_and_exec backend/build/libs \
    find . -maxdepth 1 -name 'piped-*-all.jar' -exec \
    cp {} "$WORKDIR/piped.jar" \;

title 'Copying config...'
cd_and_exec backend cp config.properties "$WORKDIR"

title 'Cleaning up...'
rm -rf backend reqwest4j


# ---
echo '*** **** ***'
echo '*** DONE ***'
title 'You need these files:'
for f in "piped.jar" "config.properties"
do
    echo "  $(readlink -f "$f")"
done
