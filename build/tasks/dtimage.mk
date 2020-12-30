ifneq ($(filter con_svma64, $(TARGET_DEVICE)),)
ifneq ($(TARGET_NO_DTIMAGE), true)

MKDTIMG := device/nexell/tools/mkdtimg
DTB_DIR := device/nexell/kernel/kernel-4.4.x/arch/arm64/boot/dts/nexell
DTB_REV01 := $(DTB_DIR)/s5p6818-con_svma-rev01.dtb

$(PRODUCT_OUT)/dtb.img: $(DTB_REV01)
	$(MKDTIMG) create $@ \
	$(DTB_REV01) --id=1


droidcore: $(PRODUCT_OUT)/dtb.img


# Images will be packed into target_files zip.
INSTALLED_RADIOIMAGE_TARGET += $(PRODUCT_OUT)/dtb.img

endif
endif
