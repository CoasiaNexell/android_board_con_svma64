#
# Copyright (C) 2015 The Android Open-Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Inherit the full_base and device configurations
ifeq ($(QUICKBOOT), 1)
$(call inherit-product, device/nexell/quickboot/component.mk)
else
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base.mk)
endif

PRODUCT_NAME := aosp_con_svma64
PRODUCT_DEVICE := con_svma64
PRODUCT_BRAND := Android
PRODUCT_MODEL := AOSP on con_svma64
PRODUCT_MANUFACTURER := NEXELL

PRODUCT_COPY_FILES += \
	device/nexell/kernel/kernel-4.4.x/arch/arm64/boot/Image:kernel

PRODUCT_COPY_FILES += \
	device/nexell/kernel/kernel-4.4.x/arch/arm64/boot/dts/nexell/s5p6818-con_svma-rev01.dtb:2ndbootloader

PRODUCT_PROPERTY_OVERRIDES += \
	ro.product.first_api_level=21

# vold check fs
PRODUCT_PROPERTY_OVERRIDES += \
	persist.vold.check_fs=0

PRODUCT_DEFAULT_PROPERTY_OVERRIDES += config.disable_bluetooth=false
ifeq ($(QUICKBOOT), 1)
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += config.quickboot=true
endif

$(call inherit-product, device/nexell/con_svma64/device.mk)

ifeq ($(QUICKBOOT), 1)
PRODUCT_PACKAGES += \
    Home \
    Settings
else
PRODUCT_PACKAGES += \
	Launcher3
endif
