# CMake utilities to help find the include and library locations for the third party libraries

# General note: The more consist our organization of third party libraries between
# platforms, the less code we have to write in this file to find them.

# Windows note: For native windows projects we were using
# visual studio specific files like thirdPartyPaths-win64-v12.Release.props
# to add the include and library directories in winclientlib.  With
# cmake we use the same approach as other platforms which is to add the paths
# programmatically in the generated vcxproj files, using these macros and other code.
# Because the vcxproj files are generated they can include absolute paths specific
# to the jenkins slave or dev machine.

#Determine ARCH variable for "x86" or "x64"
#Currently only needed on windows, which is only platform that still compiles 32 bit
#
#Also set "VS_VERSION" with the Visual Studio version (e.g. "12")
macro(determine_compiler_and_arch)
    if(MSVC)
        #The libs are organized based on debug/release win32/64 subdirectories that
        #follow a naming convention. In future debug builds should link to the debug library

        #64 or 32 bit is decided by picking different generator, e.g. "Visual Studio 12 2013 Win64
        if (CMAKE_GENERATOR MATCHES ".*Win64")
            message(STATUS "CMAKE_GENERATOR ${CMAKE_GENERATOR}")
            set (ARCH x64)
        else()
            set (ARCH x86)
        endif()

        #Also pull the VS version out, e.g. "12" from "Visual Studio 12 2013 Win64
        string(REGEX REPLACE "Visual Studio ([0-9]+) [0-9]+.*" "\\1" VS_VERSION ${CMAKE_GENERATOR})
 
        message(STATUS "Detected VS is ${VS_VERSION}, architecture: ${ARCH}")
    endif()
endmacro(determine_compiler_and_arch)


#This is replacement for the installprep.vcxproj approach that was finding the dlls at compile time
#and copying them to the output path so that unit tests and other executables find the correct dll.
#The advantage of cmake approach is that it happens at regeneration time and only forces a regenation if the source
#dlls actually change (which is rare)
#At generation time we don't know if we will compile Debug or Release so we copy to both
macro(copy_3rdparty_dll dllname dllsourcedir)
    configure_file(${dllsourcedir}/${dllname} ${CMAKE_BINARY_DIR}/Debug/${dllname} COPYONLY)
    configure_file(${dllsourcedir}/${dllname} ${CMAKE_BINARY_DIR}/Release/${dllname} COPYONLY)
endmacro(copy_3rdparty_dll)

#Set variables pointing to the desired openssl include files and libraries
#version - e.g. 1.0.1e
macro(configure_openssl version)
    set(OPENSSL_USE_STATIC_LIBS ON)

    if(CMAKE_HOST_APPLE OR MSVC)
        #Default FindOpenssl doesn't understand our openssl directory layout in thirdparty-mac / winclientlib
        #To be cleanest we could provide our own Find module override but currently its simple to define the variables
        #to point into our third party location

        set (OPENSSL_ROOT ${THIRDPARTY_LIB_ROOT}/openssl/openssl-${version})

        set (OPENSSL_FOUND ON)
        set (OPENSSL_VERSION ${version})

        if(MSVC)
            #The libs are organized based on debug/release win32/64 subdirectories that
            #follow a naming convention. In future debug builds should link to the debug openssl
            determine_compiler_and_arch()

            set (OPENSSL_CRYPTO_LIBRARY ${OPENSSL_ROOT}/openssl-${version}-vc${VS_VERSION}-${ARCH}-release/libeay32.lib)
            set (OPENSSL_SSL_LIBRARY ${OPENSSL_ROOT}/openssl-${version}-vc${VS_VERSION}-${ARCH}-release/ssleay32.lib)

            copy_3rdparty_dll(libeay32.dll ${OPENSSL_ROOT}/openssl-${version}-vc${VS_VERSION}-${ARCH}-release)
            copy_3rdparty_dll(ssleay32.dll ${OPENSSL_ROOT}/openssl-${version}-vc${VS_VERSION}-${ARCH}-release)
        else()
            set (OPENSSL_CRYPTO_LIBRARY ${OPENSSL_ROOT}/libcrypto-${version}.a)
            set (OPENSSL_SSL_LIBRARY ${OPENSSL_ROOT}/libssl-${version}.a)
        endif()

        set (OPENSSL_LIBRARIES ${OPENSSL_CRYPTO_LIBRARY} ${OPENSSL_SSL_LIBRARY})
 
        set (OPENSSL_INCLUDE_DIR ${OPENSSL_ROOT}/include)
    else()
        #On linux find the installed version - review should be fail if it doesn't match the provided version argh
        find_package(openssl REQUIRED)

        message(STATUS "Openssl expected version ${version}, found version ${OPENSSL_VERSION}")
    endif()

    include_directories (SYSTEM ${OPENSSL_INCLUDE_DIR})
endmacro(configure_openssl)


#version - examples "1.61.0"
#listlist - name of the variable that contains the list of non-header boosts libraries that are needed
#           (I had trouble figuring out how to actually pass a list)
macro(configure_boost version liblist)
    #On linux we don't currently deploy boost via a git repro so it has to be found installed on
    #the system.  For Windows and Mac it is at a well known location

    if(MSVC OR CMAKE_HOST_APPLE)
        #version 1.61.0 is found at boost_1_61_0
        string (REPLACE "." "_" boost_version_underscores ${version})

        set (BOOST_ROOT ${THIRDPARTY_LIB_ROOT}/boost/boost_${boost_version_underscores})
        message(STATUS "Using boost root ${BOOST_ROOT}")

        set (Boost_NO_SYSTEM_PATHS ON)
    endif()

    #If trouble configuring boost then this line is useful
    #set (Boost_DEBUG ON)

    #Various options are available
    set (Boost_USE_MULTITHREADED ON)
    set (Boost_USE_STATIC_LIBS ON)
    set (Boost_USE_STATIC_RUNTIME OFF)

    #The behavior and variables that it sets are documented as FindBoost

    find_package (Boost ${version} REQUIRED COMPONENTS ${${liblist}})

    #The libraries that are not header-only would need to be listed, e.g.
    #and we reference ${Boost_LIBRARIES} in target_link_libraries

    include_directories (SYSTEM ${Boost_INCLUDE_DIR})

endmacro()

function(config_zlib)
   if(MSVC)
      determine_compiler_and_arch()

      set (ZLIB_ROOT ${THIRDPARTY_LIB_ROOT}/zlib)
 
      set (ZLIB_INCLUDE_DIRS ${THIRDPARTY_LIB_ROOT}/zlib/include)

      set (ZLIB_LIBRARIES ${THIRDPARTY_LIB_ROOT}/zlib/zlib-vc${VS_VERSION}-${ARCH}-release/zdll.lib PARENT_SCOPE)

      copy_3rdparty_dll(zlib1.dll ${THIRDPARTY_LIB_ROOT}/zlib/zlib-vc${VS_VERSION}-${ARCH}-release)
   else() 
       find_package (ZLIB)
   endif() 

   include_directories (SYSTEM ${ZLIB_INCLUDE_DIRS})

endfunction()

#On windows find path like
#$(winclientlib)\protobuf\protobuf-3.0\include
#$(winclientlib)\protobuf\protobuf-3.0\vc12-x64\lib
function(configure_protobuf)
    find_package (Protobuf REQUIRED) 
endfunction()

#$(winclientlib)\lzma\include;

function(config_lzma) 
    if (MSVC)
        #Currently windows only includes lzma headers but doesn't actually link 
        set (LZMA_INCLUDE_DIRS ${THIRDPARTY_LIB_ROOT}/lzma/include)
        include_directories (SYSTEM ${LZMA_INCLUDE_DIRS})
    endif()
endfunction()

function(config_ragel)
    if(MSVC)
        set(RAGEL_BIN ${THIRDPARTY_LIB_ROOT}/tools/ragel.exe PARENT_SCOPE)
    else()
        #On these platforms we require that ragel is installed or in the path
        set(RAGEL_BIN ragel PARENT_SCOPE)
    endif()
endfunction()
