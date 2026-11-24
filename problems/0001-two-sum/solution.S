/*
 * 1. Two Sum - https://leetcode.com/problems/two-sum/
 *
 * void two_sum(const int *nums, int n, int target, int out[2]);
 *
 * For each i, scan j > i for nums[i] + nums[j] == target.
 * Writes {-1, -1} if no pair exists.
 * Not optimal and far from O(n) Time/Space of the C++ source.
 * But we have no STL in place and everything have to made by hand.
 * So I have to Brute force, what gives you O(n^2). 
 *
 * Registers (AAPCS64):
 *   x0 = nums   w1 = n   w2 = target   x3 = out
 *   w4 = i      w5 = j   w6 = nums[i]  w7 = nums[j]
 * Only caller-saved registers are used and nothing is called -> leaf
 * function, no stack frame needed.
 *
 * Author: Swen Kalski
 */
        .text
        .global two_sum
        .type   two_sum, %function
two_sum:
        mov     w4, #0                          // i = 0
.Louter:
        cmp     w4, w1
        b.ge    .Lnot_found                     // i >= n
        ldr     w6, [x0, w4, sxtw #2]           // nums[i]
        sub     w6, w2, w6                      // need = target - nums[i]
        add     w5, w4, #1                      // j = i + 1
.Linner:
        cmp     w5, w1
        b.ge    .Lnext_i                        // j >= n
        ldr     w7, [x0, w5, sxtw #2]           // nums[j]
        cmp     w7, w6
        b.eq    .Lfound
        add     w5, w5, #1
        b       .Linner
.Lnext_i:
        add     w4, w4, #1
        b       .Louter
.Lnot_found:
        mov     w4, #-1
        mov     w5, #-1
.Lfound:
        stp     w4, w5, [x3]                    // out[0] = i, out[1] = j
        ret
        .size   two_sum, . - two_sum
