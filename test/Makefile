all: logic shift move arithmetic \
	div jump branch mem \
	forwarding
	@printf "\033[92;1m==>\033[0m all tests passed.\n"

logic:
	./test.sh logic

shift:
	./test.sh shift

move:
	./test.sh move

arithmetic:
	./test.sh arithmetic

div:
	./test.sh div

jump: 
	./test.sh jump

branch:
	./test.sh branch

mem:
	./test.sh mem

forwarding:
	./test.sh forwarding

clean:
	rm -rf */dump.vcd */output.txt */test.vvp */rom.txt