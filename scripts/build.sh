#!/bin/sh
# Compila `wk` per tutte le piattaforme supportate in bin/<os>-<arch>/ (richiede zig 0.17.x).
# Uso: scripts/build.sh [target...]   target: linux-x86_64 linux-aarch64 macos-x86_64 macos-aarch64 windows-x86_64
# Compilare da un albero git pulito: la versione del binario include `git describe --dirty`.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
all="linux-x86_64 linux-aarch64 macos-x86_64 macos-aarch64 windows-x86_64"
targets=${*:-$all}
# la configurazione di zig (con `git describe`) è in cache: va svuotata o il binario porta un commit vecchio
rm -rf "$root/cli/.zig-cache"
# commit di provenienza, letto PRIMA di toccare bin/ (che è tracciato): "sporco" conta solo fuori da bin/
commit=$(git -C "$root" describe --always)
git -C "$root" diff --quiet HEAD -- . ':!bin' || commit="$commit-dirty"
for t in $targets; do
  os=${t%-*}; arch=${t#*-}
  case "$os" in
    linux) triple="$arch-linux-musl" ;;
    macos) triple="$arch-macos" ;;
    windows) triple="$arch-windows" ;;
    *) echo "unknown target: $t" >&2; exit 1 ;;
  esac
  out="$root/bin/$t"
  echo "== $t ($triple)"
  rm -rf "$out"
  (cd "$root/cli" && zig build -Dtarget="$triple" -Doptimize=ReleaseSafe -Dstrip=true -Dcommit="$commit" -p "$out.tmp")
  mkdir -p "$out"
  mv "$out.tmp/bin/"* "$out/"
  rm -rf "$out.tmp"
  ls -l "$out" | tail -n +2
done
