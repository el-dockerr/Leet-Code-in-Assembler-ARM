// 1. Add two Numbers - https://leetcode.com/problems/add-two-numbers/
//
// Time: O(max(m,n)) 
// Space O(1) 
//
// Adding both lists in parallel into a new TreeNode
// 
// Author: Swen Kalski

#include <memory>
#include <vector>

#include "test.h"

using namespace std;

struct ListNode {
 int val;
 ListNode *next;

 ListNode() : val(0), next(nullptr) {}
 ListNode(int x) : val(x), next(nullptr) {}
 ListNode(int x, ListNode *next) : val(x), next(next) {}
 ~ListNode(){ delete next;}
};

class Solution {
 public:
  ListNode* addTwoNumbers(ListNode* l1, ListNode* l2) {
    ListNode dummy(0);
    ListNode* curr = &dummy;
    int carry = 0;

    while (l1 != nullptr || l2 != nullptr || carry != 0) {
      int sum = carry;
      if (l1 != nullptr) {
        sum += l1->val;
        l1 = l1->next;
      }
      if (l2 != nullptr) {
        sum += l2->val;
        l2 = l2->next;
      }

      carry = sum / 10;
      curr->next = new ListNode(sum % 10);
      curr = curr->next;
    }

    ListNode* head = dummy.next;
    dummy.next = nullptr;  // ~ListNode would otherwise delete the result
    return head;
  }
};

/*
* TODO: Since we will fiddle around with TreeNodes a lot, I might
* add it to a header file to make my live a bit easier.
*/

// Builds a list from digits (least significant first). Caller owns it.
static ListNode* makeList(const vector<int>& digits)
{
  ListNode* head = nullptr;
  for (auto it = digits.rbegin(); it != digits.rend(); ++it)
    head = new ListNode(*it, head);
  return head;
}

static vector<int> toVector(const ListNode* l)
{
  vector<int> out;
  for (; l != nullptr; l = l->next) out.push_back(l->val);
  return out;
}

// Runs the solution on two digit vectors and frees every list afterwards.
static vector<int> add(const vector<int>& a, const vector<int>& b)
{
  unique_ptr<ListNode> l1(makeList(a));
  unique_ptr<ListNode> l2(makeList(b));
  unique_ptr<ListNode> result(Solution().addTwoNumbers(l1.get(), l2.get()));
  return toVector(result.get());
}

int main()
{
  // LeetCode examples
  EXPECT_EQ(add({2, 4, 3}, {5, 6, 4}), (vector<int>{7, 0, 8}));        // 342 + 465 = 807
  EXPECT_EQ(add({0}, {0}), (vector<int>{0}));
  EXPECT_EQ(add({9, 9, 9, 9, 9, 9, 9}, {9, 9, 9, 9}),
            (vector<int>{8, 9, 9, 9, 0, 0, 0, 1}));

  // Different lengths, carry ripples through the longer list
  EXPECT_EQ(add({1}, {9, 9}), (vector<int>{0, 0, 1}));                 // 1 + 99 = 100
  EXPECT_EQ(add({9, 9}, {1}), (vector<int>{0, 0, 1}));
  // Final carry creates a new node
  EXPECT_EQ(add({5}, {5}), (vector<int>{0, 1}));
  // No carry at all
  EXPECT_EQ(add({1, 2, 3}, {4, 5, 6}), (vector<int>{5, 7, 9}));
  // One operand is 0
  EXPECT_EQ(add({0}, {7, 3}), (vector<int>{7, 3}));

  return TEST_SUMMARY();
}
