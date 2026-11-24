// 1. Two Sum - https://leetcode.com/problems/two-sum/
//
// Time: O(n) 
// Space O(n) 
//
// Remember every value's index, look up the complement.
// 
// Author: Swen Kalski

#include <unordered_map>
#include <vector>

#include "test.h"

using namespace std;

class Solution {
public:
    vector<int> twoSum(vector<int>& nums, int target)
    {
        unordered_map<int, int> seen;   // value -> index
        for (int i = 0; i < (int)nums.size(); ++i) {
            auto it = seen.find(target - nums[i]);
            if (it != seen.end()) return {it->second, i};
            seen[nums[i]] = i;
        }
        return {};
    }
};

int main()
{
    {
        vector<int> nums{2, 7, 11, 15};
        EXPECT_EQ(Solution().twoSum(nums, 9), (vector<int>{0, 1}));
    }
    {
        vector<int> nums{3, 2, 4};
        EXPECT_EQ(Solution().twoSum(nums, 6), (vector<int>{1, 2}));
    }
    {
        vector<int> nums{3, 3};
        EXPECT_EQ(Solution().twoSum(nums, 6), (vector<int>{0, 1}));
    }
    {
        vector<int> nums{-1000000000, 5, 1000000000};
        EXPECT_EQ(Solution().twoSum(nums, 0), (vector<int>{0, 2}));
    }
    return TEST_SUMMARY();
}
