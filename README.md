# Simple C++20 module support for CMake

Provides the `add_module_library` CMake function that is a wrapper around `add_library` with additional rules to generate `.pcm` files.

`hello.cc`:
```c++
export module hello;

#include <cstdio>

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

Building with clang 16:

```
CXX=clang++-16 cmake .
make
```

Running:

```
$ ./main
Hello, modules!
```
