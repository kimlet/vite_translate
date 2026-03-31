cmake_minimum_required(VERSION 3.22.1)
project(vibe_translate_native)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_C_STANDARD 11)

# ─── Build whisper.cpp using its own CMake ──────────────────
set(WHISPER_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../whisper.cpp")
set(BRIDGE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../bridge")

# Disable features we don't need on Android
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(GGML_METAL OFF CACHE BOOL "" FORCE)
set(GGML_CUDA OFF CACHE BOOL "" FORCE)
set(GGML_OPENCL OFF CACHE BOOL "" FORCE)

# Use whisper.cpp's own CMake build
add_subdirectory(${WHISPER_DIR} ${CMAKE_BINARY_DIR}/whisper.cpp)

# ─── Whisper Bridge shared library ──────────────────────────
add_library(whisper_bridge SHARED
    ${BRIDGE_DIR}/whisper_bridge.c
)

target_include_directories(whisper_bridge PRIVATE
    ${WHISPER_DIR}/include
    ${BRIDGE_DIR}
)

target_link_libraries(whisper_bridge PRIVATE
    whisper
    log
)

# ─── CTranslate2 Bridge shared library ─────────────────────
add_library(ct2_bridge SHARED
    ${BRIDGE_DIR}/ct2_bridge.cpp
)

target_include_directories(ct2_bridge PRIVATE
    ${BRIDGE_DIR}
)

target_link_libraries(ct2_bridge PRIVATE
    log
)

# ─── SentencePiece Bridge shared library ───────────────────
add_library(sp_bridge SHARED
    ${BRIDGE_DIR}/sentencepiece_bridge.cpp
)

target_include_directories(sp_bridge PRIVATE
    ${BRIDGE_DIR}
)

target_link_libraries(sp_bridge PRIVATE
    log
)
