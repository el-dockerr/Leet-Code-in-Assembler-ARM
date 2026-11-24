/* Test harness for the ASM solution (runs bare-metal in QEMU). */
#include "runtime.h"

void two_sum(const int *nums, int n, int target, int out[2]);

static void check(const int *nums, int n, int target, int e0, int e1)
{
    int out[2] = { -2, -2 };
    int expected[2] = { e0, e1 };
    two_sum(nums, n, target, out);
    EXPECT_ARRAY_EQ(out, expected, 2);
}

int main(void)
{
    puts("0001 two-sum (asm)");

    check((int[]){ 2, 7, 11, 15 }, 4, 9, 0, 1);
    check((int[]){ 3, 2, 4 }, 3, 6, 1, 2);
    check((int[]){ 3, 3 }, 2, 6, 0, 1);
    check((int[]){ -1000000000, 5, 1000000000 }, 3, 0, 0, 2);
    check((int[]){ 1, 2 }, 2, 100, -1, -1);

    return TEST_SUMMARY();
}
