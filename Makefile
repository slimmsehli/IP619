SHELL := /bin/bash

default: clean
all : clean comp run

clean:
	echo "\n\n\n Cleaning ... \n\n\n"
	rm -rf simdir *.log *.vcd *.hex simresult

blockname:=axi

comp:
	echo "\n\n\n Compiling ... \n\n\n"
	mkdir -p simresult
	verilator --binary -j 0 --trace --timing -Wall \
	-F ./rtl/${blockname}/filelist.f -I./rtl/${blockname} \
	--top top --Mdir simresult -o simv \
	-Wno-UNDRIVEN -Wno-UNUSEDSIGNAL -Wno-WIDTHEXPAND -Wno-IMPLICIT \
	-Wno-PINCONNECTEMPTY -Wno-DECLFILENAME -Wno-BLKSEQ -Wno-INITIALDLY \
	-Wno-UNUSEDPARAM -Wno-WIDTHTRUNC -Wno-VARHIDDEN -Wno-REDEFMACRO -Wno-TIMESCALEMOD -Wno-PROCASSINIT \
	-Wno-CASEINCOMPLETE |& tee ./simresult/compile.log 

run:
	mkdir -p simresult
	echo "\n\n\n Simulation ... \n\n\n"
	./simresult/simv 
	#+TEST=$(TEST) |& tee ./simresult/sim.log 

wave:
	echo "\n\n\n Openining Waves ... \n\n\n"
	gtkwave ./simresult/sim.vcd &
