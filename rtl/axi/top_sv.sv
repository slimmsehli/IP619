`timescale 1ns / 1ps

module top();

    // Clock and Reset
    logic        aclk;
    logic        aresetn;
    
    // AXI-Lite Signals
    logic [5:0]  awaddr;
    logic [2:0]  awprot;
    logic        awvalid;
    logic        awready;
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        wvalid;
    logic        wready;
    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;
    logic [5:0]  araddr;
    logic [2:0]  arprot;
    logic        arvalid;
    logic        arready;
    logic [31:0] rdata;
    logic [1:0]  rresp;
    logic        rvalid;
    logic        rready;

    // DUT Instantiation
    axi_lite_reg dut (
        .* 
    );

    // Clock Generation (100 MHz)
    initial begin
        aclk = 0;
        forever #5 aclk = ~aclk;
    end

    // --- Updated AXI Write Task ---
    task automatic axi_write(input logic [5:0] addr, input logic [7:0] data, input logic [2:0] prot, output logic [1:0] resp);
        begin
            @(posedge aclk);
            awvalid <= 1'b1;
            awaddr  <= addr;
            awprot  <= prot;
            wvalid  <= 1'b1;
            wdata   <= {24'h0, data};
            wstrb   <= 4'b0001; 
            bready  <= 1'b1;

            fork
                begin
                    wait(awready);
                    @(posedge aclk);
                    awvalid <= 1'b0;
                end
                begin
                    wait(wready);
                    @(posedge aclk);
                    wvalid <= 1'b0;
                end
            join

            wait(bvalid);
            resp = bresp; // Capture the response
            @(posedge aclk);
            bready <= 1'b0;
        end
    endtask

    // --- Updated AXI Read Task ---
    task automatic axi_read(input logic [5:0] addr, input logic [2:0] prot, output logic [7:0] data, output logic [1:0] resp);
        begin
            @(posedge aclk);
            arvalid <= 1'b1;
            araddr  <= addr;
            arprot  <= prot;
            rready  <= 1'b1;

            wait(arready);
            @(posedge aclk);
            arvalid <= 1'b0;

            wait(rvalid);
            data = rdata[7:0]; 
            resp = rresp; // Capture the response
            @(posedge aclk);
            rready <= 1'b0;
        end
    endtask

    always begin
        repeat(100) @(posedge aclk);
    end
    
    // --- Main Test Sequence ---
    logic [7:0] read_val;
    logic [7:0] expected_data;
    logic [7:0] write_data;
    logic [1:0] wresp;
    //logic [1:0] rresp;

    reg [7:0] write_queue [0:15];
    integer errors;
    
    initial begin
        $display("----------------------------------------");
        $display("TB AXI LITE WITH PERMISSIONS");
        $display("----------------------------------------");
        
        // Initialize signals
        aresetn = 0; errors = 0;
        awvalid = 0; awaddr = 0; awprot = 0; wvalid = 0; wdata = 0; wstrb = 0; bready = 0;
        arvalid = 0; araddr = 0; arprot = 0; rready = 0;
        
        for (int i = 0; i < 16; i++) begin
            write_queue[i] = $random();
        end

        // Apply reset
        #20 aresetn = 1;
        #20;

        $display("----------------------------------------");
        $display("Testing Reg 0-7: Standard Read/Write");
        $display("----------------------------------------");
        for (int i = 0; i < 8; i++) begin
            write_data = write_queue[i];
            
            axi_write(i * 4, write_data, 3'b000, wresp);
            axi_read(i * 4, 3'b000, read_val, rresp);
            
            if (read_val === write_data && wresp === 2'b00 && rresp === 2'b00) begin
                $display("[PASS] RW Reg %0d = %h", i, read_val);
            end else begin
                $display("[FAIL] RW Reg %0d = %h (Exp %h), WResp=%b, RResp=%b", i, read_val, write_data, wresp, rresp);
                errors++;
            end
        end

        $display("----------------------------------------");
        $display("Testing Reg 8-11: Read-Only");
        $display("----------------------------------------");
        for (int i = 8; i < 12; i++) begin
            axi_write(i * 4, 8'hFF, 3'b000, wresp); // Attempt unprivileged write
            axi_read(i * 4, 3'b000, read_val, rresp);
            
            if (read_val === 8'hAA && wresp === 2'b00 && rresp === 2'b00) begin
                $display("[PASS] RO Reg %0d = %h (Silently ignored write)", i, read_val);
            end else begin
                $display("[FAIL] RO Reg %0d = %h (Exp AA), WResp=%b, RResp=%b", i, read_val, wresp, rresp);
                errors++;
            end
        end

        $display("----------------------------------------");
        $display("Testing Reg 12-15: Privileged Access");
        $display("----------------------------------------");
        for (int i = 12; i < 16; i++) begin
            write_data = write_queue[i];
            
            // 1. Attempt Unprivileged Write
            axi_write(i * 4, write_data, 3'b000, wresp);
            if (wresp === 2'b10) $display("[PASS] Unpriv Write Reg %0d Blocked (SLVERR)", i);
            else begin $display("[FAIL] Unpriv Write Reg %0d allowed! WResp=%b", i, wresp); errors++; end
            
            // 2. Attempt Unprivileged Read
            axi_read(i * 4, 3'b000, read_val, rresp);
            if (rresp === 2'b10 && read_val === 8'h00) $display("[PASS] Unpriv Read Reg %0d Blocked (SLVERR)", i);
            else begin $display("[FAIL] Unpriv Read Reg %0d allowed! RResp=%b Data=%h", i, rresp, read_val); errors++; end
            
            // 3. Attempt Privileged Write & Read
            axi_write(i * 4, write_data, 3'b001, wresp); // bit [0] = 1 (Privileged)
            axi_read(i * 4, 3'b001, read_val, rresp);
            
            if (read_val === write_data && wresp === 2'b00 && rresp === 2'b00) begin
                $display("[PASS] Privileged RW Reg %0d = %h", i, read_val);
            end else begin
                $display("[FAIL] Privileged RW Reg %0d = %h (Exp %h), WResp=%b, RResp=%b", i, read_val, write_data, wresp, rresp);
                errors++;
            end
        end
        $finish;
    end

    final begin
        $display("----------------------------------------");
        if (errors == 0) begin
            $display("[PASS] All tests passed");
        end else begin
            $display("[FAIL] %0d errors occurred", errors);
        end
        $display("----------------------------------------");
    end

endmodule
