export module test;

#include "hello.h"
#include <cstdio>

export void hello() { std::printf("Hello, modules!\n"); }
