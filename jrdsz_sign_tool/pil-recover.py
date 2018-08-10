#! /usr/bin/env python
"""
===========================================================================

  Copyright (c) 2012 QUALCOMM Incorporated.  All Rights Reserved.
  QUALCOMM Proprietary and Confidential.

===========================================================================
"""

"""
Splits elf files into segments.

If the elf is signed, the elf headers and the hash segment are output to
the *.mdt file, and then the segments are output to *.b<n> files.

If the elf isn't signed each segment is output to a *.b<n> file and the
elf headers are output to the *.mdt file.
"""

import sys
import struct

def usage():
	print "Usage: %s <elf> <prefix>" % sys.argv[0]
	exit(1)

def is_elf(file):
	"""Verifies a file as being an ELF file"""
	file.seek(0)
	magic = file.read(4)
	image.seek(0)
	return magic == '\x7fELF'

def gen_struct(format, image):
	"""Generates a dictionary from the format tuple by reading image"""

	str = "<%s" % "".join([x[1] for x in format])
	elems = struct.unpack(str, image.read(struct.calcsize(str)))
	keys = [x[0] for x in format]
	return dict(zip(keys, elems))

def append_data(input, output, start, size):
	"""Append 'size' bytes from 'input' at 'start' to 'output' file"""

	if size == 0:
		return

	input.seek(start)
	outFile = open(output, 'ab')
	outFile.write(input.read(size))
	outFile.close()

def parse_metadata(image):
	"""Parses elf header metadata"""
	metadata = {}

	elf32_hdr = [
			("ident", "16s"),
			("type", "H"),
			("machine", "H"),
			("version", "I"),
			("entry", "I"),
			("phoff", "I"),
			("shoff", "I"),
			("flags", "I"),
			("ehsize", "H"),
			("phentsize", "H"),
			("phnum", "H"),
			("shentsize", "H"),
			("shnum", "H"),
			("shstrndx", "H"),
			]
	elf32_hdr = gen_struct(elf32_hdr, image)
	print "elf32_hdr>>>"
	print elf32_hdr

	#print "UUUUUUU"
	metadata['num_segments'] = elf32_hdr['phnum']
	metadata['pg_start'] = elf32_hdr['phoff']

	elf32_phdr = [
			("type", "I"),
			("offset", "I"),
			("vaddr", "I"),
			("paddr", "I"),
			("filesz", "I"),
			("memsz", "I"),
			("flags", "I"),
			("align", "I"),
			]

	metadata['segments'] = []
	for i in xrange(metadata['num_segments']):
		image.seek(metadata['pg_start'] + (i * elf32_hdr['phentsize']))
		phdr = gen_struct(elf32_phdr, image)
		metadata['segments'].append(phdr)
		phdr['hash'] = (phdr['flags'] & (0x7 << 24)) == (0x2 << 24)
	print "metadata>>>"
	print metadata

	#print "XXXXXXX"
	return metadata

def recover_segments(metadata, image, name):
	"""Creates <name>.bXX files for each segment"""
	filesize = 0
        fill_img = "/dev/zero"
        fill_img_handle = open(fill_img, 'rb')
	for i, seg in enumerate(metadata['segments']):
		start = seg['offset']
		size = seg['filesz']
		if start != 0:
		    size_fill = start - (filesize)
		    #print "KKKKKKKK-fillsize %d,after fill size %d" % (size_fill,filesize+size_fill)
		    append_data(fill_img_handle, image, 0, size_fill)
		input_img = "%s.b%02d" % (name, i)
		input_read = open(input_img, 'rb')
		#print "LLLLLLLL- file %s -> start %d,size %d" % (input_img,start,size)
		append_data(input_read, image, 0, size)
		input_read.close()

		filesize = start + size
	fill_img_handle.close()

if __name__ == "__main__":

	if len(sys.argv) != 2:
		usage()
	prefix = sys.argv[1]
        meta_image = "%s.mdt" % prefix
        output_img = "%s.mbn" % (prefix)
	image = open(meta_image, 'rb')
	if not is_elf(image):
		usage()


	metadata = parse_metadata(image)
	
	recover_segments(metadata, output_img, prefix)


