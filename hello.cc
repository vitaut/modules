module;

#include <cstdio>

export module hello;

#include "hello.h"

export void hello() { std::printf("Hello, modules!\n"); }
