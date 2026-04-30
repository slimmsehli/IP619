
# install python virtual env and load peakhdl
py -m venv venv
source venv/bin/activate
pip install peakrdl

# convert to systemRDL from IPXACT
peakrdl systemrdl ./rtl/axi/axi_lite_reg_ipxact.xml -o regblock/axi_lite_reg_rdl.rdl
# generate uvm register model
peakrdl uvm regblock/axi_lite_reg_rdl.rdl -o regblock/axi_lite_reg_model.sv
# generate RTL
peakrdl regblock regblock/axi_lite_reg_rdl.rdl -o regblock/ --cpuif axi-flat
# generate gtml docs
peakrdl html turboencabulator.rdl -o html_dir/

# load regbank doc
python3 -m http.server -d $PWD/regblock/doc & firefox http://0.0.0.0:8000/