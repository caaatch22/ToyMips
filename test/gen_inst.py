import os
import sys
import argparse
import platform
import binascii


assert platform.system() == 'Linux'
parser = argparse.ArgumentParser()
parser.add_argument("-s", dest="s", default="assemble.s", type=str)
parser.add_argument("-o", dest="o", default="rom.txt", type=str)
args = parser.parse_args()

args.tc = "~/mips-2014.05/bin/mips-sde-elf-"

os.system("{}as -mips32 {} -o rom.o".format(args.tc, args.s))
os.system("{}ld -T ram.ld rom.o -o rom.om".format(args.tc))
os.system("{}objcopy -O binary rom.om rom.bin".format(args.tc))


with open(args.o, "w") as f:
	s = binascii.b2a_hex(open('rom.bin', 'rb').read()).decode('utf-8')
	for i in range(len(s) // 8):
		print(s[i * 8: (i + 1)*8], file=f)

os.system("rm rom.o rom.om rom.bin")