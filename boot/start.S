/*
 * start.S - bare-metal AArch64 bootstrap for QEMU `virt`.
 *
 * QEMU loads the ELF (-kernel) and jumps to _start on CPU 0, normally at EL1.
 * We:
 *   1. drop from EL2 to EL1 if QEMU started us at EL2 (-M virt,virtualization=on)
 *   2. install an exception vector table (crashes are reported, not silent hangs)
 *   3. enable FP/SIMD (otherwise the first float/NEON instruction traps)
 *   4. enable the MMU with an identity map, so RAM is "Normal" memory
 *      (unaligned loads/stores work, just like in a Linux user process)
 *   5. set up the stack, clear .bss, call main()
 *   6. exit QEMU via semihosting with main()'s return value as exit code
 */

        .section .text.boot, "ax"
        .global _start
        .type   _start, %function
_start:
        /* Only CPU 0 runs the program; park any others. */
        mrs     x0, mpidr_el1
        and     x0, x0, #0xff
        cbnz    x0, park

        /* ---- 1. EL2 -> EL1 if needed ------------------------------------ */
        mrs     x0, CurrentEL
        lsr     x0, x0, #2
        cmp     x0, #2
        b.ne    at_el1
        mov     x0, #(1 << 31)          /* HCR_EL2.RW: EL1 is AArch64 */
        msr     hcr_el2, x0
        mov     x0, #0x3c5              /* SPSR: EL1h, D/A/I/F masked */
        msr     spsr_el2, x0
        adr     x0, at_el1
        msr     elr_el2, x0
        eret

at_el1:
        /* ---- 2. vector table -------------------------------------------- */
        ldr     x0, =vectors
        msr     vbar_el1, x0

        /* ---- 3. FP/SIMD + SVE: CPACR_EL1.FPEN = 0b11, ZEN = 0b11 --------- */
        /*      (ZEN is ignored on CPUs without SVE, e.g. -cpu cortex-a72)  */
        mov     x0, #((3 << 20) | (3 << 16))
        msr     cpacr_el1, x0
        isb

        /* ---- 4. MMU: identity map, 1 GiB blocks ------------------------- */
        /* MAIR: attr0 = Device-nGnRnE (0x00), attr1 = Normal WB RA/WA (0xff) */
        mov     x0, #0xff00
        msr     mair_el1, x0
        /* TCR: T0SZ=25 (39-bit VA, walk starts at L1), inner/outer WB WA,
         *      inner shareable, 4 KiB granule, EPD1=1 (no TTBR1 walks),
         *      IPS=0 (32-bit PA is enough for 0..4 GiB)                    */
        ldr     x0, =0x803519
        msr     tcr_el1, x0
        ldr     x0, =page_table_l1
        msr     ttbr0_el1, x0
        isb
        tlbi    vmalle1
        dsb     sy
        isb
        mrs     x0, sctlr_el1
        orr     x0, x0, #(1 << 0)       /* M: MMU on        */
        orr     x0, x0, #(1 << 2)       /* C: data cache    */
        orr     x0, x0, #(1 << 12)      /* I: instr. cache  */
        bic     x0, x0, #(1 << 1)       /* A: no alignment checking */
        msr     sctlr_el1, x0
        isb

        /* ---- 5. stack, .bss, main --------------------------------------- */
        ldr     x0, =__stack_top
        mov     sp, x0

        ldr     x0, =__bss_start
        ldr     x1, =__bss_end
1:      cmp     x0, x1
        b.hs    2f
        str     xzr, [x0], #8
        b       1b
2:
        mov     x29, xzr                /* terminate frame-pointer chain */
        mov     x30, xzr
        bl      main

        /* ---- 6. exit with main()'s return value ------------------------- */
        b       rt_exit
        .size   _start, . - _start

park:   wfe
        b       park


/*
 * void rt_exit(int code)  -- never returns.
 * Semihosting SYS_EXIT (0x18) with ADP_Stopped_ApplicationExit (0x20026);
 * QEMU turns `code` into its own process exit status. Needs `-semihosting`.
 */
        .text
        .global rt_exit
        .type   rt_exit, %function
rt_exit:
        sxtw    x2, w0
        ldr     x1, =0x20026
        sub     sp, sp, #16
        stp     x1, x2, [sp]
        mov     x1, sp
        mov     w0, #0x18
        hlt     #0xf000
        /* only reached if QEMU was started without -semihosting */
3:      wfe
        b       3b
        .size   rt_exit, . - rt_exit


/*
 * Exception vectors: 16 entries x 128 bytes, 2 KiB aligned.
 * Every entry calls rt_exception(vector, esr, elr, far) in runtime.c,
 * which prints a diagnosis and exits QEMU with code 99.
 */
        .macro  vector_entry index
        .balign 0x80
        mov     x0, #\index
        b       exception_common
        .endm

        .section .text.vectors, "ax"
        .balign 0x800
vectors:
        .irp    i, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
        vector_entry \i
        .endr

exception_common:
        /* Exception while reporting an exception? Exit at once, don't loop. */
        ldr     x4, =in_exception
        ldr     w5, [x4]
        cbnz    w5, 4f
        mov     w5, #1
        str     w5, [x4]
        mrs     x1, esr_el1
        mrs     x2, elr_el1
        mrs     x3, far_el1
        ldr     x4, =__stack_top        /* fresh stack: the old one may be broken */
        mov     sp, x4
        bl      rt_exception
        /* nested exception: print a fixed message straight to the UART */
4:      ldr     x1, =nested_msg
        mov     x2, #0x09000000         /* PL011 data register */
5:      ldrb    w3, [x1], #1
        cbz     w3, 6f
        str     w3, [x2]
        b       5b
6:      mov     w0, #99
        b       rt_exit

        .section .rodata
nested_msg:
        .asciz  "\r\n*** CPU exception inside the exception handler.\r\n    Was the code built for a newer -march (ARCH) than the QEMU -cpu (QEMU_CPU)?\r\n"

        .bss
        .balign 4
in_exception:
        .word   0


/*
 * Level-1 translation table (512 x 1 GiB entries), identity mapped:
 *   0x0000_0000 - 0x3fff_ffff  Device  (UART, GIC, ... on `virt`)
 *   0x4000_0000 - 0x7fff_ffff  Normal  (RAM)
 * Block descriptor: [1:0]=01 block, [4:2]=AttrIndx, [9:8]=SH, [10]=AF
 */
        .section .data.page_table, "aw"
        .balign 4096
page_table_l1:
        .quad   0x0000000000000401      /* attr0 Device, AF             */
        .quad   0x0000000040000705      /* attr1 Normal, inner shr., AF */
        .fill   510, 8, 0
