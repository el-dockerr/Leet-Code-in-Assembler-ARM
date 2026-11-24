/*
 * Memory layout for QEMU `virt` (RAM starts at 0x4000_0000).
 * QEMU puts the device tree at the start of RAM, so the image starts at
 * +512 KiB. Run QEMU with at least -m 128M (the scripts use 256M).
 */
ENTRY(_start)

STACK_SIZE = 8M;
HEAP_SIZE  = 64M;

MEMORY
{
    RAM (rwx) : ORIGIN = 0x40080000, LENGTH = 255M
}

SECTIONS
{
    .text : {
        KEEP(*(.text.boot))
        *(.text.vectors)
        *(.text .text.*)
    } > RAM

    .rodata : ALIGN(16) { *(.rodata .rodata.*) } > RAM

    .data : ALIGN(16) { *(.data .data.*) } > RAM

    .bss (NOLOAD) : ALIGN(16) {
        __bss_start = .;
        *(.bss .bss.*) *(COMMON)
        . = ALIGN(16);
        __bss_end = .;
    } > RAM

    .heap (NOLOAD) : ALIGN(16) {
        __heap_start = .;
        . += HEAP_SIZE;
        __heap_end = .;
    } > RAM

    .stack (NOLOAD) : ALIGN(16) {
        . += STACK_SIZE;
        __stack_top = .;
    } > RAM

    /DISCARD/ : { *(.comment) *(.note .note.*) *(.eh_frame*) }
}
