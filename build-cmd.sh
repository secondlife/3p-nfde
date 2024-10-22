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

        ;;

        # ------------------------- darwin, darwin64 -------------------------
        darwin*)

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
