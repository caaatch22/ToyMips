# `ToyMips`

## Introduction

This is my cource project for computer architecture. We implement an five stage MIPS32 pipeline CPU in verilog. 

All instuctions supported are listed below.

|  type   |   instuction  | tested   |
| --- | --- | --- |
|arithmetic | add, addi, addu, addiu, sub, subu, slt, slti, sltiu, mult, multu, div, divu, clo, clz | ✔ |
|logic | and, andi, or, ori, lui, nor, xor, xori | ✔ |
|shift | sll, sllv, sra, srav, srl, srlv | ✔ |
|jump | j, jal, jr, jalr | ✔ |
| branch | beq, bne, bgez, bgtz, blez, bltz, bltzal, bgezal, | ✔|
| move | mfhi, mflo, mthi, mtlo, movz, movn | ✔ | 
|load-store| lb, lbu, lh, lhu, lw, sb, sh, sw, ll, sc|✔ |
| exception-related |eret, mfc0, mtc0, break, syscall,  |  |



## build under Linux

### Install the `iverilog` and `gtkwave`(optional) 
```shell
apt-get install iverilog
apt-get install gtkwave
```

After installation, you may try the following command to see the version information:

```shell
iverilog -v
gtkwave -v
```

### Install the `GCC cross compilation tool chain`	

We need use MIPS compilation tool chain to generate machine code from assembly.

```shell
wget https://sourcery.mentor.com/GNUToolchain/package12725/public/mips-sde-elf/mips-2014.05-24-mips-sde-elf-i686-pc-linux-gnu.tar.bz2
tar jxvf mips-2014.05-24-mips-sde-elf-i686-pc-linux-gnu.tar.bz2
rm mips-2014.05-24-mips-sde-elf-i686-pc-linux-gnu.tar.bz2
mv mips-2014.05 ~
```

for 64-bit Linux, you need
```shell
sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install libc6:i386 libncurses5:i386 libstdc++6:i386
```


## Installation
```shell
git clone git@github.com:caaatch22/ToyMips.git
```

## Usages

you can use our test frame.

```shell
cd test 
make all
```

In detail, the `test` is composed of the following unit test cases:

    test-arithmetic
	test-logic
	test-shift
	test-move
    test-div
	test-jump
	test-branch
	test-mem
	test-forwarding

You may also use the following command to run a signle unit test.

```shell
cd test
make <test-name>
```

You may use gtkwave to see waveform with `dump.vcd` in `<test-name>` file and `vvp <test-name>/test.vvp` to simulate. 

## License
This project is released under [MIT license](https://github.com/caaatch22/ToyMips/blob/main/LICENSE).

