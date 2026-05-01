
parameter DATA_WIDTH = 32;

module top();
    logic aclk = 0;
    logic aresetn;

    // Clock generation
    always #5 aclk = ~aclk;

    // Instantiate Interface
    axi_vif vif(aclk, aresetn);

    // Instantiate DUT (Connect interface signals to DUT ports)
    axi_lite_reg dut (
        .aclk(vif.aclk), .aresetn(vif.aresetn),
        .awaddr(vif.awaddr), .awprot(vif.awprot), .awvalid(vif.awvalid), .awready(vif.awready),
        .wdata(vif.wdata),   .wstrb(vif.wstrb),   .wvalid(vif.wvalid),   .wready(vif.wready),
        .bresp(vif.bresp),   .bvalid(vif.bvalid), .bready(vif.bready),
        .araddr(vif.araddr), .arprot(vif.arprot), .arvalid(vif.arvalid), .arready(vif.arready),
        .rdata(vif.rdata),   .rresp(vif.rresp),   .rvalid(vif.rvalid),   .rready(vif.rready)
    );

    string testname;
    axi_test_base test;
    axi_test_random test_random_i;
    axi_test_b2b_readwrite test_b2b_readwrite_i;

    initial begin
        // get the testbane from the simulation command line
        if (!$value$plusargs("TESTNAME=%s", testname)) begin
            testname = "test_random"; 
        end

        case (testname)
            "axi_test_random": begin
                test_random_i = new(vif, 1000);
                test = test_random_i;
            end
            "axi_test_b2b_readwrite": begin
                test_b2b_readwrite_i = new(vif, 1000);
                test = test_b2b_readwrite_i;
            end
            default: begin
                $fatal("Invalid test name: %s", testname);
            end
        endcase

        test.run();
    end
endmodule
