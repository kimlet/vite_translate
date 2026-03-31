Pod::Spec.new do |s|
  s.name             = 'vibe_translate_native'
  s.version          = '1.0.0'
  s.summary          = 'whisper.cpp and translation bridges for vibeTranslate'
  s.homepage         = 'https://github.com/example/vibe_translate'
  s.license          = { :type => 'MIT', :text => 'MIT' }
  s.author           = 'vibeTranslate'
  s.ios.deployment_target = '16.0'
  s.source           = { :path => '.' }

  s.source_files = [
    # Bridge files
    'bridge/*.{c,cpp,h}',

    # Whisper core
    'whisper.cpp/src/whisper.cpp',
    'whisper.cpp/src/*.h',
    'whisper.cpp/include/*.h',

    # GGML core
    'whisper.cpp/ggml/src/ggml.c',
    'whisper.cpp/ggml/src/ggml.cpp',
    'whisper.cpp/ggml/src/ggml-alloc.c',
    'whisper.cpp/ggml/src/ggml-backend.cpp',
    'whisper.cpp/ggml/src/ggml-backend-reg.cpp',
    'whisper.cpp/ggml/src/ggml-backend-dl.cpp',
    'whisper.cpp/ggml/src/ggml-opt.cpp',
    'whisper.cpp/ggml/src/ggml-threading.cpp',
    'whisper.cpp/ggml/src/ggml-quants.c',
    'whisper.cpp/ggml/src/gguf.cpp',
    'whisper.cpp/ggml/src/*.h',
    'whisper.cpp/ggml/include/*.h',

    # GGML CPU backend
    'whisper.cpp/ggml/src/ggml-cpu/*.{c,cpp,h}',
    'whisper.cpp/ggml/src/ggml-cpu/amx/*.{c,cpp,h}',
    'whisper.cpp/ggml/src/ggml-cpu/arch/arm/*.{c,cpp}',
    'whisper.cpp/ggml/src/ggml-cpu/arch-fallback.h',

    # GGML Metal backend (uncomment when Metal Toolchain is installed)
    # 'whisper.cpp/ggml/src/ggml-metal/*.{c,cpp,m,h}',
  ]

  s.public_header_files = [
    'bridge/whisper_bridge.h',
    'bridge/ct2_bridge.h',
  ]

  s.preserve_paths = [
    'whisper.cpp/**/*',
    'bridge/**/*',
  ]

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => [
      '"$(PODS_TARGET_SRCROOT)/whisper.cpp/include"',
      '"$(PODS_TARGET_SRCROOT)/whisper.cpp/ggml/include"',
      '"$(PODS_TARGET_SRCROOT)/whisper.cpp/ggml/src"',
      '"$(PODS_TARGET_SRCROOT)/whisper.cpp/ggml/src/ggml-cpu"',
      '"$(PODS_TARGET_SRCROOT)/whisper.cpp/ggml/src/ggml-metal"',
      '"$(PODS_TARGET_SRCROOT)/whisper.cpp/src"',
      '"$(PODS_TARGET_SRCROOT)/bridge"',
    ].join(' '),
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) GGML_USE_ACCELERATE=1 NDEBUG=1 WHISPER_USE_COREML=0',
    'OTHER_CFLAGS' => '-O3 -DNDEBUG -Wno-shorten-64-to-32 -Wno-comma',
    'OTHER_CPLUSPLUSFLAGS' => '-O3 -DNDEBUG -std=c++17 -Wno-shorten-64-to-32 -Wno-comma',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }

  s.dependency 'Flutter'
  s.frameworks = ['Accelerate', 'Foundation']
  s.libraries = ['c++']

  # Metal support: uncomment below and add GGML_USE_METAL=1 to preprocessor defs
  # when Metal Toolchain is installed in Xcode.
  # s.frameworks += ['Metal', 'MetalKit']
  # s.resource_bundles = {
  #   'whisper_metal' => ['whisper.cpp/ggml/src/ggml-metal/ggml-metal.metal']
  # }
end
