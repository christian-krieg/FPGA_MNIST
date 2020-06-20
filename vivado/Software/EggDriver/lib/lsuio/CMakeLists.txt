project(LSUIO)


add_library(lsuio STATIC
    src/attr.c
    src/base.c
    src/helper.c
    src/lsuio.c
    src/mem.c
)


target_include_directories(
    lsuio 
    PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)


