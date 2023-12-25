include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(algorithm_tuner_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(algorithm_tuner_setup_options)
  option(algorithm_tuner_ENABLE_HARDENING "Enable hardening" ON)
  option(algorithm_tuner_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    algorithm_tuner_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    algorithm_tuner_ENABLE_HARDENING
    OFF)

  algorithm_tuner_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR algorithm_tuner_PACKAGING_MAINTAINER_MODE)
    option(algorithm_tuner_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(algorithm_tuner_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(algorithm_tuner_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(algorithm_tuner_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(algorithm_tuner_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(algorithm_tuner_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(algorithm_tuner_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(algorithm_tuner_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(algorithm_tuner_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(algorithm_tuner_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(algorithm_tuner_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(algorithm_tuner_ENABLE_PCH "Enable precompiled headers" OFF)
    option(algorithm_tuner_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(algorithm_tuner_ENABLE_IPO "Enable IPO/LTO" ON)
    option(algorithm_tuner_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(algorithm_tuner_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(algorithm_tuner_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(algorithm_tuner_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(algorithm_tuner_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(algorithm_tuner_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(algorithm_tuner_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(algorithm_tuner_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(algorithm_tuner_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(algorithm_tuner_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(algorithm_tuner_ENABLE_PCH "Enable precompiled headers" OFF)
    option(algorithm_tuner_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      algorithm_tuner_ENABLE_IPO
      algorithm_tuner_WARNINGS_AS_ERRORS
      algorithm_tuner_ENABLE_USER_LINKER
      algorithm_tuner_ENABLE_SANITIZER_ADDRESS
      algorithm_tuner_ENABLE_SANITIZER_LEAK
      algorithm_tuner_ENABLE_SANITIZER_UNDEFINED
      algorithm_tuner_ENABLE_SANITIZER_THREAD
      algorithm_tuner_ENABLE_SANITIZER_MEMORY
      algorithm_tuner_ENABLE_UNITY_BUILD
      algorithm_tuner_ENABLE_CLANG_TIDY
      algorithm_tuner_ENABLE_CPPCHECK
      algorithm_tuner_ENABLE_COVERAGE
      algorithm_tuner_ENABLE_PCH
      algorithm_tuner_ENABLE_CACHE)
  endif()

  algorithm_tuner_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (algorithm_tuner_ENABLE_SANITIZER_ADDRESS OR algorithm_tuner_ENABLE_SANITIZER_THREAD OR algorithm_tuner_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(algorithm_tuner_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(algorithm_tuner_global_options)
  if(algorithm_tuner_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    algorithm_tuner_enable_ipo()
  endif()

  algorithm_tuner_supports_sanitizers()

  if(algorithm_tuner_ENABLE_HARDENING AND algorithm_tuner_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR algorithm_tuner_ENABLE_SANITIZER_UNDEFINED
       OR algorithm_tuner_ENABLE_SANITIZER_ADDRESS
       OR algorithm_tuner_ENABLE_SANITIZER_THREAD
       OR algorithm_tuner_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${algorithm_tuner_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${algorithm_tuner_ENABLE_SANITIZER_UNDEFINED}")
    algorithm_tuner_enable_hardening(algorithm_tuner_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(algorithm_tuner_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(algorithm_tuner_warnings INTERFACE)
  add_library(algorithm_tuner_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  algorithm_tuner_set_project_warnings(
    algorithm_tuner_warnings
    ${algorithm_tuner_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(algorithm_tuner_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(algorithm_tuner_options)
  endif()

  include(cmake/Sanitizers.cmake)
  algorithm_tuner_enable_sanitizers(
    algorithm_tuner_options
    ${algorithm_tuner_ENABLE_SANITIZER_ADDRESS}
    ${algorithm_tuner_ENABLE_SANITIZER_LEAK}
    ${algorithm_tuner_ENABLE_SANITIZER_UNDEFINED}
    ${algorithm_tuner_ENABLE_SANITIZER_THREAD}
    ${algorithm_tuner_ENABLE_SANITIZER_MEMORY})

  set_target_properties(algorithm_tuner_options PROPERTIES UNITY_BUILD ${algorithm_tuner_ENABLE_UNITY_BUILD})

  if(algorithm_tuner_ENABLE_PCH)
    target_precompile_headers(
      algorithm_tuner_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(algorithm_tuner_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    algorithm_tuner_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(algorithm_tuner_ENABLE_CLANG_TIDY)
    algorithm_tuner_enable_clang_tidy(algorithm_tuner_options ${algorithm_tuner_WARNINGS_AS_ERRORS})
  endif()

  if(algorithm_tuner_ENABLE_CPPCHECK)
    algorithm_tuner_enable_cppcheck(${algorithm_tuner_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(algorithm_tuner_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    algorithm_tuner_enable_coverage(algorithm_tuner_options)
  endif()

  if(algorithm_tuner_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(algorithm_tuner_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(algorithm_tuner_ENABLE_HARDENING AND NOT algorithm_tuner_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR algorithm_tuner_ENABLE_SANITIZER_UNDEFINED
       OR algorithm_tuner_ENABLE_SANITIZER_ADDRESS
       OR algorithm_tuner_ENABLE_SANITIZER_THREAD
       OR algorithm_tuner_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    algorithm_tuner_enable_hardening(algorithm_tuner_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
