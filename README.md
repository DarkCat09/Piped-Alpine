# Piped-Alpine

- Patches for backend source code to make it work on Alpine
- Simple build script and `start.sh`
- OpenRC configs

Patches may outdate, so open an issue
if you get an error while script applies them.

## How to build
1. Install dependencies: `doas apk add git openjdk17 openjdk21 7zip`
(Note that both OpenJDK 17 and 21 are installed,
for building reqwest4j and Piped respectively)
2. Install Rust: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`  
(Note that you don't need doas or sudo here)
3. Enter to RustUp environment: `source ~/.cargo/env`
4. Run the script: `./build.sh`  
(`bash build.sh` if you executed previous commands from bash)

You can set environment variables
`ARCH=x86_64|aarch64|armv7...`,
`LIBC=musl|gnu|musleabi|gnueabi`,
e.g. `ARCH=aarch64 ./build.sh`.
They default to x86_64 musl.

## How to start Piped
1. Edit config.properties
2. Change `/home/piped` in start.sh to directory
where piped JAR and config are located
3. Run the script: `./start.sh`

## OpenRC
1. Change `/home/piped` in piped.init to directory
where piped JAR and config are located
2. Change `command_user="piped"` in piped.init to the Piped's user name
3. Copy this init script: `doas cp piped.init /etc/init.d/piped`
4. Add it to autostart: `doas rc-update add piped`
5. Start the service: `doas service piped start`

## I also need to start a proxy, right?
Yes.

This repo is dedicated only to patches for Piped's backend,
but I've included an OpenRC config for proxy and this small explanation below.

### Build
Building proxy is quite easy:
```bash
git clone https://github.com/TeamPiped/piped-proxy
cd piped-proxy
cargo build --release
cp target/release/piped-proxy ..
cd ..
```

### Start
Command: `UDS=1 ./piped-proxy`

- With UDS=1, it creates a Unix socket in `./socket/actix.sock`
instead of listening on TCP port.
- Without UDS=1, it listens for HTTP connections on :8080 port.
- If you want to specify other TCP port,
use `BIND=127.0.0.1:8080` variable (replace port and host with your own),
and do not enable UDS.

Create `socket` directory before the first start if you have enabled UDS.  
Also, check if the user from which the proxy is started has write access to the `socket/`.

### OpenRC
The same as in Piped backend.  
Copy `proxy.init` replacing the directory and user, replacing `UDS=1` with `BIND=...` if needed.  
I've set `nginx` as user because otherwise my reverse proxy won't have access to the socket file.
