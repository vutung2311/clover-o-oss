#!/bin/bash

export PRODUCTION_BUILD=yes
export TARGET_BUILD_VARIANT=user
export KBUILD_BUILD_USER=BuildUser
export KBUILD_BUILD_HOST=BuildHost

ARM64_GCC_BIN_PATH=$HOME/Toolchain/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu/bin
ARM32_GCC_BIN_PATH=$HOME/Toolchain/gcc-arm-9.2-2019.12-x86_64-arm-none-linux-gnueabihf/bin
CLANG_BIN_PATH=/usr/lib/llvm-10/bin
LD_BIN_PATH=/usr/lib/llvm-10/bin

BUILD_CROSS_COMPILE_ARM64=$ARM64_GCC_BIN_PATH/aarch64-none-linux-gnu-
BUILD_CROSS_COMPILE_ARM32=$ARM32_GCC_BIN_PATH/arm-none-linux-gnueabihf-
BUILD_CC=$CLANG_BIN_PATH/clang
# BUILD_CC="${BUILD_CROSS_COMPILE_ARM64}gcc"
BUILD_LD=$LD_BIN_PATH/ld.lld
BUILD_JOB_NUMBER="$(nproc)"
# BUILD_JOB_NUMBER=1

OUTPUT_ZIP="mipad4_kernel"
RDIR="$(pwd)"
ARCH=arm64
KERNEL_DEFCONFIG=clover-perf_defconfig

FUNC_CLEAN_DTB()
{
    if ! [ -d ${RDIR}/arch/${ARCH}/boot/dts ] ; then
        echo "no directory : "${RDIR}/arch/${ARCH}/boot/dts""
    else
        echo "rm files in : "${RDIR}/arch/${ARCH}/boot/dts/*.dtb""
        rm ${RDIR}/arch/${ARCH}/boot/dts/qcom/*.dtb
    fi
}

FUNC_BUILD_KERNEL()
{
    echo ""
    echo "=============================================="
    echo "START : FUNC_BUILD_KERNEL"
    echo "=============================================="
    echo ""
    echo "build common config="$KERNEL_DEFCONFIG ""

    FUNC_CLEAN_DTB

    make -j$BUILD_JOB_NUMBER ARCH=${ARCH} \
            CC=$BUILD_CC \
            LD=$BUILD_LD \
            CROSS_COMPILE="$BUILD_CROSS_COMPILE_ARM64" \
            CROSS_COMPILE_ARM32="$BUILD_CROSS_COMPILE_ARM32" \
            $KERNEL_DEFCONFIG || exit -1

    echo ""
    for var in "$@"
    do
        if [[ "$var" = "--with-lto" ]] ; then
            echo "Enable CLANG_LTO"
            ./scripts/config \
            -e CLANG_LTO
            continue
        fi
        if [[ "$var" = "--with-supersu" ]] ; then
            echo "Enable ASSISTED_SUPERUSER"
            ./scripts/config \
            -e ASSISTED_SUPERUSER
            continue
        fi
    done
    echo ""

    make -j$BUILD_JOB_NUMBER ARCH=${ARCH} \
            CC=$BUILD_CC \
            LD=$BUILD_LD \
            CROSS_COMPILE_ARM32="$BUILD_CROSS_COMPILE_ARM32" \
            CROSS_COMPILE="$BUILD_CROSS_COMPILE_ARM64" || exit -1

    echo ""
    echo "================================="
    echo "END   : FUNC_BUILD_KERNEL"
    echo "================================="
    echo ""
}

FUNC_BUILD_RAMDISK()
{
    find ${RDIR}/out -name "*.ko" -exec rm {} \;
    cp ${RDIR}/arch/${ARCH}/boot/Image.gz-dtb ${RDIR}/aik/split_img/boot.img-zImage
    find ${RDIR} -name "*.ko" -not -path "*/out/*" -not -name "wlan.ko" -exec cp -f {} ${RDIR}/out/system/lib/modules/ \;
    find ${RDIR} -name "wlan.ko" -not -path "*/out/*" -exec cp -f {} ${RDIR}/out/vendor/lib/modules/qca_cld3/qca_cld3_wlan.ko \;
    cd ${RDIR}/aik
    ./fixperm.sh
    ./repackimg.sh
}

FUNC_BUILD_ZIP()
{
    rm -f ${RDIR}/${OUTPUT_ZIP}.zip
    cp ${RDIR}/aik/image-new.img ${RDIR}/out/boot.img
    cd ${RDIR}/out/ && zip ../${OUTPUT_ZIP}.zip -r *
}

# MAIN FUNCTION
rm -rf ./build.log
(
    START_TIME=`date +%s`

    FUNC_BUILD_KERNEL "$@"
    FUNC_BUILD_RAMDISK
    FUNC_BUILD_ZIP

    END_TIME=`date +%s`

    let "ELAPSED_TIME=${END_TIME}-${START_TIME}"
    echo "Total compile time was ${ELAPSED_TIME} seconds"

) 2>&1	 | tee -a ./build.log
