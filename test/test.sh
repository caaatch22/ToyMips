#!/bin/bash

echo -e '\e[96;1m==>\e[0m start testing' $1'.'
python3 gen_inst.py -s test-$1/asm.s -o test-$1/rom.txt

cd ./test-$1
iverilog -c ../files.txt -g2009 -o test.vvp

ignore=(
WARNING
VCD
)

flg=0
vvp test.vvp | while read line; do
    if [[ ! "${ignore[@]}"  =~ "${line:0:7}" && ! "${ignore[@]}"  =~ "${line:0:3}" ]]; then
        if [ "$flg" -eq 0 ]; then
            echo $line > output.txt
            flg=1
        else 
            echo $line >> output.txt
        fi
    fi
done


diff expected.txt output.txt 

if [ $? != 0 ]; then
    echo -e '\033[91;1m==>\033[0m test' $1 'failed.'
    exit 1
else 
    echo -e '\033[92;1m==>\033[0m test' $1 'passed.'
fi

