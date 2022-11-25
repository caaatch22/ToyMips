
inst_rom.om:     file format elf32-tradbigmips


Disassembly of section .text:

00000000 <_start>:
   0:	24110006 	li	s1,6
   4:	24120005 	li	s2,5
   8:	20110003 	addi	s1,zero,3
   c:	20120004 	addi	s2,zero,4
  10:	02329820 	add	s3,s1,s2
  14:	02519822 	sub	s3,s2,s1
  18:	02329824 	and	s3,s1,s2
  1c:	02329825 	or	s3,s1,s2
  20:	36330005 	ori	s3,s1,0x5
  24:	02329826 	xor	s3,s1,s2
  28:	0232982a 	slt	s3,s1,s2
  2c:	0251982a 	slt	s3,s2,s1
  30:	3c148000 	lui	s4,0x8000
  34:	24110003 	li	s1,3
  38:	24120004 	li	s2,4
  3c:	20110005 	addi	s1,zero,5
  40:	20120006 	addi	s2,zero,6
  44:	02329820 	add	s3,s1,s2
  48:	02519822 	sub	s3,s2,s1
  4c:	02329824 	and	s3,s1,s2
  50:	02329825 	or	s3,s1,s2
  54:	36330004 	ori	s3,s1,0x4
  58:	02329826 	xor	s3,s1,s2
  5c:	0232982a 	slt	s3,s1,s2
  60:	0251982a 	slt	s3,s2,s1
  64:	3c148000 	lui	s4,0x8000
  68:	ac120000 	sw	s2,0(zero)
  6c:	8c130000 	lw	s3,0(zero)
  70:	12320002 	beq	s1,s2,7c <test1>
  74:	20130005 	addi	s3,zero,5
  78:	12330002 	beq	s1,s3,84 <test2>

0000007c <test1>:
  7c:	24130007 	li	s3,7
  80:	08000023 	j	8c <end>

00000084 <test2>:
  84:	24130008 	li	s3,8
  88:	0800001f 	j	7c <test1>

Disassembly of section .reginfo:

00000000 <.reginfo>:
   0:	001e0000 	sll	zero,s8,0x0
	...
