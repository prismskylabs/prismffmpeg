cmake_minimum_required(VERSION 2.8.8)
set(ffmpeg_binary_dir ${CMAKE_CURRENT_BINARY_DIR}/ffmpeg)
set(ffmpeg_install_prefix ${ffmpeg_binary_dir}/root)
# pkg-config (.pc) files will be installed here.
set(ffmpeg_pkg_config_path ${ffmpeg_install_prefix}/lib/pkgconfig)
set(ffmpeg_source_dir ${CMAKE_CURRENT_SOURCE_DIR}/src)

if(WIN32)
    set(FFMPEG_LIB_DIR ${ffmpeg_install_prefix}/bin CACHE INTERNAL "")
else()
    set(FFMPEG_LIB_DIR ${ffmpeg_install_prefix}/lib CACHE INTERNAL "")
endif()
set(FFMPEG_INCLUDE_DIR ${ffmpeg_install_prefix}/include CACHE INTERNAL "")
if(WIN32)
    message(STATUS "Checking FFmpeg source for bad line endings")
    file(
        GLOB files FOLLOW_SYMLINKS
        ${ffmpeg_source_dir}/*.mak ${ffmpeg_source_dir}/Makefile
        ${ffmpeg_source_dir}/configure ${ffmpeg_source_dir}/lib*/Makefile)
    foreach(file ${files})
        file(READ ${file} file_content_as_hex HEX)
        if(file_content_as_hex MATCHES "0d0a")
            message(
                FATAL_ERROR
                "${file} contains CRLF line endings, which break the FFmpeg"
                " build system.  Switch to LF line endings to proceed,"
                " perhaps like this:"
                "\n"
                " cd ${ffmpeg_source_dir} && "
                "git config --local --replace core.autocrlf false && "
                "rm -r * && git reset --hard")
        endif()
    endforeach()
endif()

execute_process(COMMAND mkdir -p ${ffmpeg_binary_dir} RESULT_VARIABLE result1)
if(APPLE AND NOT DEBUG)
    set(FFMPEG_FLAGS "--enable-opencl")
endif()
if(WIN32)
    set(FFMPEG_FLAGS ${FFMPEG_FLAGS}  --disable-w32threads --enable-pthreads)
    set(PTHREADS_WIN32_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pthreads-win32 CACHE INTERNAL "")
    MESSAGE("ffmpeg PTHREADS_WIN32_DIR: ${PTHREADS_WIN32_DIR}    CMAKE_CURRENT_SOURCE_DIR: ${CMAKE_CURRENT_SOURCE_DIR}")
    file(COPY ${PTHREADS_WIN32_DIR}/include DESTINATION ${ffmpeg_install_prefix})
    MESSAGE("COPY PTHREADS: ${EXECUTABLE_OUTPUT_PATH}/${WIN_CONFIG_DIR}/pthreadGC2.dll")
    file(COPY ${PTHREADS_WIN32_DIR}/dll/x86/pthreadGC2.dll DESTINATION "${EXECUTABLE_OUTPUT_PATH}/${WIN_CONFIG_DIR}")
endif()

if(USE_H264 AND NOT PRISM_CPP_API)
    set(FFMPEG_FLAGS ${FFMPEG_FLAGS} --enable-gpl --enable-encoder=libx264,mjpeg,libvpx_vp8,libvpx_vp9 --enable-libx264)
    include(${CMAKE_CURRENT_SOURCE_DIR}/Findx264.cmake)
endif()

if(NOT PRISM_CPP_API)
    set(FFMPEG_CROSS --enable-runtime-cpudetect)
    set(FFMPEG_FLAGS ${FFMPEG_FLAGS}
         --enable-decoder=h264,mjpeg,mpeg4,msmpeg4v1,msmpeg4v2,msmpeg4v3,vp8
         --enable-demuxer=asf,avi,h264,matroska,m4v,mjpeg,mpegts,mpegtsraw,rtsp,flv
         --enable-muxer=avi,h264,mjpeg,rtsp,webm,matroska,mp4,m4v
         --enable-hwaccel=h264_vda,h264_vdpau
         --enable-parser=h264,mjpeg,vp8,mpeg4video
         --enable-protocol=file,pipe,rtp,tcp,udp,http,https,httpproxy )
else()
    if (EMBEDDED)
        set(FFMPEG_CROSS --enable-cross-compile
            --cross-prefix=$ENV{ISD_TOP_DIR}/bin/arm-linux-gnueabihf- --arch=arm --target-os=linux
            --extra-ldflags="-L$ENV{ISD_TOP_DIR}/lib" --disable-yasm
            --enable-pic --disable-thumb)
    endif()
    set(FFMPEG_FLAGS ${FFMPEG_FLAGS}
         --enable-decoder=h264,mjpeg,mpeg4
         --enable-demuxer=h264,avi,h264,matroska,m4v,mjpeg,rtsp,mpegts,mpegtsraw
         --enable-muxer=avi,h264,mjpeg,matroska,rtsp,mp4
         --enable-parser=h264,mjpeg,mpeg4video
         --enable-encoder=h264,libx264,mjpeg,libvpx_vp8,libvpx_vp9
         --enable-protocol=file,rtp,tcp,udp,http,https,httpproxy)
endif()
if(DEBUG)
    set(FFMPEG_DEBUG --enable-debug=3 --disable-optimizations --disable-mmx --disable-stripping)
endif()

if(EXISTS ${ffmpeg_binary_dir}/config.mak)
    message(STATUS  "FFMPEG already configured. Delete ${ffmpeg_binary_dir}/config.mak to force configure")
else()
    message(STATUS "Configuring FFmpeg\n")
    execute_process(
        # Windows requires the "sh" prefix.
        COMMAND sh ${ffmpeg_source_dir}/configure
            ${FFMPEG_CROSS}
            --prefix=${ffmpeg_install_prefix}
            ${FFMPEG_DEBUG}
            --enable-shared
            # Component options (per "configure --help")
            --disable-avdevice --disable-avfilter --disable-doc
            --disable-postproc --disable-swresample --enable-sdl
            --disable-vaapi --disable-vda --disable-vdpau
            --enable-avformat --enable-avcodec --enable-network --enable-swscale
            # Individual component options (per "configure --help")
            --disable-everything
            --enable-ffmpeg --enable-ffplay --enable-ffprobe --enable-ffserver
            --enable-vda --disable-iconv --disable-libopencv --enable-libx264 --enable-libvpx
            --enable-gpl --enable-nonfree
            --enable-encoder=libx264,mjpeg,libvpx_vp8,libvpx_vp9
            ${FFMPEG_FLAGS}
        WORKING_DIRECTORY ${ffmpeg_binary_dir} RESULT_VARIABLE result2)
    if(result1 OR result2)
        message(FATAL_ERROR "Failed to configure FFmpeg")
    endif()

    message(STATUS "Installing FFmpeg pkg-config files")
    execute_process(
        COMMAND make install-headers WORKING_DIRECTORY ${ffmpeg_binary_dir}
        RESULT_VARIABLE result)
    if(result)
        message(FATAL_ERROR "Failed to install FFmpeg pkg-config files")
    endif()
endif()

# Defining a target per library allows them to be built
# concurrently.
include(ExternalProject)
unset(FFMPEG_LIBRARIES)
foreach(library avformat avcodec avutil swscale)
    ExternalProject_add(${library}_external_project
        SOURCE_DIR ${ffmpeg_source_dir} CONFIGURE_COMMAND ""
        BINARY_DIR ${ffmpeg_binary_dir} BUILD_COMMAND ""
        INSTALL_COMMAND make install-lib${library}-shared)
    list(APPEND ffmpeg_external_projects ${library}_external_project)
    list(APPEND FFMPEG_LIBRARIES ${library})
    set_target_properties(${library}_external_project PROPERTIES FOLDER "3rdParty2")
endforeach()

set(FFMPEG_LIBRARIES ${FFMPEG_LIBRARIES} CACHE INTERNAL "")
set(FFMPEG_INCLUDE_DIRS ${FFMPEG_INCLUDE_DIR} CACHE INTERNAL "")
set(FFMPEG_PROJECTS ${ffmpeg_external_projects} CACHE INTERNAL "")

if(WIN32)
    list(APPEND ffmpeg_files avcodec-56.dll avformat-56.dll avutil-54.dll swscale-3.dll)
elseif(APPLE)
    list(APPEND ffmpeg_files libavcodec.56.dylib libavformat.56.dylib
                             libavutil.54.dylib libswscale.3.dylib)
else()
    list(APPEND ffmpeg_files libavcodec.so.56 libavformat.so.56 libavutil.so.54 libswscale.so.3)
endif()
FOREACH(ffmpeg_file ${ffmpeg_files})
    list(APPEND FFMPEG_MODULES "${FFMPEG_LIB_DIR}/${ffmpeg_file}")
ENDFOREACH(ffmpeg_file)
set(FFMPEG_MODULES ${FFMPEG_MODULES} CACHE INTERNAL "")

if(WIN32)
    set(ffmpeg_dest ${EXECUTABLE_OUTPUT_PATH}/${WIN_CONFIG_DIR}/)
else()
    set(ffmpeg_dest ${EXECUTABLE_OUTPUT_PATH}/)
endif()
