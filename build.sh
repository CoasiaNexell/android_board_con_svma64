#!/bin/bash

set -e

TOP=`pwd`
export TOP

source ${TOP}/device/nexell/con_svma64/common.sh
source ${TOP}/device/nexell/tools/dir.sh
source ${TOP}/device/nexell/tools/make_build_info.sh
source ${TOP}/device/nexell/tools/revert_patches.sh

parse_args -s s5p6818 $@
print_args
setup_toolchain
export_work_dir

DTIMGE_TOOL=${TOP}/device/nexell/tools/mkdtimg
DEVICE_DIR=${TOP}/device/nexell/${BOARD_NAME}
OUT_DIR=${TOP}/out/target/product/${BOARD_NAME}


if [ "${QUICKBOOT}" == "true" ] ; then
	PARTMAP_FILE=${TOP}/device/nexell/con_svma64/partmap_quick.txt
	KERNEL_DEFCONFIG=s5p6818_con_svma_nougat_quickboot_defconfig
else
    PARTMAP_FILE=${TOP}/device/nexell/con_svma64/partmap.txt
	KERNEL_DEFCONFIG=s5p6818_con_svma_nougat_defconfig
fi

DEVID_USB=0
DEVID_SPI=1
DEVID_NAND=2
DEVID_SDMMC=3
DEVID_SDFS=4
DEVID_UART=5
PORT_EMMC=0
PORT_SD=2
DEVIDS=("usb" "spi" "nand" "sdmmc" "sdfs" "uart")
PORTS=("emmc" "sd")

RSA_SIGN_TOOL=${DEVICE_DIR}/tools/rsa_sign_pss
SECURE_TOOL=${TOP}/device/nexell/tools/SECURE_BINGEN

BL1_SOURCE=${TOP}/device/nexell/bl1/bl1-s5p6818
OPTEE_BUILD=${TOP}/device/nexell/secure/optee_build

FIP_SEC_SIZE=
FIP_NONSEC_SIZE=

if [ "${RSA_KEY}" == "none" ]; then
    RSA_KEY=${DEVICE_DIR}/private_key.pem
fi

CROSS_COMPILE="aarch64-linux-android-"
CROSS_COMPILE32="arm-linux-gnueabihf-"

OPTEE_BUILD_OPT="PLAT_DRAM_SIZE=2048 PLAT_UART_BASE=0xc00a3000 SECURE_ON=0 SUPPORT_ANDROID=1"
OPTEE_BUILD_OPT+=" CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE32=${CROSS_COMPILE32}"
OPTEE_BUILD_OPT+=" UBOOT_DIR=${UBOOT_DIR}"
if [ "${QUICKBOOT}" == "true" ]; then
OPTEE_BUILD_OPT+=" QUICKBOOT=1"
fi

KERNEL_IMG=${KERNEL_DIR}/arch/arm64/boot/Image
DTB_IMG=${KERNEL_DIR}/arch/arm64/boot/dts/nexell/s5p6818-con_svma-rev01.dtb


if [ "${BUILD_ALL}" == "true" ] || [ "${BUILD_BL1}" == "true" ]; then
    build_bl1 ${BL1_DIR}/bl1-${TARGET_SOC} con_svma 2 emmc
    build_bl1 ${BL1_DIR}/bl1-${TARGET_SOC} con_svma 0 sd no
fi

if [ "${BUILD_ALL}" == "true" ] || [ "${BUILD_UBOOT}" == "true" ]; then
    build_uboot ${UBOOT_DIR} ${TARGET_SOC} con_svma ${CROSS_COMPILE}

    if [ "${BUILD_UBOOT}" == "true" ]; then
        build_optee ${OPTEE_DIR} "${OPTEE_BUILD_OPT}" build-fip-nonsecure
        build_optee ${OPTEE_DIR} "${OPTEE_BUILD_OPT}" build-singleimage
        if [ "${ENABLE_ENC}" == "false" ]; then
            # generate fip-nonsecure.img
            gen_third ${TARGET_SOC} ${OPTEE_DIR}/optee_build/result/fip-nonsecure.bin \
                0xbdf00000 0x00000000 ${OPTEE_DIR}/optee_build/result/fip-nonsecure.img
        fi
    fi
fi

if [ "${BUILD_ALL}" == "true" ] || [ "${BUILD_SECURE}" == "true" ]; then
    build_optee ${OPTEE_DIR} "${OPTEE_BUILD_OPT}" all

    # generate fip-loader-emmc.img
    # -m argument decided by partmap.txt
    #    first: fip-secure.img offset
    #    second: fip-nonsecure.img offset
    gen_third ${TARGET_SOC} \
        ${OPTEE_DIR}/optee_build/result/fip-loader.bin \
        0xbfcc0000 0xbfd00800 ${OPTEE_DIR}/optee_build/result/fip-loader-emmc.img \
        "-k 3 -m 0x60200 -b 3 -p 2 -m 0x1E0200 -b 3 -p 2"
    # generate fip-loader-sd.img
    gen_third ${TARGET_SOC} \
        ${OPTEE_DIR}/optee_build/result/fip-loader.bin \
        0xbfcc0000 0xbfd00800 ${OPTEE_DIR}/optee_build/result/fip-loader-sd.img \
        "-k 3 -m 0x60200 -b 3 -p 0 -m 0x1E0200 -b 3 -p 0"
    # generate fip-secure.img
    gen_third ${TARGET_SOC} ${OPTEE_DIR}/optee_build/result/fip-secure.bin \
        0xbfb00000 0x00000000 ${OPTEE_DIR}/optee_build/result/fip-secure.img
    # generate fip-nonsecure.img
    gen_third ${TARGET_SOC} ${OPTEE_DIR}/optee_build/result/fip-nonsecure.bin \
        0xbdf00000 0x00000000 ${OPTEE_DIR}/optee_build/result/fip-nonsecure.img
    # generate fip-loader-usb.img
    # first -z size : size of fip-secure.img
    # second -z size : size of fip-nonsecure.img
    fip_sec_size=$(stat --printf="%s" ${OPTEE_DIR}/optee_build/result/fip-secure.img)
    fip_nonsec_size=$(stat --printf="%s" ${OPTEE_DIR}/optee_build/result/fip-nonsecure.img)
    gen_third ${TARGET_SOC} \
        ${OPTEE_DIR}/optee_build/result/fip-loader.bin \
        0xbfcc0000 0xbfd00800 ${OPTEE_DIR}/optee_build/result/fip-loader-usb.img \
        "-k 0 -u -m 0xbfb00000 -z ${fip_sec_size} -m 0xbdf00000 -z ${fip_nonsec_size}"
    cat ${OPTEE_DIR}/optee_build/result/fip-secure.img >> ${OPTEE_DIR}/optee_build/result/fip-loader-usb.img
    cat ${OPTEE_DIR}/optee_build/result/fip-nonsecure.img >> ${OPTEE_DIR}/optee_build/result/fip-loader-usb.img
fi
if [ "${BUILD_ALL}" == "true" ] || [ "${BUILD_KERNEL}" == "true" ]; then
    build_kernel ${KERNEL_DIR} ${TARGET_SOC} ${BOARD_NAME} ${KERNEL_DEFCONFIG} ${CROSS_COMPILE}
    test -d ${OUT_DIR} && \
        cp ${KERNEL_IMG} ${OUT_DIR}/kernel && \
        cp ${DTB_IMG} ${OUT_DIR}/2ndbootloader
fi

if [ "${BUILD_KERNEL}" == "true" ]; then
    ${DTIMGE_TOOL} create ${OUT_DIR}/dtb.img \
     ${TOP}/device/nexell/kernel/kernel-4.4.x/arch/arm64/boot/dts/nexell/s5p6818-con_svma-rev01.dtb --id=1
fi

if [ "${BUILD_ALL}" == "true" ] || [ "${BUILD_MODULE}" == "true" ]; then
    build_module ${KERNEL_DIR} ${TARGET_SOC} ${CROSS_COMPILE}
fi


if [ "${BUILD_ALL}" == "true" ] || [ "${BUILD_ANDROID}" == "true" ]; then
    rm -rf ${OUT_DIR}/system
    rm -rf ${OUT_DIR}/root
    rm -rf ${OUT_DIR}/data
    generate_key ${BOARD_NAME}
    build_android ${TARGET_SOC} ${BOARD_NAME} ${BUILD_TAG}
fi
# u-boot envs
echo "make u-boot env"
if [ -f ${UBOOT_DIR}/u-boot.bin ]; then
	if [  "${QUICKBOOT}" == "true" ]; then
        UBOOT_BOOTCMD=$(make_uboot_bootcmd_svm \
            ${PARTMAP_FILE} \
            0x4007f800 \
            2048 \
            ${KERNEL_IMG} \
            "boot:emmc")
	else
    	UBOOT_BOOTCMD=$(make_uboot_bootcmd_dtimg \
        	${PARTMAP_FILE} \
	        0x4007f800 \
    	    2048 \
        	${KERNEL_IMG} \
			0x49000000 \
	        ${OUT_DIR}/ramdisk.img \
    	    "boot:emmc")
	fi

    UBOOT_RECOVERYCMD="ext4load mmc 0:7 0x49000000 recovery.dtb; ext4load mmc 0:7 0x40080000 recovery.kernel; ext4load mmc 0:7 0x48000000 ramdisk-recovery.img; booti 40080000 0x48000000:2d0f8f 0x49000000"
	if [  "${QUICKBOOT}" == "true" ]; then
    	UBOOT_BOOTARGS='console=ttySAC0,115200n8 loglevel=4 quiet printk.time=1 '
    	UBOOT_BOOTARGS+='root=\/dev\/mmcblk0p2 rw rootfstype=ext4 rootwait '
    	UBOOT_BOOTARGS+='init=\/sbin\/nx_init '
		UBOOT_BOOTARGS+='androidboot.hardware=con_svma64 '
		UBOOT_BOOTARGS+='androidboot.console=ttySAC0 '
		UBOOT_BOOTARGS+='androidboot.serialno=0123456789abcdef '
		UBOOT_BOOTARGS+='androidboot.selinux=permissive'
	else
	    UBOOT_BOOTARGS='console=ttySAC0,115200n8 loglevel=7 printk.time=1 '
		UBOOT_BOOTARGS+='androidboot.hardware=con_svma64 '
		UBOOT_BOOTARGS+='androidboot.console=ttySAC0 '
		UBOOT_BOOTARGS+='androidboot.serialno=0123456789abcdef '
		UBOOT_BOOTARGS+='androidboot.selinux=permissive'
	fi

	RECOVERY_BOOTARGS='console=ttySAC0,115200n8 loglevel=7 printk.time=1 '
	RECOVERY_BOOTARGS+='androidboot.hardware=con_svma64 '
	RECOVERY_BOOTARGS+='androidboot.console=ttySAC0 '
	RECOVERY_BOOTARGS+='androidboot.serialno=0123456789abcdef '
	RECOVERY_BOOTARGS+='androidboot.selinux=permissive '

    SPLASH_SOURCE="mmc"
    SPLASH_OFFSET="0x2e4200"

    AUTORECOVERY_CMD="nxrecovery mmc 1 mmc 0"

	NXQUICKREAR_ARGS_0='nx_cam.m=-m2 nx_cam.b=-b1 nx_cam.c=-c26 nx_cam.r=-r704x480 nx_cam.end'
	NXQUICKREAR_ARGS_1='nx_cam.m=-m9 nx_cam.b=-b1 nx_cam.c=-c26 nx_cam.r=-r1280x720 nx_cam.end'

    echo "UBOOT_BOOTCMD ==> ${UBOOT_BOOTCMD}"
    echo "UBOOT_BOOTARGS ==> ${UBOOT_BOOTARGS}"
    echo "UBOOT_RECOVERYCMD ==> ${UBOOT_RECOVERYCMD}"
    echo "RECOVERY_BOOTARGS ==> ${RECOVERY_BOOTARGS}"

    pushd `pwd`
    cd ${UBOOT_DIR}
	build_uboot_env_param ${CROSS_COMPILE} "${UBOOT_BOOTCMD}" "${UBOOT_BOOTARGS}" "${RECOVERY_BOOTARGS}" "${SPLASH_SOURCE}" "${SPLASH_OFFSET}" "${UBOOT_RECOVERYCMD}" "${AUTORECOVERY_CMD}" "${NXQUICKREAR_ARGS_0}" "${NXQUICKREAR_ARGS_1}"
    # for sd card auto recovery
    build_uboot_env_param ${CROSS_COMPILE} "${UBOOT_BOOTCMD}" "${UBOOT_BOOTARGS}" "${RECOVERY_BOOTARGS}" "${SPLASH_SOURCE}" "${SPLASH_OFFSET}" "${UBOOT_RECOVERYCMD}" "${AUTORECOVERY_CMD}" "${NXQUICKREAR_ARGS_0}" "${NXQUICKREAR_ARGS_1}" "params_sd.bin"
    popd
fi

# make bootloader
bl1=""
loader=""
secure=""
nonsecure=""
echo "make bootloader for emmc"
# TODO: get seek offset from configuration file

bl1=${BL1_DIR}/bl1-${TARGET_SOC}/out/bl1-emmcboot.bin
loader=${OPTEE_DIR}/optee_build/result/fip-loader-emmc.img
secure=${OPTEE_DIR}/optee_build/result/fip-secure.img
nonsecure=${OPTEE_DIR}/optee_build/result/fip-nonsecure.img

param=${UBOOT_DIR}/params.bin
boot_logo=${DEVICE_DIR}/logo.bmp
out_file=${DEVICE_DIR}/bootloader

if [ -f ${bl1} ] && [ -f ${loader} ] && [ -f ${secure} ] && [ -f ${nonsecure} ] && [ -f ${param} ] && [ -f ${boot_logo} ]; then
    BOOTLOADER_PARTITION_SIZE=$(get_partition_size ${DEVICE_DIR}/partmap.txt bootloader)
    make_bootloader \
        ${BOOTLOADER_PARTITION_SIZE} \
        ${bl1} \
        65536 \
        ${loader} \
        393216 \
        ${secure} \
        1966080 \
        ${nonsecure} \
        3014656 \
        ${param} \
        3031040 \
        ${boot_logo} \
        ${out_file}

    test -d ${OUT_DIR} && cp ${DEVICE_DIR}/bootloader ${OUT_DIR}
fi
echo "make bootloader for sd"

bl1=${BL1_DIR}/bl1-${TARGET_SOC}/out/bl1-sdboot.bin
loader=${OPTEE_DIR}/optee_build/result/fip-loader-sd.img
param=${UBOOT_DIR}/params_sd.bin
out_file=${DEVICE_DIR}/bootloader-sd

if [ -f ${bl1} ] && [ -f ${loader} ] && [ -f ${secure} ] && [ -f ${nonsecure} ] && [ -f ${param} ] && [ -f ${boot_logo} ]; then
    BOOTLOADER_PARTITION_SIZE=$(get_partition_size ${DEVICE_DIR}/partmap.txt bootloader)
    make_bootloader \
        ${BOOTLOADER_PARTITION_SIZE} \
        ${bl1} \
        65536 \
        ${loader} \
        393216 \
        ${secure} \
        1966080 \
        ${nonsecure} \
        3014656 \
        ${param} \
        3031040 \
        ${boot_logo} \
        ${out_file}

    test -d ${OUT_DIR} && cp ${DEVICE_DIR}/bootloader-sd ${OUT_DIR}
fi

if [ "${BUILD_DIST}" == "true" ]; then
    build_dist ${TARGET_SOC} ${BOARD_NAME} ${BUILD_TAG}
fi

if [ "${BUILD_KERNEL}" == "true" ]; then
    test -f ${OUT_DIR}/ramdisk.img && \
        make_android_bootimg \
            ${KERNEL_IMG} \
            ${OUT_DIR}/ramdisk.img \
            ${OUT_DIR}/boot.img \
            2048 \
            "buildvariant=${BUILD_TAG}"
fi
post_process ${TARGET_SOC} \
	${PARTMAP_FILE} \
	${RESULT_DIR} \
    ${BL1_DIR}/bl1-${TARGET_SOC}/out \
    ${OPTEE_DIR}/optee_build/result \
    ${UBOOT_DIR} \
    ${KERNEL_DIR}/arch/arm64/boot \
    ${KERNEL_DIR}/arch/arm64/boot/dts/nexell \
    ${OUT_DIR} \
    con_svma

make_ext4_recovery_image \
    ${KERNEL_IMG} \
    ${DTB_IMG} \
    ${OUT_DIR}/ramdisk-recovery.img \
    67108864 \
    ${RESULT_DIR}


cp -f ${OUT_DIR}/dtb.img ${RESULT_DIR}
if [ -f "${KERNEL_IMG}" ];then
cp -af ${KERNEL_IMG} ${RESULT_DIR}
fi

make_build_info ${RESULT_DIR}

