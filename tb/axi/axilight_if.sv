// ============================================================================
// 1. AXI-Lite Interface
// ============================================================================
interface axi_vif(input logic aclk, input logic aresetn);
    logic [5:0]  awaddr; logic [2:0]  awprot; logic awvalid; logic awready;
    logic [31:0] wdata;  logic [3:0]  wstrb;  logic wvalid;  logic wready;
    logic [1:0]  bresp;  logic bvalid;  logic bready;
    logic [5:0]  araddr; logic [2:0]  arprot; logic arvalid; logic arready;
    logic [31:0] rdata;  logic [1:0]  rresp;  logic rvalid;  logic rready;
endinterface : axi_vif
