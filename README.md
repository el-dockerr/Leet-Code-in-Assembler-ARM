# Leet Code in Assembler (ARM)
## Written by Swen Kalski


The Repository have LeetCode problems solved twice: once in **C++** and once in **ARM64 (AArch64) assembly**.

This is a nice repo, to keep my knowledge about ARM Assembly alive and keep me busy when I'm bored.

The C++ solutions run natively. The assembly solutions run **bare-metal in QEMU**
(`qemu-system-aarch64 -M virt`). A small bootstrap in this repo provides `printf`,
`malloc`, test assertions and crash reports, so nothing else is needed.

```
 solution.S ─┐                                            ┌─ UART  ──> your terminal
 test.c     ─┼─ clang --target=aarch64-none-elf ─> asm.elf ─ qemu ─┤
 boot/*     ─┘           (+ ld.lld, boot/linker.ld)        └─ exit code (semihosting)

 solution.cc ── g++ -std=c++20 ──> cpp.exe ──> runs natively
```

---

## Quick start

```bat
run.bat doctor          :: checks the tools, then runs the QEMU smoke test
run.bat 0001            :: runs problem 0001 (asm in QEMU + cpp natively)
run.bat new 0042-trapping-rain-water
```

On Linux / macOS / WSL use `./run.sh` with the same arguments.

## Requirements

| Tool | Used for | Windows | Debian / Ubuntu | macOS |
|---|---|---|---|---|
| `qemu-system-aarch64` | runs the ASM | `scoop install qemu` | `apt install qemu-system-arm` | `brew install qemu` |
| `clang` + `ld.lld` (LLVM ≥ 15) | assembles and links the bare-metal ELF | `winget install LLVM.LLVM` | `apt install clang lld` | `brew install llvm lld` |
| `g++` (C++20) | C++ solutions | MSYS2: `pacman -S mingw-w64-ucrt-x86_64-gcc` | `apt install g++` | Xcode CLT (`CXX=clang++`) |
| `gdb-multiarch` *(optional)* | `debug` command | MSYS2: `pacman -S mingw-w64-ucrt-x86_64-gdb-multiarch` | `apt install gdb-multiarch` | `brew install aarch64-elf-gdb` |

No ARM GCC cross toolchain is needed: one LLVM install targets AArch64 as well as the host.
The scripts look for each tool on `PATH` first, then in the usual install folders
(scoop, `C:\Program Files\LLVM`, `C:\msys64`).

## Commands

| Command | What it does |
|---|---|
| `run.bat asm <problem>` | build `boot/` + all `.S`/`.c` files of the problem, run them in QEMU |
| `run.bat cpp <problem>` | build all `.cpp` files of the problem natively and run them |
| `run.bat test <problem>` | both of the above (same as `run.bat <problem>`) |
| `run.bat debug <problem> [func]` | QEMU halted with a GDB stub, gdb attached, breakpoint at `func` (default `main`) |
| `run.bat all` | test every folder in `problems/`, print a summary |
| `run.bat new <NNNN-slug>` | copy `templates/problem/` to `problems/<NNNN-slug>/` and fill in the placeholders |
| `run.bat doctor` | check the tools and run `tests/qemu-smoke` |
| `run.bat clean` | delete `build/` |

`<problem>` can be a path (`tests\qemu-smoke`), a folder in `problems/` (`0001-two-sum`)
or the start of its name (`0001`).

**Exit codes:** `0` all checks passed · `1` a check failed · `98` out of heap · `99` CPU exception (crash).
QEMU passes the code through, so the scripts work in CI.

**Stuck in an endless loop?** Press `Ctrl+A`, then `X`, to quit QEMU.

## Project layout

```
boot/                 bare-metal bootstrap (shared by all problems)
  start.S             _start: EL2->EL1, vectors, FPU/SVE on, MMU on, stack, .bss, main(), exit
  runtime.c/.h        UART printf/puts, malloc, memcpy..., EXPECT_* macros, crash report
  linker.ld           memory map (QEMU virt, RAM at 0x4000_0000)
  debug.gdb           gdb settings used by `debug`
cpp/test.h            EXPECT_EQ / TEST_SUMMARY for the C++ solutions
problems/NNNN-slug/
  solution.S          ASM solution
  test.c              ASM test harness (runs in QEMU, calls the ASM function)
  solution.cc        C++ solution + its tests (main)
templates/problem/    template that `new` copies
tests/qemu-smoke/     checks the toolchain, bootstrap and runtime
build/                build output (git-ignored): <problem>/asm.elf, asm.map, cpp.exe
run.bat, run.sh       build & run scripts
```

## Workflow for a new problem

1. `run.bat new 0136-single-number`
2. **C++:** write the `Solution` class and test cases in `solution.cc`.
   (I prever .cc over .cpp - see Google Code Style pattern)
3. **ASM:** choose a C signature for the function, e.g.
   `int single_number(const int *nums, int n);`
   (vectors become pointer + length; returned arrays become an output pointer).
   Implement it in `solution.S` and declare it in `test.c`.
4. `run.bat 0136`, then fix it until both parts show `PASSED`.
5. Add the problem to the [progress table](#progress).

---

## AArch64 cheat sheet

### Calling convention (AAPCS64)

| Registers | Role | Who saves |
|---|---|---|
| `x0`–`x7` | arguments 1–8, return value in `x0` (`w0` for `int`) | caller |
| `x8` | indirect result (struct return) | caller |
| `x9`–`x15` | scratch | caller |
| `x16`, `x17` | intra-call scratch (IP0/IP1) | caller |
| `x18` | platform register (free to use here) | — |
| `x19`–`x28` | must be preserved | **callee** |
| `x29` (FP), `x30` (LR) | frame pointer, return address | **callee** |
| `sp` | stack pointer, **must stay 16-byte aligned** | — |
| `v0`–`v7` / `d0`–`d7` | FP/SIMD arguments and return value | caller |
| `v8`–`v15` (lower 64 bits) | must be preserved | **callee** |

`int` → `wN` (32-bit), `long` / pointer / `size_t` → `xN` (64-bit).
A write to `wN` zeroes the upper half of `xN`.

### Common patterns

```asm
// non-leaf function: save FP + LR (and any x19-x28 you use)
func:   stp     x29, x30, [sp, #-32]!
        mov     x29, sp
        stp     x19, x20, [sp, #16]
        ...
        ldp     x19, x20, [sp, #16]
        ldp     x29, x30, [sp], #32
        ret

        ldr     w2, [x0, w1, sxtw #2]   // w2 = nums[i]   (int array, signed index)
        ldr     x2, [x0, x1, lsl #3]    // x2 = arr[i]    (64-bit array)
        ldr     w2, [x0], #4            // w2 = *p++
        cmp     w1, w2 ; b.lt label     // signed  <   (b.lo for unsigned)
        csel    w0, w1, w2, gt          // w0 = (w1 > w2) ? w1 : w2
        cbz     w0, label               // if (w0 == 0) goto label
        adr     x0, msg ; bl puts       // call the runtime from ASM
```

Local labels: `1:` … `b 1b` (backward) / `b 1f` (forward), or `.Lname:`.

## Runtime available in QEMU

You can call these from `test.c` and from assembly (`bl printf`, `bl malloc`, …). See [boot/runtime.h](boot/runtime.h).

| Function | Notes |
|---|---|
| `printf`, `puts`, `putchar` | `%d %i %u %x %X %p %s %c`, `l`/`ll`/`z`, width, `-`, `0` |
| `print_int_array(a, n)` | prints `[1, 2, 3]` |
| `malloc`, `calloc`, `free` | bump allocator, 64 MiB heap; `free` does nothing |
| `memset`, `memcpy`, `memmove`, `memcmp`, `strlen` | |
| `rt_exit(code)` | quit QEMU immediately with `code` |
| `rt_cycles()` | virtual counter (`cntvct_el0`), for rough timing |
| `EXPECT_EQ(a, b)`, `EXPECT_TRUE(c)`, `EXPECT_ARRAY_EQ(a, e, n)`, `TEST_SUMMARY()` | test helpers |

### The bare-metal environment

- CPU `-cpu max` (armv9-a: NEON, SVE2, LSE atomics, CRC, …), one core, EL1, 256 MiB RAM.
- The MMU is on with an identity map (RAM = Normal memory), so unaligned loads/stores work.
- 8 MiB stack, 64 MiB heap (change both in [boot/linker.ld](boot/linker.ld)).
- There is no OS: no `svc` syscalls, files, threads or interrupts. Output goes to the PL011 UART at `0x0900_0000`.
- Crashes (bad pointer, misaligned `sp`, undefined instruction) print `ESR`/`ELR`/`FAR` and exit with 99.
  Find the source line: `llvm-addr2line -f -e build\<problem>\asm.elf <ELR>`.

## Debugging

```bat
run.bat debug 0001-two-sum
```

This starts QEMU halted (in a separate window, which also shows the program output) and attaches
`gdb-multiarch` with a breakpoint on `two_sum`. Useful commands:

| gdb | |
|---|---|
| `si` / `ni` | step one instruction (into / over `bl`) |
| `c` | continue to the next breakpoint |
| `info registers` / `p $x0` | registers |
| `x/8dw $x0` | 8 signed 32-bit words at `x0` (e.g. `nums`) |
| `x/10i $pc` | disassemble at the current PC |
| `layout asm` / `layout regs` | TUI views (if supported by the terminal) |

Other useful tools: `llvm-objdump -d build\<problem>\asm.elf` (disassembly) and `build\<problem>\asm.map` (where everything was linked).

## Configuration

Set these environment variables before calling the script, e.g. `set QEMU_CPU=cortex-a72`:

| Variable | Default | |
|---|---|---|
| `QEMU_CPU` | `max` | QEMU `-cpu` model, e.g. `cortex-a53`, `cortex-a72`, `neoverse-n2` |
| `ARCH` | `armv9-a` | clang `-march`; must be supported by `QEMU_CPU` (`armv8-a` for A53/A72) |
| `QEMU`, `CLANG`, `CXX`, `GDB`, `LLDB` | auto | explicit tool paths |
| `GDB_PORT` | `1234` | port of QEMU's GDB stub |

## Troubleshooting

| Symptom | Fix |
|---|---|
| `The system cannot find the batch label specified` | `run.bat` lost its CRLF line endings. `.gitattributes` prevents this; to fix it now, re-save the file with CRLF. |
| `qemu-system-aarch64 not found` right after `scoop install qemu` | open a new terminal (the PATH change only applies there), or set `QEMU=...` |
| Exit code 99 with *"exception inside the exception handler"* | `ARCH` is newer than the CPU in `QEMU_CPU`. Use `QEMU_CPU=max` or a lower `ARCH`. |
| QEMU prints nothing and hangs | endless loop in your code: `Ctrl+A X`, then `run.bat debug` |
| `lldb` exits immediately (Windows) | the official LLVM `lldb.exe` needs `python310.dll`; use `gdb-multiarch` instead |

---

## Progress

| # | Problem | Difficulty | C++ | ASM | Notes |
|---:|---|---|:---:|:---:|---|
| 1 | [Two Sum](https://leetcode.com/problems/two-sum/) | Easy | ✅ | ✅ | C++: hash map O(n) · ASM: brute force O(n²) |
| | | | | | |
