#!/usr/bin/env python
# -*- coding: UTF-8 -*-
# Copyright 2015, The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from __future__ import print_function
from sys import exit
from argparse import ArgumentParser, FileType
from os import rename, makedirs
from os.path import basename, exists
from struct import unpack, calcsize
import os, json, binascii, shutil
from mkimage  import mkimage_header, PART_MAGIC


def ROUNDDOWN(number, alignment):
    return ((number) & ~((alignment)-1))


class Bunch:
    """
    Turns a dictionary into a class
    and Save to Jsons
    """
    def __init__(self, d):
        for key in d:
            if key in ('cmdline', 'extra_cmdline', 'product_name'):
                setattr(self, key, (d[key][0]).partition(b'\0')[0].decode())
                continue
            if key not in ('args', 'a', 'c', 'b', 'm', 'y'):
                setattr(self, key, d[key])

        self.header_version = self.version
        self.pagesize = self.page_size

        # find common base of all loading addresses
        kernel_offset = self.kernel_ramdisk_second_info[1]
        base = 0xffffffff
        if kernel_offset > 0:
            base = kernel_offset
        ramdisk_offset = self.kernel_ramdisk_second_info[3]
        if ramdisk_offset > 0:
            base = min(base, ramdisk_offset)
        second_offset = self.kernel_ramdisk_second_info[5]
        if second_offset > 0:
            base = min(base, second_offset)
        tags_offset = self.kernel_ramdisk_second_info[6]
        if tags_offset > 0:
            base = min(base, tags_offset)
        if self.version > 1:
            base = min(base, self.dtb_load_address)
        base = ROUNDDOWN(base, self.page_size)
        if (base&0xffff) == 0x8000:
            base -= 0x8000
        self.base = base
        self.kernel_offset = kernel_offset - base
        self.ramdisk_offset = ramdisk_offset - base if ramdisk_offset > 0 else 0
        self.second_offset = second_offset - base if second_offset > 0 else 0
        self.tags_offset = tags_offset - base if  tags_offset > 0 else 0
        if self.version > 1:
            base = min(base, self.dtb_load_address)
            self.dtb_offset = self.dtb_load_address - base

        os_version = self.kernel_ramdisk_second_info[9]>>11
        os_patch_level = self.kernel_ramdisk_second_info[9]&0x7ff

        if os_version != 0:
            a = (os_version>>14)&0x7f
            b = (os_version>>7)&0x7f
            c = os_version&0x7f
            self.os_version = '%d.%d.%d' % (a,b,c)

        if os_patch_level != 0:
            y = (os_patch_level>>4) + 2000
            m = os_patch_level&0xf
            self.os_patch_level = '%04d-%02d-%02d' % (y,m,0)

        self.path = os.path.join(os.getcwd(), 'bootimg.json')

    def __repr__(self):
        """"""
        attrs = str([x for x in self.__dict__])
        return "<Bunch: %s>" % attrs

    def Get(self, path):
        self.path = path
        self._Load()
        return self.__dict__

    def _Load(self):
        if self.path is not None:
            try:
                f = open(self.path)
                try:
                    self.__dict__ = json.load(f)
                finally:
                    f.close()
            except (IOError, ValueError):
                try:
                    os.remove(self.path)
                except OSError:
                    pass
                self.__dict__= {}

    def Save(self, path=None):
        if path is not None:
            self.path = path
        try:
            f = open(self.path, 'w')
            try:
                _data = {}
                for k, v in self.__dict__.items():
                    if k == 'id':
                        _data[k] = binascii.hexlify(v)
                    elif k != 'path':
                        _data[k] = v
                json.dump(_data, f, indent=2, skipkeys=True)
            finally:
                f.close()
        except (IOError, TypeError):
            try:
                os.remove(self.path)
            except OSError:
                pass
