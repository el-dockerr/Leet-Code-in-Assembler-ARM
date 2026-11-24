/*
 * NNNN. Title - https://leetcode.com/problems/<slug>/
 *
 * int solve(const int *nums, int n);
 *
 * Idea:
 *
 * Registers (AAPCS64):
 *   x0 = nums   w1 = n
 *   result in w0
 */
        .text
        .global solve
        .type   solve, %function
solve:
        // Non-leaf function? Save frame pointer + link register first:
        //   stp     x29, x30, [sp, #-16]!
        //   mov     x29, sp
        //   ...
        //   ldp     x29, x30, [sp], #16
        mov     w0, #0
        ret
        .size   solve, . - solve
