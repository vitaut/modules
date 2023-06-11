# Simple C++20 module support for CMake

[![](https://github.com/vitaut/modules/workflows/linux/badge.svg)](https://github.com/vitaut/modules/actions?query=workflow%3Alinux)
[![](https://github.com/vitaut/modules/workflows/windows/badge.svg)](https://github.com/vitaut/modules/actions?query=workflow%3Awindows)

Provides the `add_module_library` CMake function that is a wrapper around `add_library` with additional module-specific rules. 

This module currently supports:
* Clang 15+ 
* GCC 11+
* MSVC 19.28+

This module can also fallback to a non-modular library for compatibility.

Projects using `add_module_library`:

* [{fmt}](https://github.com/fmtlib/fmt): a modern formatting library

## Example

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
project(HELLO CXX)

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

## License

The code is distributed under the permissive `MIT license
<https://github.com/vitaut/modules/blob/d7d015ae07681b0c003e8c8feffac08c8b3e9dd3/modules.cmake#L6-L30>`_
with an optional exception that allows distributing binary code without
attribution.
