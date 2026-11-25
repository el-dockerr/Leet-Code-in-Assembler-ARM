/* Test harness for the ASM solution (runs bare-metal in QEMU). */
#include "runtime.h"

struct ListNode {
    int val;
    struct ListNode *next;
};

struct ListNode *add_two_numbers(const struct ListNode *l1,
                                 const struct ListNode *l2);

/* L(1, 2, 3) expands to "array, length", so a whole list fits in one arg. */
#define L(...) (int[]){ __VA_ARGS__ }, ARRAY_LEN(((int[]){ __VA_ARGS__ }))

#define MAX_DIGITS 32

/* Builds a list from digits (least significant first). */
static struct ListNode *make_list(const int *digits, int n)
{
    struct ListNode *head = NULL;
    for (int i = n - 1; i >= 0; --i) {
        struct ListNode *node = malloc(sizeof *node);
        node->val = digits[i];
        node->next = head;
        head = node;
    }
    return head;
}

static void check(const int *a, int na, const int *b, int nb,
                  const int *expected, int ne)
{
    const struct ListNode *l = add_two_numbers(make_list(a, na),
                                               make_list(b, nb));
    int out[MAX_DIGITS];
    int len = 0;
    for (int i = 0; i < MAX_DIGITS; ++i) out[i] = -1;
    for (; l != NULL && len < MAX_DIGITS; l = l->next) out[len++] = l->val;

    EXPECT_EQ(len, ne);
    EXPECT_ARRAY_EQ(out, expected, ne);
}

int main(void)
{
    puts("0002 add-two-numbers (asm)");

    /* LeetCode examples */
    check(L(2, 4, 3), L(5, 6, 4), L(7, 0, 8));              /* 342 + 465 = 807 */
    check(L(0), L(0), L(0));
    check(L(9, 9, 9, 9, 9, 9, 9), L(9, 9, 9, 9),
          L(8, 9, 9, 9, 0, 0, 0, 1));

    /* Different lengths, carry ripples through the longer list */
    check(L(1), L(9, 9), L(0, 0, 1));                       /* 1 + 99 = 100 */
    check(L(9, 9), L(1), L(0, 0, 1));
    /* Final carry creates a new node */
    check(L(5), L(5), L(0, 1));
    /* No carry at all */
    check(L(1, 2, 3), L(4, 5, 6), L(5, 7, 9));
    /* One operand is 0 */
    check(L(0), L(7, 3), L(7, 3));

    return TEST_SUMMARY();
}
