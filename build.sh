#!/usr/bin/env bash
# shellcheck source=patcher.sh

WORKDIR=$(pwd)


# ---
dep () {
    if ! which "$1" 2>/dev/null
    then
        echo "$1 not found"
        exit 1
    fi
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

set_piped_version () {
    # From GitHub Actions
    commit_date=$(git log -1 --date=short --pretty=format:%cd)
    commit_sha=$(git rev-parse --short HEAD)
    echo "$commit_date-$commit_sha" >VERSION
}

title () {
    # Newline, Bold text, $1, Normal text, Newline
    printf '\n\033[1m%s\033[0m\n' "$1"
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
source patcher.sh
cd_and_exec backend patch_backend
cd_and_exec reqwest4j patch_reqwest4j


# ---
export RUSTFLAGS="-C target-feature=-crt-static"

title 'Building reqwest-jni'
cd_and_exec reqwest4j/reqwest-jni \
    cargo build --release --target x86_64-unknown-linux-musl

title 'Building reqwest4j without Rust library...'
OLD_PATH="$PATH"
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
export PATH="$JAVA_HOME/bin:$PATH"
cd_and_exec reqwest4j ./gradlew shadowJar
cd_and_exec reqwest4j ./gradlew --stop
export PATH="$OLD_PATH"
unset JAVA_HOME


# ---
title 'Adding built libreqwest_jni into reqwest4j JAR...'

title '--Copying files'

# Copy JAR into workdir
REQ4J_NAME="reqwest4j.jar"
REQ4J="$WORKDIR/$REQ4J_NAME"

cd_and_exec reqwest4j/build/libs \
    find . -maxdepth 1 -name 'reqwest4j-*-all.jar' -exec \
    cp {} "$REQ4J" \;

# Copy built reqwest-jni into workdir
REQJNI_NAME="libreqwest.so"
REQJNI="$WORKDIR/$REQJNI_NAME"

cd_and_exec reqwest4j/reqwest-jni/target/x86_64-unknown-linux-musl/release \
    cp libreqwest_jni.so "$REQJNI"

# Create JAR native libraries tree
title '--Creating libraries directory tree'
NATIVES="META-INF/natives/linux/x86_64"
mkdir -p "$NATIVES"

# Move reqwest-jni to native libraries directory
title '--Moving libreqwest'
mv "$REQJNI" "$NATIVES/$REQJNI_NAME"

# Add native libraries into JAR
title '--Injecting libraries directory into reqwest4j JAR'
7z u "$REQ4J" META-INF

# Clean up
title '--Cleaning up'
rm -rf META-INF
rm -f "$REQJNI"


# ---
title 'Adding reqwest4j JAR into Piped sources...'
cd_and_exec backend mkdir -p libs
cd_and_exec backend/libs mv "$REQ4J" ./

title 'Creating VERSION file...'
cd_and_exec backend set_piped_version

title 'Building Piped...'
OLD_PATH="$PATH"
export JAVA_HOME="/usr/lib/jvm/java-21-openjdk"
export PATH="$JAVA_HOME/bin:$PATH"
cd_and_exec backend ./gradlew shadowJar
cd_and_exec backend ./gradlew --stop
export PATH="$OLD_PATH"
unset JAVA_HOME


# ---
title 'Copying Piped JAR...'
cd_and_exec backend/build/libs \
    find . -maxdepth 1 -name 'piped-*-all.jar' -exec \
    cp {} "$WORKDIR/piped.jar" \;

title 'Copying config and version...'
cd_and_exec backend cp config.properties VERSION "$WORKDIR"

title 'Cleaning up...'
rm -rf backend reqwest4j


# ---
echo
echo '*** ************** ***'
echo '***      DONE      ***'
echo '*** ************** ***'

title 'You need these files:'

for f in "piped.jar" "config.properties" "VERSION"
do
    echo "  $(readlink -f "$f")"
done
