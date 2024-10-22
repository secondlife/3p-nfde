#!/usr/bin/env bash

cd "$(dirname "$0")"

set -eux

NFD_SOURCE_DIR="nativefiledialog"

top="$(pwd)"
stage="$top"/stage

# load autobuild provided shell functions and variables
case "$AUTOBUILD_PLATFORM" in
    windows*)
        autobuild="$(cygpath -u "$AUTOBUILD")"
    ;;
    *)
        autobuild="$AUTOBUILD"
    ;;
esac
source_environment_tempfile="$stage/source_environment.sh"
"$autobuild" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

# remove_cxxstd
source "$(dirname "$AUTOBUILD_VARIABLES_FILE")/functions"

pushd "$NFD_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        # ------------------------ windows, windows64 ------------------------
        windows*)
        load_vsvars

        opts="$(replace_switch /Zi /Z7 $LL_BUILD_RELEASE)"
        plainopts="$(remove_switch /GR $(remove_cxxstd $opts))"

        mkdir -p "build"
        pushd "build"
            cmake -G "Ninja Multi-Config" .. -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_C_FLAGS="$plainopts" \
            -DCMAKE_CXX_FLAGS="$opts" \
            -DCMAKE_INSTALL_PREFIX="$(cygpath -m $stage)" \
            -DCMAKE_INSTALL_LIBDIR="$(cygpath -m "$stage/lib/release")" \
            -DCMAKE_INSTALL_INCLUDEDIR="$(cygpath -m "$stage/include/nfde")"

            cmake --build . --config Release
            cmake --install . --config Release

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                ctest -C Release
            fi
        popd

        ;;

        # ------------------------- darwin, darwin64 -------------------------
        darwin*)
            export MACOSX_DEPLOYMENT_TARGET="$LL_BUILD_DARWIN_DEPLOY_TARGET"

            for arch in x86_64 arm64 ; do
                ARCH_ARGS="-arch $arch"
                cc_opts="${TARGET_OPTS:-$ARCH_ARGS $LL_BUILD_RELEASE}"
                cc_opts="$(remove_cxxstd $cc_opts)"

                mkdir -p "build_$arch"
                pushd "build_$arch"
                    cmake .. -G "Ninja Multi-Config" -DBUILD_SHARED_LIBS:BOOL=OFF \
                        -DCMAKE_BUILD_TYPE="Release" \
                        -DCMAKE_C_FLAGS="$cc_opts" \
                        -DCMAKE_CXX_FLAGS="$cc_opts" \
                        -DCMAKE_INSTALL_PREFIX="$stage" \
                        -DCMAKE_INSTALL_LIBDIR="$stage/lib/release/$arch" \
                        -DCMAKE_INSTALL_INCLUDEDIR="$stage/include/nfde" \
                        -DCMAKE_OSX_ARCHITECTURES="$arch" \
                        -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET}

                    cmake --build . --config Release
                    cmake --install . --config Release

                    # conditionally run unit tests
                    if [ "${DISABLE_UNIT_TESTS:-0}" = "0" -a "$arch" = "$(uname -m)" ]; then
                        ctest -C Release
                    fi
                popd
            done

            lipo -create -output "$stage/lib/release/libnfd.a" "$stage/lib/release/x86_64/libnfd.a" "$stage/lib/release/arm64/libnfd.a" 
        ;;            

        # -------------------------- linux, linux64 --------------------------
        linux*)
            # Default target per autobuild build --address-size
            opts="${TARGET_OPTS:--m$AUTOBUILD_ADDRSIZE $LL_BUILD_RELEASE}"

            # Release
            mkdir -p "build_gtk"
            pushd "build_gtk"
                cmake .. -GNinja -DBUILD_SHARED_LIBS:BOOL=OFF -DNFD_PORTAL=OFF \
                    -DCMAKE_BUILD_TYPE="Release" \
                    -DCMAKE_C_FLAGS="$(remove_cxxstd $opts)" \
                    -DCMAKE_CXX_FLAGS="$opts" \
                    -DCMAKE_INSTALL_PREFIX="$stage" \
                    -DCMAKE_INSTALL_LIBDIR="$stage/lib/release" \
                    -DCMAKE_INSTALL_INCLUDEDIR="$stage/include/nfde"

                cmake --build . --config Release
                cmake --install . --config Release

                # conditionally run unit tests
                if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    ctest -C Release
                fi
            popd

            mv "$stage/lib/release/libnfd.a" "$stage/lib/release/libnfd_gtk.a"

            mkdir -p "build_portal"
            pushd "build_portal"
                cmake .. -GNinja -DBUILD_SHARED_LIBS:BOOL=OFF -DNFD_PORTAL=ON \
                    -DCMAKE_BUILD_TYPE="Release" \
                    -DCMAKE_C_FLAGS="$(remove_cxxstd $opts)" \
                    -DCMAKE_CXX_FLAGS="$opts" \
                    -DCMAKE_INSTALL_PREFIX="$stage" \
                    -DCMAKE_INSTALL_LIBDIR="$stage/lib/release"

                cmake --build . --config Release

                # conditionally run unit tests
                if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    ctest -C Release
                fi
                mv "src/libnfd.a" "$stage/lib/release/libnfd_portal.a"
            popd


        ;;
    esac

    mkdir -p "$stage/LICENSES"
    cp LICENSE "$stage/LICENSES/nfde.txt"
popd
