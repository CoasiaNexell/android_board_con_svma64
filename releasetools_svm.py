# Copyright (C) 2009 The Android Open Source Project
# Copyright (c) 2011-2013, The Linux Foundation. All rights reserved.
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

"""Emit commands needed for NEXELL devices during OTA installation
(installing bootloader image)."""

import common

def WriteBootloader(info, img, btype):
    print "WriteBootloader ..."
    common.ZipWriteStr(info.output_zip, "bootloader", img)
    info.script.Print("Writing bootloader ...")
    info.script.AppendExtra('nexell.write_bootloader(package_extract_file("bootloader"), "%s");' % btype)
    info.script.Print("End of Writing bootloader")

def WriteKernel(info, img, offset):
    print "WriteKernel ..."
    common.ZipWriteStr(info.output_zip, "kernel", img)
    info.script.Print("Writing kernel ...")
    info.script.AppendExtra('nexell.write_kernel(package_extract_file("kernel"), "%s");' % offset)
    info.script.Print("End of Writing kernel")

def WriteDTB(info, img, offset):
    print "WriteDTB ..."
    common.ZipWriteStr(info.output_zip, "dtb.img", img)
    info.script.Print("Writing dtb ...")
    info.script.AppendExtra('nexell.write_dtb(package_extract_file("dtb.img"), "%s");' % offset)
    info.script.Print("End of Writing dtb")

def WriteRoot(info, img, offset):
    print "WriteRoot ..."
    common.ZipWriteStr(info.output_zip, "root.img", img)
    info.script.Print("Writing root.img ...")
    info.script.AppendExtra('nexell.write_root(package_extract_file("root.img"), "%s");' % offset)
    info.script.Print("End of Writing root")

def OTA_InstallEnd(info):
    print "Applying image-update script modifications..."

    bootloader_img = None
    try:
        bootloader_img = info.input_zip.read("IMAGES/bootloader")
    except AttributeError:
        bootloader_img = info.target_zip.read("IMAGES/bootloader")
    except KeyError:
        print "no bootloader in target_files, skipping install"

    if bootloader_img is not None:
        WriteBootloader(info, bootloader_img, "mmc")

	kernel_img = None
    try:
        kernel_img = info.input_zip.read("IMAGES/kernel")
    except AttributeError:
        kernel_img = info.target_zip.read("IMAGES/kernel")
    except KeyError:
        print "no kernel in target_files, skipping install"

    if kernel_img is not None:
        WriteKernel(info, kernel_img, "0xA00000")

	dtb_img = None
    try:
        dtb_img = info.input_zip.read("RADIO/dtb.img")
    except AttributeError:
        dtb_img = info.target_zip.read("RADIO/dtb.img")
    except KeyError:
        print "no bootloader in target_files, skipping install"

    if dtb_img is not None:
        WriteDTB(info, dtb_img, "0x2A00000")

	root_img = None
    try:
        root_img = info.input_zip.read("IMAGES/root.img")
    except AttributeError:
        root_img = info.target_zip.read("IMAGES/root.img")
    except KeyError:
        print "no bootloader in target_files, skipping install"

    if root_img is not None:
        WriteRoot(info, root_img, "2")

    return

def FullOTA_InstallEnd(info):
    OTA_InstallEnd(info)
    return

def IncrementalOTA_InstallEnd(info):
    OTA_InstallEnd(info)
    return
