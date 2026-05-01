
# AXI4 Light register bank

## Install peakhdl for register bank 
* Install python virtual env and load peakhdl
* py -m venv venv
* source venv/bin/activate
* pip install peakrdl

## use peakhdl to generate the regmodel from the IPXACT
* convert to systemRDL from IPXACT : peakrdl systemrdl ./rtl/axi/axi_lite_reg_ipxact.xml -o regblock/axi_lite_reg_rdl.rdl
* Generate uvm register model: peakrdl uvm regblock/axi_lite_reg_rdl.rdl -o regblock/axi_lite_reg_model.sv
* Generate RTL: peakrdl regblock regblock/axi_lite_reg_rdl.rdl -o regblock/ --cpuif axi-flat
* Generate gtml docs: peakrdl html turboencabulator.rdl -o html_dir/
* Load regbank doc: python3 -m http.server -d $PWD/regblock/doc & firefox http://0.0.0.0:8000/