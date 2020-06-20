cmake_minimum_required(VERSION 3.10)
project(EggnetDriver C)

# ------------------------------------
# Setup/Options
# ------------------------------------

# Uncomment if there is an "compile with -fPIC" error
# https://wiki.gentoo.org/wiki/Project:AMD64/Fixing_-fPIC_Errors_Guide
# set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Find pthreads
set(THREADS_PREFER_PTHREAD_FLAG ON)

# ------------------------------------
# Find Packages and Requirements
# ------------------------------------
#
# Useful Doc:
# https://cmake.org/cmake/help/latest/command/find_package.html

find_package(Threads REQUIRED)
find_package(SWIG 4 REQUIRED)
find_package(Python 3.6 REQUIRED COMPONENTS Interpreter Devlopment NumPy)

# Activate SWIG
include(UseSWIG)

# Add LSUIO
add_subdirectory(lib/lsuio)



# ------------------------------------
# Eggnet Driver Software (C)
# ------------------------------------

add_library(
    EggnetDriver STATIC
        src/eggdma.c
        src/eggnet.c
        src/eggstatus.c
        src/egguio.c
)

# Setup Include's
target_include_directories(EggnetDriver
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE 
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# Link with lsuio
target_link_libraries(EggnetDriver PRIVATE lsuio)


# For quick debugging
add_executable(EggnetTest src/main.c)
target_link_libraries(EggnetTest PUBLIC EggnetDriver)



# ------------------------------------
# Eggnet Driver Software (Python/Swig)
# ------------------------------------
#
#
# swig_add_library(<name>
#                     [TYPE <SHARED|MODULE|STATIC|USE_BUILD_SHARED_LIBS>]
#                     LANGUAGE <language>
#                     [NO_PROXY]
#                     [OUTPUT_DIR <directory>]
#                     [OUTFILE_DIR <directory>]
#                     SOURCES <file>...
#                    )

swig_add_library(PyEggnetDriver
    LANGUAGE python
    SOURCES src/eggnet.i
)





