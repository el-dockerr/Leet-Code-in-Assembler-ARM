// test.h - minimal header-only test helpers for the native C++ solutions.
//
//   #include "test.h"
//   int main() {
//       EXPECT_EQ(Solution().twoSum(nums, 9), (std::vector<int>{0, 1}));
//       return TEST_SUMMARY();
//   }
#pragma once

#include <iostream>
#include <sstream>
#include <string>
#include <type_traits>
#include <vector>

namespace leet {

template <class T>
std::string show(const T& v);

template <class T>
std::string show(const std::vector<T>& v)
{
    std::string s = "[";
    for (size_t i = 0; i < v.size(); ++i) s += (i ? ", " : "") + show(v[i]);
    return s + "]";
}

template <class T>
std::string show(const T& v)
{
    if constexpr (std::is_same_v<T, bool>) return v ? "true" : "false";
    else if constexpr (std::is_convertible_v<T, std::string>) return "\"" + std::string(v) + "\"";
    else { std::ostringstream os; os << v; return os.str(); }
}

inline int checks_run = 0;
inline int checks_failed = 0;

template <class A, class E>
bool expect_eq(const A& actual, const E& expected, const char* expr, const char* file, int line)
{
    ++checks_run;
    if (actual == expected) return true;
    ++checks_failed;
    std::cout << "  FAIL  " << file << ":" << line << ": " << expr << "\n"
              << "        expected " << show(expected) << ", got " << show(actual) << "\n";
    return false;
}

inline int summary()
{
    if (checks_failed)
        std::cout << "FAILED  " << checks_failed << " of " << checks_run << " checks\n";
    else
        std::cout << "PASSED  " << checks_run << " checks\n";
    return checks_failed ? 1 : 0;
}

} // namespace leet

#define EXPECT_EQ(actual, expected) ::leet::expect_eq((actual), (expected), #actual, __FILE__, __LINE__)
#define EXPECT_TRUE(cond)           ::leet::expect_eq(static_cast<bool>(cond), true, #cond, __FILE__, __LINE__)
#define TEST_SUMMARY()              ::leet::summary()
