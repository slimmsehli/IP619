SHELL := /bin/bash

default: clean
all : clean comp run

clean:
	echo "\n\n\n Cleaning ... \n\n\n"
	rm -rf simdir *.log *.vcd *.hex simresult regblock

blockname:=axi

comp:
	echo "\n\n\n Compiling ... \n\n\n"
	mkdir -p simresult
	verilator --binary -j 0 --trace --timing -Wall \
	-F ./rtl/${blockname}/filelist.f -I./rtl/${blockname} \
	-F ./tb/${blockname}/filelist.f -I./tb/${blockname} \
	--top top --Mdir simresult -o simv \
	-Wno-UNDRIVEN -Wno-UNUSEDSIGNAL -Wno-WIDTHEXPAND -Wno-IMPLICIT \
	-Wno-PINCONNECTEMPTY -Wno-DECLFILENAME -Wno-BLKSEQ -Wno-INITIALDLY \
	-Wno-UNUSEDPARAM -Wno-WIDTHTRUNC -Wno-VARHIDDEN -Wno-REDEFMACRO -Wno-TIMESCALEMOD -Wno-PROCASSINIT \
	-Wno-CASEINCOMPLETE |& tee ./simresult/compile.log 

run:
	mkdir -p simresult
	echo "\n\n\n Simulation ... \n\n\n"
	./simresult/simv +TESTNAME=axi_test_random |& tee ./simresult/sim_random.log 
	./simresult/simv +TESTNAME=axi_test_direct |& tee ./simresult/sim_direct.log 
	#+TEST=$(TEST) |& tee ./simresult/sim.log 

wave:
	echo "\n\n\n Openining Waves ... \n\n\n"
	gtkwave ./simresult/sim.vcd &

reg:
	mkdir -p regblock
	# convert to systemRDL from IPXACT
	peakrdl systemrdl ./rtl/axi/axi_lite_reg_ipxact.xml -o regblock/axi_lite_reg_rdl.rdl
	# generate uvm register model
	peakrdl uvm regblock/axi_lite_reg_rdl.rdl -o regblock/axi_lite_reg_model.sv
	# generate RTL
	peakrdl regblock regblock/axi_lite_reg_rdl.rdl -o regblock/ --cpuif axi4-lite
	# generate gtml docs
	peakrdl html regblock/axi_lite_reg_rdl.rdl -o regblock/doc
