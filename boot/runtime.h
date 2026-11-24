/*
 * runtime.h - tiny freestanding runtime for the bare-metal QEMU tests.
 *
 * Everything here is callable from C *and* from assembly (AAPCS64):
 *     bl printf      // x0 = fmt, x1.. = args
 *     bl malloc      // x0 = size  -> x0 = pointer
 */
#ifndef LEET_RUNTIME_H
#define LEET_RUNTIME_H

#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* ---- console (PL011 UART, shows up in the terminal) -------------------- */
int  putchar(int c);
int  puts(const char *s);                       /* appends '\n'            */
int  printf(const char *fmt, ...);              /* %d %i %u %x %X %p %s %c %%,
                                                   l/ll/z modifiers, width,
                                                   '-' and '0' flags        */
int  vprintf(const char *fmt, va_list ap);
void print_int_array(const int *a, int n);      /* prints "[1, 2, 3]"      */

/* ---- memory ------------------------------------------------------------- */
void *malloc(size_t size);                      /* bump allocator, 16-aligned */
void *calloc(size_t n, size_t size);
void  free(void *p);                            /* no-op                   */
void *memset(void *dst, int c, size_t n);
void *memcpy(void *dst, const void *src, size_t n);
void *memmove(void *dst, const void *src, size_t n);
int   memcmp(const void *a, const void *b, size_t n);
size_t strlen(const char *s);

/* ---- control ------------------------------------------------------------ */
_Noreturn void rt_exit(int code);               /* QEMU exits with `code`  */
uint64_t rt_cycles(void);                       /* virtual counter ticks   */

/* ---- testing -------------------------------------------------------------
 *   int main(void) {
 *       EXPECT_EQ(add(2, 3), 5);
 *       EXPECT_ARRAY_EQ(out, ((int[]){0, 1}), 2);
 *       return TEST_SUMMARY();      // exit code 0 = all passed
 *   }
 */
bool rt_expect_eq(long long actual, long long expected,
                  const char *expr, const char *file, int line);
bool rt_expect_array_eq(const int *actual, const int *expected, int n,
                        const char *expr, const char *file, int line);
bool rt_expect_true(bool cond, const char *expr, const char *file, int line);
int  rt_test_summary(void);

#define EXPECT_EQ(actual, expected) \
    rt_expect_eq((long long)(actual), (long long)(expected), #actual, __FILE__, __LINE__)
#define EXPECT_TRUE(cond) \
    rt_expect_true((cond), #cond, __FILE__, __LINE__)
#define EXPECT_ARRAY_EQ(actual, expected, n) \
    rt_expect_array_eq((actual), (expected), (n), #actual, __FILE__, __LINE__)
#define TEST_SUMMARY() rt_test_summary()

#define ARRAY_LEN(a) ((int)(sizeof(a) / sizeof((a)[0])))

#endif
