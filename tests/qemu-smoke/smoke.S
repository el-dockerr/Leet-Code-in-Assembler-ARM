/*
 * smoke.S - assembly side of the QEMU smoke test.
 */
        .text

/* long add_i64(long a, long b) */
        .global add_i64
        .type   add_i64, %function
add_i64:
        add     x0, x0, x1
        ret
        .size   add_i64, . - add_i64

/* double mul_f64(double a, double b)   -- needs FP enabled by start.S */
        .global mul_f64
        .type   mul_f64, %function
mul_f64:
        fmul    d0, d0, d1
        ret
        .size   mul_f64, . - mul_f64

/* int sum_i32_neon(const int *a, int n)  -- n multiple of 4, uses NEON */
        .global sum_i32_neon
        .type   sum_i32_neon, %function
sum_i32_neon:
        movi    v0.4s, #0
1:      cbz     w1, 2f
        ld1     {v1.4s}, [x0], #16
        add     v0.4s, v0.4s, v1.4s
        sub     w1, w1, #4
        b       1b
2:      addv    s0, v0.4s
        fmov    w0, s0
        ret
        .size   sum_i32_neon, . - sum_i32_neon

/* uint32_t load_unaligned(const void *p)  -- needs MMU on (Normal memory) */
        .global load_unaligned
        .type   load_unaligned, %function
load_unaligned:
        ldr     w0, [x0]
        ret
        .size   load_unaligned, . - load_unaligned

/* void hello_from_asm(void)  -- assembly calling back into the C runtime */
        .global hello_from_asm
        .type   hello_from_asm, %function
hello_from_asm:
        stp     x29, x30, [sp, #-16]!   /* save frame pointer + return addr */
        mov     x29, sp
        adr     x0, fmt
        mov     w1, #42
        bl      printf
        ldp     x29, x30, [sp], #16
        ret
        .size   hello_from_asm, . - hello_from_asm

        .section .rodata
fmt:    .asciz  "  hello from assembly, w1 = %d\n"
