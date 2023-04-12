# Simple C++20 module support for CMake

Provides the `add_module_library` CMake function that is a wrapper around `add_library` with additional rules to generate `.pcm` files. Currently supports clang 15+ and can fallback to a non-modular library for compatibility.

## Usage

`hello.cc`:
```c++
module;

#include <cstdio>

export module hello;

export void hello() { std::printf("Hello, modules!\n"); }
```

`main.cc`:
```c++
import hello;

int main() { hello(); }
```

`CMakeLists.txt`:
```cmake
cmake_minimum_required(VERSION 3.11)
project(HELLO)

# Clang 16 requires extensions to be disabled for modules.
set(CMAKE_CXX_EXTENSIONS OFF)

include(modules.cmake)

add_module_library(hello hello.cc)

add_executable(main main.cc)
target_link_libraries(main hello)
```

Building with clang:

```
CXX=clang++ cmake .
make
```

Running:

```
$ ./main
Hello, modules!
```
