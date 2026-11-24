/* Test harness for the ASM solution (runs bare-metal in QEMU). */
#include "runtime.h"

int solve(const int *nums, int n);

int main(void)
{
    puts("NNNN <slug> (asm)");

    {
        int nums[] = { 1, 2, 3 };
        EXPECT_EQ(solve(nums, ARRAY_LEN(nums)), 0);
    }

    return TEST_SUMMARY();
}
