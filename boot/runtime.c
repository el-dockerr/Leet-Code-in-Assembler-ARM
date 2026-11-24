/*
 * runtime.c - console, memory, test helpers and crash reporting.
 * Freestanding: no libc, built with clang --target=aarch64-none-elf.
 */
#include "runtime.h"

/* ======================================================================= */
/* PL011 UART on QEMU virt                                                 */
/* ======================================================================= */
#define UART0_BASE 0x09000000UL
#define UART_DR    (*(volatile uint32_t *)(UART0_BASE + 0x00))
#define UART_FR    (*(volatile uint32_t *)(UART0_BASE + 0x18))
#define UART_TXFF  (1u << 5)

int putchar(int c)
{
    if (c == '\n') {
        while (UART_FR & UART_TXFF) {}
        UART_DR = '\r';
    }
    while (UART_FR & UART_TXFF) {}
    UART_DR = (uint32_t)(unsigned char)c;
    return c;
}

static void put_str(const char *s)
{
    while (*s) putchar(*s++);
}

int puts(const char *s)
{
    put_str(s);
    putchar('\n');
    return 0;
}

/* ======================================================================= */
/* printf                                                                  */
/* ======================================================================= */
static void put_padded(const char *s, int len, int width, bool left, char pad)
{
    if (!left) for (int i = len; i < width; i++) putchar(pad);
    for (int i = 0; i < len; i++) putchar(s[i]);
    if (left) for (int i = len; i < width; i++) putchar(' ');
}

static int fmt_unsigned(char *buf, unsigned long long v, unsigned base, bool upper)
{
    const char *digits = upper ? "0123456789ABCDEF" : "0123456789abcdef";
    char tmp[24];
    int n = 0;
    do { tmp[n++] = digits[v % base]; v /= base; } while (v);
    for (int i = 0; i < n; i++) buf[i] = tmp[n - 1 - i];
    return n;
}

int vprintf(const char *fmt, va_list ap)
{
    for (; *fmt; fmt++) {
        if (*fmt != '%') { putchar(*fmt); continue; }
        fmt++;

        bool left = false; char pad = ' ';
        for (;; fmt++) {
            if (*fmt == '-') left = true;
            else if (*fmt == '0') pad = '0';
            else break;
        }
        int width = 0;
        while (*fmt >= '0' && *fmt <= '9') width = width * 10 + (*fmt++ - '0');

        int lng = 0;
        while (*fmt == 'l') { lng++; fmt++; }
        if (*fmt == 'z') { lng = 2; fmt++; }

        char buf[32];
        int len = 0;
        switch (*fmt) {
        case 'd': case 'i': {
            long long v = lng ? va_arg(ap, long long) : va_arg(ap, int);
            unsigned long long u = v < 0 ? 0ULL - (unsigned long long)v : (unsigned long long)v;
            if (v < 0) buf[len++] = '-';
            len += fmt_unsigned(buf + len, u, 10, false);
            break;
        }
        case 'u': case 'x': case 'X': {
            unsigned long long v = lng ? va_arg(ap, unsigned long long) : va_arg(ap, unsigned);
            len = fmt_unsigned(buf, v, *fmt == 'u' ? 10 : 16, *fmt == 'X');
            break;
        }
        case 'p':
            buf[0] = '0'; buf[1] = 'x';
            len = 2 + fmt_unsigned(buf + 2, (uintptr_t)va_arg(ap, void *), 16, false);
            break;
        case 'c':
            buf[len++] = (char)va_arg(ap, int);
            break;
        case 's': {
            const char *s = va_arg(ap, const char *);
            if (!s) s = "(null)";
            put_padded(s, (int)strlen(s), width, left, ' ');
            continue;
        }
        case '%':
            putchar('%');
            continue;
        default:            /* unknown: print verbatim */
            putchar('%');
            if (!*fmt) return 0;
            putchar(*fmt);
            continue;
        }
        if (pad == '0' && !left && buf[0] == '-') {     /* -0042, not 00-42 */
            putchar('-');
            put_padded(buf + 1, len - 1, width - 1, false, '0');
        } else {
            put_padded(buf, len, width, left, left ? ' ' : pad);
        }
    }
    return 0;
}

int printf(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vprintf(fmt, ap);
    va_end(ap);
    return 0;
}

void print_int_array(const int *a, int n)
{
    putchar('[');
    for (int i = 0; i < n; i++) printf(i ? ", %d" : "%d", a[i]);
    putchar(']');
}

/* ======================================================================= */
/* memory                                                                  */
/* ======================================================================= */
extern char __heap_start[], __heap_end[];
static char *heap_ptr = __heap_start;

void *malloc(size_t size)
{
    size = (size + 15) & ~(size_t)15;
    if (size > (size_t)(__heap_end - heap_ptr)) {
        printf("\n*** malloc(%zu): out of memory (heap is %zu bytes)\n",
               size, (size_t)(__heap_end - __heap_start));
        rt_exit(98);
    }
    void *p = heap_ptr;
    heap_ptr += size;
    return p;
}

void *calloc(size_t n, size_t size)
{
    void *p = malloc(n * size);
    return memset(p, 0, n * size);
}

void free(void *p) { (void)p; }

void *memset(void *dst, int c, size_t n)
{
    unsigned char *d = dst;
    while (n--) *d++ = (unsigned char)c;
    return dst;
}

void *memcpy(void *dst, const void *src, size_t n)
{
    unsigned char *d = dst;
    const unsigned char *s = src;
    while (n--) *d++ = *s++;
    return dst;
}

void *memmove(void *dst, const void *src, size_t n)
{
    unsigned char *d = dst;
    const unsigned char *s = src;
    if (d < s) while (n--) *d++ = *s++;
    else       while (n--) d[n] = s[n];
    return dst;
}

int memcmp(const void *a, const void *b, size_t n)
{
    const unsigned char *x = a, *y = b;
    for (; n; n--, x++, y++) if (*x != *y) return *x - *y;
    return 0;
}

size_t strlen(const char *s)
{
    size_t n = 0;
    while (s[n]) n++;
    return n;
}

uint64_t rt_cycles(void)
{
    uint64_t v;
    __asm__ volatile("isb; mrs %0, cntvct_el0" : "=r"(v));
    return v;
}

/* ======================================================================= */
/* tests                                                                   */
/* ======================================================================= */
static int checks_run, checks_failed;

static void report_fail(const char *expr, const char *file, int line)
{
    checks_failed++;
    printf("  FAIL  %s:%d: %s\n", file, line, expr);
}

bool rt_expect_eq(long long actual, long long expected,
                  const char *expr, const char *file, int line)
{
    checks_run++;
    if (actual == expected) return true;
    report_fail(expr, file, line);
    printf("        expected %lld, got %lld\n", expected, actual);
    return false;
}

bool rt_expect_true(bool cond, const char *expr, const char *file, int line)
{
    checks_run++;
    if (cond) return true;
    report_fail(expr, file, line);
    return false;
}

bool rt_expect_array_eq(const int *actual, const int *expected, int n,
                        const char *expr, const char *file, int line)
{
    checks_run++;
    if (memcmp(actual, expected, (size_t)n * sizeof(int)) == 0) return true;
    report_fail(expr, file, line);
    printf("        expected "); print_int_array(expected, n);
    printf("\n        got      "); print_int_array(actual, n);
    putchar('\n');
    return false;
}

int rt_test_summary(void)
{
    if (checks_failed)
        printf("FAILED  %d of %d checks\n", checks_failed, checks_run);
    else
        printf("PASSED  %d checks\n", checks_run);
    return checks_failed ? 1 : 0;
}

/* ======================================================================= */
/* crash reporting (called from the vector table in start.S)               */
/* ======================================================================= */
static const char *ec_name(unsigned ec)
{
    switch (ec) {
    case 0x00: return "unknown / undefined instruction";
    case 0x07: return "FP/SIMD access trapped";
    case 0x0e: return "illegal execution state";
    case 0x15: return "SVC instruction";
    case 0x18: return "MSR/MRS trapped";
    case 0x20: case 0x21: return "instruction abort (bad branch target?)";
    case 0x22: return "PC alignment fault";
    case 0x24: case 0x25: return "data abort (bad pointer / out of bounds?)";
    case 0x26: return "SP alignment fault (sp must stay 16-byte aligned)";
    case 0x2c: return "floating-point exception";
    case 0x3c: return "BRK instruction";
    default:   return "see ARM ARM, ESR_ELx.EC";
    }
}

void rt_exception(uint64_t vector, uint64_t esr, uint64_t elr, uint64_t far)
{
    static const char *const kind[4] = { "sync", "IRQ", "FIQ", "SError" };
    unsigned ec = (unsigned)(esr >> 26) & 0x3f;
    printf("\n*** CPU exception: %s (vector %u)\n", kind[vector & 3], (unsigned)vector);
    printf("    ESR_EL1 = 0x%lx  (EC 0x%x: %s)\n", esr, ec, ec_name(ec));
    printf("    ELR_EL1 = 0x%lx  <- faulting instruction\n", elr);
    printf("    FAR_EL1 = 0x%lx  <- faulting address\n", far);
    printf("    hint: llvm-addr2line -f -e <elf> 0x%lx\n", elr);
    rt_exit(99);
}
