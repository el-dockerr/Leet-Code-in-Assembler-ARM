/*
 * 2. Add Two Numbers - https://leetcode.com/problems/add-two-numbers/
 *
 * struct ListNode { int val; struct ListNode *next; };   // 16 bytes
 * struct ListNode *add_two_numbers(const struct ListNode *l1,
 *                                  const struct ListNode *l2);
 *
 * Same approach as the C++ source: walk both lists in parallel, add the
 * digits plus carry and append a freshly malloced node to the result.
 * A dummy head node lives on the stack, so appending never needs a
 * special case for the first node.
 *
 *
 * malloced?? malloc'd?? both look wrong to me.
 *
 * sum = d1 + d2 + carry is at most 9 + 9 + 1 = 19, so no division is
 * needed:  carry = (sum >= 10),  digit = carry ? sum - 10 : sum.
 *
 * Time: O(max(m,n))   Space: O(1) besides the result list. So same as
 * the C++ approach.
 *
 * Node layout:  [node, #0] = val (w)   [node, #8] = next (x)
 *
 * Registers (AAPCS64):
 *   x0 = l1     x1 = l2      result (head of new list) in x0
 *   x19 = l1    x20 = l2     x21 = tail      w22 = carry    w23 = digit
 *   x19-x23 are callee-saved, so they survive the calls to malloc.
 *
 * Stack frame (80 bytes):
 *   [sp, #0]  x29, x30      [sp, #16] x19, x20
 *   [sp, #32] x21, x22      [sp, #48] x23
 *   [sp, #64] dummy.val     [sp, #72] dummy.next
 *
 * Author: Swen Kalski
 */
        .text
        .global add_two_numbers
        .type   add_two_numbers, %function
add_two_numbers:
        stp     x29, x30, [sp, #-80]!
        mov     x29, sp
        stp     x19, x20, [sp, #16]
        stp     x21, x22, [sp, #32]
        str     x23, [sp, #48]

        mov     x19, x0                         // l1
        mov     x20, x1                         // l2
        str     xzr, [sp, #72]                  // dummy.next = NULL
        add     x21, sp, #64                    // tail = &dummy
        mov     x22, #0                         // carry = 0 (whole x22)

.Lloop:
        orr     x9, x19, x20
        orr     x9, x9, x22
        cbz     x9, .Ldone                      // !l1 && !l2 && !carry

        mov     w9, w22                         // sum = carry
        cbz     x19, .Lskip_l1
        ldr     w10, [x19]                      // sum += l1->val
        add     w9, w9, w10
        ldr     x19, [x19, #8]                  // l1 = l1->next
.Lskip_l1:
        cbz     x20, .Lskip_l2
        ldr     w10, [x20]                      // sum += l2->val
        add     w9, w9, w10
        ldr     x20, [x20, #8]                  // l2 = l2->next
.Lskip_l2:
        cmp     w9, #10
        cset    w22, hs                         // carry = sum >= 10
        sub     w10, w9, #10
        csel    w23, w10, w9, hs                // digit = carry ? 
                                                // sum-10 : sum

        mov     x0, #16
        bl      malloc                          // x0 = new node
        str     w23, [x0]                       // node->val  = digit
        str     xzr, [x0, #8]                   // node->next = NULL
        str     x0, [x21, #8]                   // tail->next = node
        mov     x21, x0                         // tail = node
        b       .Lloop

.Ldone:
        ldr     x0, [sp, #72]                   // return dummy.next

        ldr     x23, [sp, #48]
        ldp     x21, x22, [sp, #32]
        ldp     x19, x20, [sp, #16]
        ldp     x29, x30, [sp], #80
        ret
        .size   add_two_numbers, . - add_two_numbers
