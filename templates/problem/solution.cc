// NNNN. Title - https://leetcode.com/problems/<slug>/
// Idea:
// Time O(?), space O(?)
#include <vector>

#include "test.hpp"

using namespace std;

class Solution {
public:
    int solve(vector<int>& nums)
    {
        (void)nums;
        return 0;
    }
};

int main()
{
    {
        vector<int> nums{1, 2, 3};
        EXPECT_EQ(Solution().solve(nums), 0);
    }
    return TEST_SUMMARY();
}
