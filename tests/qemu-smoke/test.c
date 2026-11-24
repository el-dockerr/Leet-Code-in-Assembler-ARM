/*
 * Author: Swen Kalski
 *
 * QEMU smoke test: proves the toolchain, bootstrap and runtime work.
 *   run.bat asm tests\qemu-smoke      (Windows)
 *   ./run.sh asm tests/qemu-smoke     (Linux / macOS / WSL)
 * Expected: "PASSED  n checks" and exit code 0.
 */
#include "runtime.h"

long     add_i64(long a, long b);
double   mul_f64(double a, double b);
int      sum_i32_neon(const int *a, int n);
uint32_t load_unaligned(const void *p);
void     hello_from_asm(void);

static int zeroed[64];          /* lives in .bss -> must be cleared by start.S */
static int initialised = 1234;  /* lives in .data -> must be loaded by QEMU    */

int main(void)
{
    uint64_t el;
    __asm__ volatile("mrs %0, CurrentEL" : "=r"(el));
    printf("leet_asm QEMU smoke test - running at EL%u\n", (unsigned)(el >> 2));

    hello_from_asm();

    EXPECT_EQ(add_i64(40, 2), 42);
    EXPECT_EQ(add_i64(-5, 3), -2);

    EXPECT_TRUE(mul_f64(1.5, 4.0) == 6.0);

    int v[8] = { 1, 2, 3, 4, 5, 6, 7, 8 };
    EXPECT_EQ(sum_i32_neon(v, 8), 36);

    unsigned char bytes[8] = { 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77 };
    EXPECT_EQ(load_unaligned(bytes + 1), 0x44332211);

    int all_zero = 1;
    for (int i = 0; i < ARRAY_LEN(zeroed); i++) all_zero &= zeroed[i] == 0;
    EXPECT_TRUE(all_zero);
    EXPECT_EQ(initialised, 1234);

    int *a = malloc(100 * sizeof(int));
    int *b = calloc(10, sizeof(int));
    EXPECT_TRUE(a != NULL && b != NULL && a != b);
    EXPECT_EQ((uintptr_t)a % 16, 0);
    EXPECT_EQ(b[9], 0);

    int expect[3] = { 1, 2, 3 }, got[3] = { 1, 2, 3 };
    EXPECT_ARRAY_EQ(got, expect, 3);

    printf("  printf: [%5d] [%-5d] [%05d] [%x] [%s] [%c]\n", 42, 42, -42, 0xbeef, "str", 'c');

    return TEST_SUMMARY();
}
