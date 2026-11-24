#!/usr/bin/env bash
# ==========================================================================
#  run.sh - build & run LeetCode solutions (Linux / macOS / WSL / Git Bash)
#     ASM -> bare-metal AArch64 ELF, executed in qemu-system-aarch64
#     C++ -> native executable
#
#  ./run.sh help    for usage. Tools can be overridden with environment
#  variables: QEMU, CLANG, CXX, GDB, QEMU_CPU, ARCH, GDB_PORT
# ==========================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$ROOT/build"

QEMU="${QEMU:-qemu-system-aarch64}"
CLANG="${CLANG:-clang}"
CXX="${CXX:-g++}"
GDB="${GDB:-}"
QEMU_CPU="${QEMU_CPU:-max}"
ARCH="${ARCH:-armv9-a}"
GDB_PORT="${GDB_PORT:-1234}"

QEMU_ARGS=(-M virt -cpu "$QEMU_CPU" -m 256M -monitor none -semihosting -no-reboot)

usage() {
    cat <<EOF
Usage: ./run.sh <command> [problem]

  asm   <problem>          build the .S/.c files, run them in QEMU (AArch64)
  cpp   <problem>          build solution.cpp natively and run it
  test  <problem>          asm + cpp  (also: ./run.sh <problem>)
  debug <problem> [func]   start QEMU halted, attach gdb, break at func (main)
  all                      run asm + cpp for every folder in problems/
  new   <name>             create problems/<name> from templates/problem
  doctor                   check that all required tools are installed
  clean                    delete build/

  <problem> is a path (tests/qemu-smoke), a folder name in problems/
  (0001-two-sum) or its prefix (0001).

  Quit a hanging QEMU with Ctrl+A then X.
EOF
}

die()  { echo "error: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
need() { have "$1" || die "$1 not found. $2"; }

# resolve_dir <arg>  ->  DIR, NAME, OUT
resolve_dir() {
    local a="$1"
    if   [[ -d "$a" ]];                then DIR="$(cd "$a" && pwd)"
    elif [[ -d "$ROOT/$a" ]];          then DIR="$ROOT/$a"
    elif [[ -d "$ROOT/problems/$a" ]]; then DIR="$ROOT/problems/$a"
    else
        local m=("$ROOT"/problems/"$a"*/)
        [[ -d "${m[0]}" ]] || die "problem '$a' not found (looked in . and problems/)"
        DIR="${m[0]%/}"
    fi
    NAME="$(basename "$DIR")"
    OUT="$BUILD/$NAME"
}

sources() {     # sources <ext...>  -> prints matching files in $DIR, one per line
    local f ext
    for f in "$DIR"/*; do
        [[ -f "$f" ]] || continue
        for ext in "$@"; do [[ "$f" == *."$ext" ]] && { echo "$f"; break; }; done
    done
}

build_asm() {
    need "$CLANG" "Install clang + lld (Debian/Ubuntu: sudo apt install clang lld; macOS: brew install llvm lld)"
    local srcs=()
    while IFS= read -r f; do srcs+=("$f"); done < <(sources S s c)
    ((${#srcs[@]})) || die "no .S / .c files in $DIR"
    mkdir -p "$OUT"
    "$CLANG" --target=aarch64-none-elf -march="$ARCH" -ffreestanding -nostdlib \
        -fno-unwind-tables -fno-asynchronous-unwind-tables -O2 -g -Wall -Wextra \
        -I"$ROOT/boot" -fuse-ld=lld -Wl,-T,"$ROOT/boot/linker.ld" -Wl,-Map,"$OUT/asm.map" \
        "$ROOT/boot/start.S" "$ROOT/boot/runtime.c" "${srcs[@]}" -o "$OUT/asm.elf"
}

run_asm() {
    echo "==== $NAME [asm, qemu -cpu $QEMU_CPU] ===="
    build_asm || return 1
    need "$QEMU" "Install QEMU (Debian/Ubuntu: sudo apt install qemu-system-arm; macOS: brew install qemu)"
    local rc=0
    "$QEMU" "${QEMU_ARGS[@]}" -nographic -kernel "$OUT/asm.elf" || rc=$?
    [[ $rc == 99 ]] && echo "(CPU exception - see the report above; disassemble with: llvm-objdump -d $OUT/asm.elf)"
    return $rc
}

run_cpp() {
    echo "==== $NAME [cpp] ===="
    need "$CXX" "Install a C++20 compiler (g++ or clang++), or set CXX"
    local srcs=()
    while IFS= read -r f; do srcs+=("$f"); done < <(sources cpp)
    ((${#srcs[@]})) || die "no .cpp files in $DIR"
    mkdir -p "$OUT"
    "$CXX" -std=c++20 -O2 -g -Wall -Wextra -I"$ROOT/cpp" "${srcs[@]}" -o "$OUT/cpp" || return 1
    "$OUT/cpp"
}

FAILS=()
run_both() {
    local rc=0 ran=0
    if [[ -n "$(sources S s)" ]]; then ran=1; run_asm || { rc=1; FAILS+=("$NAME[asm]"); }; fi
    if [[ -n "$(sources cpp)"  ]]; then ran=1; run_cpp || { rc=1; FAILS+=("$NAME[cpp]"); }; fi
    ((ran)) || echo "==== $NAME: nothing to run (no .S or .cpp) ===="
    return $rc
}

cmd_all() {
    local count=0 d
    for d in "$ROOT"/problems/*/; do
        [[ -d "$d" ]] || continue
        DIR="${d%/}"; NAME="$(basename "$DIR")"; OUT="$BUILD/$NAME"
        count=$((count + 1))
        run_both || true
        echo
    done
    if ((${#FAILS[@]})); then echo "FAILED: ${FAILS[*]}"; return 1; fi
    echo "All $count problems passed."
}

cmd_debug() {
    local brk="${1:-main}"
    build_asm
    need "$QEMU" "Install QEMU"
    if [[ -z "$GDB" ]]; then
        if have gdb-multiarch; then GDB=gdb-multiarch
        elif have gdb && gdb -batch -ex "set architecture aarch64" >/dev/null 2>&1; then GDB=gdb
        else die "no AArch64-capable gdb found (sudo apt install gdb-multiarch; macOS: brew install aarch64-elf-gdb)"
        fi
    fi
    echo "QEMU halted at _start, GDB stub on localhost:$GDB_PORT, UART output -> $OUT/uart.log"
    "$QEMU" "${QEMU_ARGS[@]}" -display none -serial "file:$OUT/uart.log" \
        -S -gdb "tcp::$GDB_PORT" -kernel "$OUT/asm.elf" &
    local qpid=$!
    trap 'kill $qpid 2>/dev/null || true' EXIT
    sleep 0.5
    echo
    echo "  gdb cheat sheet:  c | si | ni | b <func> | info registers | x/8dw \$x0 | bt | q"
    echo "  program output:   tail -f $OUT/uart.log   (in a second terminal)"
    echo
    "$GDB" -q -x "$ROOT/boot/debug.gdb" -ex "target remote localhost:$GDB_PORT" \
        -ex "break $brk" -ex "continue" "$OUT/asm.elf"
}

cmd_new() {
    local name="${1:-}"
    [[ -n "$name" ]] || die "usage: ./run.sh new 0042-trapping-rain-water"
    local dest="$ROOT/problems/$name"
    [[ ! -e "$dest" ]] || die "$dest already exists"
    local num="${name%%-*}" slug="${name#*-}"
    local title
    title="$(echo "$slug" | awk -F- '{for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2)} 1' OFS=' ')"
    mkdir -p "$dest"
    local f
    for f in "$ROOT"/templates/problem/*; do
        sed -e "s/NNNN/$num/g" -e "s/<slug>/$slug/g" -e "s/Title/$title/g" "$f" > "$dest/$(basename "$f")"
    done
    echo "Created problems/$name"
    echo "  edit   problems/$name/solution.S, test.c, solution.cpp"
    echo "  run    ./run.sh $name"
}

cmd_doctor() {
    local missing=0 t
    for t in "$QEMU" "$CLANG" ld.lld "$CXX"; do
        if have "$t"; then echo "[ok] $t: $(command -v "$t")"; else echo "[!!] $t: not found"; missing=1; fi
    done
    if have gdb-multiarch; then echo "[ok] gdb-multiarch: $(command -v gdb-multiarch)"
    else echo "[--] gdb-multiarch: not found (optional, for ./run.sh debug)"; fi
    ((missing == 0)) || { echo; die "some required tools are missing"; }
    echo
    echo "Running QEMU smoke test ..."
    resolve_dir "$ROOT/tests/qemu-smoke"
    run_asm
}

cmd="${1:-}"
case "$cmd" in
    ""|help|-h|--help) usage ;;
    doctor) cmd_doctor ;;
    new)    cmd_new "${2:-}" ;;
    all)    cmd_all ;;
    clean)  rm -rf "$BUILD"; echo "build/ removed" ;;
    asm|cpp|test|debug)
        [[ -n "${2:-}" ]] || { usage; exit 2; }
        resolve_dir "$2"
        case "$cmd" in
            asm)   run_asm ;;
            cpp)   run_cpp ;;
            test)  run_both ;;
            debug) cmd_debug "${3:-}" ;;
        esac ;;
    *)  resolve_dir "$cmd"; run_both ;;
esac
