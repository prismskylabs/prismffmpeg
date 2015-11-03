set(_target_name arm-linux-gnueabihf)
set(_openssl_target linux-armv4)

if(NOT EXISTS $ENV{ISD_TOP_DIR})
    message(FATAL_ERROR "ISD_TOP_DIR not found: '$ENV{ISD_TOP_DIR}'")
endif()
message(STATUS "ISD_TOP_DIR: '$ENV{ISD_TOP_DIR}'")

set(_target_root "$ENV{ISD_TOP_DIR}")

if(Debug)
    message("Debug is true")
endif()

set(_target_C_FLAGS "-mfloat-abi=hard -mfpu=neon -mcpu=cortex-a9 -O2")
set(_target_CXX_FLAGS ${_target_C_FLAGS})
set(_target_EXE_LINKER_FLAGS
    "-s -z muldefs -L${_target_root}/lib -L${_target_root}/${_target_name}/lib -Wl,-rpath-link=${_target_root}/lib:${_target_root}/${_target_name}/lib -lrt")

foreach(_i C_FLAGS CXX_FLAGS EXE_LINKER_FLAGS)
    if(NOT CMAKE_${_i}_INIT MATCHES ${_target_${_i}})
        string(STRIP "${CMAKE_${_i}_INIT} ${_target_${_i}}" CMAKE_${_i}_INIT)
    endif()
endforeach()
        
if(DEFINED _included_${CMAKE_CURRENT_LIST_FILE})
    return()
endif()
set(_included_${CMAKE_CURRENT_LIST_FILE} 1)

set(ISD 1)
add_definitions(-DISD)

set(EMBEDDED 1)
add_definitions(-DEMBEDDED)

set(PRISM_CPP_API 1)
add_definitions(-DPRISM_CPP_API)

set(CMAKE_C_COMPILER ${_target_name}-gcc)
set(CMAKE_CXX_COMPILER ${_target_name}-g++)

if(CCACHE)
    set(CMAKE_C_COMPILER "${CCACHE}" ${CMAKE_C_COMPILER})
    set(CMAKE_CXX_COMPILER "${CCACHE}" ${CMAKE_CXX_COMPILER})
endif()

set(CMAKE_FIND_ROOT_PATH "${_target_root}")
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)

set(CMAKE_SYSTEM_NAME Linux)

set(CMAKE_USER_MAKE_RULES_OVERRIDE ${CMAKE_CURRENT_LIST_FILE})

set(CMAKE_INCLUDE_PATH "${_target_root}/${_target_name}/include")
set(CMAKE_LIBRARY_PATH "${_target_root}/${_target_name}/lib")
