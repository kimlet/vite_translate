cmake_minimum_required(VERSION 3.18)
project(vibe_translate_native)

# ─── whisper.cpp ────────────────────────────────────────────
# Add whisper.cpp as a subdirectory (git submodule)
# whisper.cpp builds libwhisper as a static library
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/whisper.cpp/CMakeLists.txt")
  add_subdirectory(whisper.cpp)
endif()

# ─── Whisper Bridge ─────────────────────────────────────────
add_library(whisper_bridge SHARED
  bridge/whisper_bridge.c
)

target_include_directories(whisper_bridge PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/whisper.cpp/include
  ${CMAKE_CURRENT_SOURCE_DIR}/bridge
)

if(TARGET whisper)
  target_link_libraries(whisper_bridge PRIVATE whisper)
endif()

# ─── CTranslate2 Bridge ────────────────────────────────────
# CTranslate2 needs to be pre-built or built from source.
# For mobile, this is typically done as a separate build step.
add_library(ct2_bridge SHARED
  bridge/ct2_bridge.cpp
)

target_include_directories(ct2_bridge PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/bridge
)

# When CTranslate2 is available:
# find_package(CTranslate2 REQUIRED)
# target_link_libraries(ct2_bridge PRIVATE CTranslate2::CTranslate2)

# ─── Installation ───────────────────────────────────────────
install(TARGETS whisper_bridge ct2_bridge
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
)
