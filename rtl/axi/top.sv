`timescale 1ns / 1ps

// ============================================================================
// 1. AXI-Lite Interface
// ============================================================================
interface axi_vif(input logic aclk, input logic aresetn);
    logic [5:0]  awaddr; logic [2:0]  awprot; logic awvalid; logic awready;
    logic [31:0] wdata;  logic [3:0]  wstrb;  logic wvalid;  logic wready;
    logic [1:0]  bresp;  logic bvalid;  logic bready;
    logic [5:0]  araddr; logic [2:0]  arprot; logic arvalid; logic arready;
    logic [31:0] rdata;  logic [1:0]  rresp;  logic rvalid;  logic rready;
endinterface

// ============================================================================
// 2. Transaction Item
// ============================================================================
class axi_item;
    rand bit       rnw;     // 0 = Write, 1 = Read
    rand bit [3:0] reg_idx; // Register index 0 to 15
    rand bit [7:0] data;    // Data to write (ignored on reads)
    rand bit [2:0] prot;    // Protection level

    // Computed properties
    bit [5:0] addr;
    
    // Response fields (populated by Driver)
    bit [1:0] resp;
    bit [7:0] rdata;

    // Constrain the randomized protection signal so we get a good mix of 
    // privileged (prot[0]=1) and unprivileged (prot[0]=0) accesses.
    constraint c_prot { prot dist {3'b000 := 50, 3'b001 := 50}; }

    // Automatically compute the byte-aligned address after randomizing
    function void post_randomize();
        addr = reg_idx * 4; 
    endfunction

    function void print(string tag="");
        $display("[%s] %s Reg %0d (Addr %0h) | Data: %h | Prot: %b | RData: %h | Resp: %b", 
                 tag, rnw ? "READ " : "WRITE", reg_idx, addr, data, prot, rdata, resp);
    endfunction
endclass

// ============================================================================
// 3. Driver
// ============================================================================
class Driver;
    virtual axi_vif vif;
    mailbox #(axi_item) gen2drv;
    mailbox #(axi_item) drv2chk;

    function new(virtual axi_vif vif, mailbox #(axi_item) gen2drv, mailbox #(axi_item) drv2chk);
        this.vif = vif;
        this.gen2drv = gen2drv;
        this.drv2chk = drv2chk;
    endfunction

    task run();
        axi_item item;
        forever begin
            gen2drv.get(item); // Wait for a transaction from Generator

            if (item.rnw == 0) drive_write(item);
            else               drive_read(item);

            drv2chk.put(item); // Send completed transaction to Checker
        end
    endtask

    task drive_write(axi_item item);
        @(posedge vif.aclk);
        vif.awvalid <= 1'b1; vif.awaddr <= item.addr; vif.awprot <= item.prot;
        vif.wvalid  <= 1'b1; vif.wdata  <= {24'h0, item.data}; vif.wstrb <= 4'b0001;
        vif.bready  <= 1'b1;

        fork
            begin wait(vif.awready); @(posedge vif.aclk); vif.awvalid <= 1'b0; end
            begin wait(vif.wready);  @(posedge vif.aclk); vif.wvalid  <= 1'b0; end
        join
        
        wait(vif.bvalid);
        item.resp = vif.bresp; // Capture DUT response
        @(posedge vif.aclk);
        vif.bready <= 1'b0;
    endtask

    task drive_read(axi_item item);
        @(posedge vif.aclk);
        vif.arvalid <= 1'b1; vif.araddr <= item.addr; vif.arprot <= item.prot;
        vif.rready  <= 1'b1;

        wait(vif.arready);
        @(posedge vif.aclk);
        vif.arvalid <= 1'b0;

        wait(vif.rvalid);
        item.rdata = vif.rdata[7:0]; // Capture DUT read data
        item.resp  = vif.rresp;      // Capture DUT response
        @(posedge vif.aclk);
        vif.rready <= 1'b0;
    endtask
endclass

// ============================================================================
// 4. Scoreboard / Checker
// ============================================================================
class Checker;
    mailbox #(axi_item) drv2chk;
    int errors = 0;
    int passes = 0;
    
    // The "Golden Reference Model" of our registers
    bit [7:0] ref_reg [0:15];

    function new(mailbox #(axi_item) drv2chk);
        this.drv2chk = drv2chk;
        for (int i = 0; i < 16; i++) ref_reg[i] = 8'h00; // Power-on state
    endfunction

    task run();
        axi_item item;
        forever begin
            drv2chk.get(item); // Wait for completed transaction from Driver
            check_transaction(item);
        end
    endtask

    function void check_transaction(axi_item item);
        bit [1:0] exp_resp;
        bit [7:0] exp_data;
        bit       match = 1;

        // --- Determine Expected Behavior based on the Specification ---
        if (item.rnw == 0) begin // WRITE
            if (item.reg_idx <= 7) begin
                exp_resp = 2'b00; ref_reg[item.reg_idx] = item.data; // RW: Update model
            end else if (item.reg_idx <= 11) begin
                exp_resp = 2'b00; // RO: Silent ignore, response OKAY
            end else begin
                if (item.prot[0]) begin
                    exp_resp = 2'b00; ref_reg[item.reg_idx] = item.data; // Privileged RW: Update
                end else begin
                    exp_resp = 2'b10; // Privileged RW blocked: SLVERR
                end
            end
            
            // Check write results
            if (item.resp !== exp_resp) match = 0;
            
        end else begin // READ
            if (item.reg_idx <= 7) begin
                exp_resp = 2'b00; exp_data = ref_reg[item.reg_idx];
            end else if (item.reg_idx <= 11) begin
                exp_resp = 2'b00; exp_data = 8'hAA; // RO status dummy data
            end else begin
                if (item.prot[0]) begin
                    exp_resp = 2'b00; exp_data = ref_reg[item.reg_idx]; // Privileged
                end else begin
                    exp_resp = 2'b10; exp_data = 8'h00; // Blocked: SLVERR, Data zeroed
                end
            end
            
            // Check read results
            if (item.resp !== exp_resp || item.rdata !== exp_data) match = 0;
        end

        // --- Print Status ---
        if (match) begin
            passes++;
            item.print("PASS");
        end else begin
            errors++;
            item.print("FAIL");
            if (item.rnw == 1)
                $display("      -> Expected Data: %h, Expected Resp: %b", exp_data, exp_resp);
            else
                $display("      -> Expected Resp: %b", exp_resp);
        end
    endfunction
endclass

// ============================================================================
// 5. Generator
// ============================================================================
class Generator;
    mailbox #(axi_item) gen2drv;
    int num_transactions;

    function new(mailbox #(axi_item) gen2drv, int num_transactions);
        this.gen2drv = gen2drv;
        this.num_transactions = num_transactions;
    endfunction

    task run();
        axi_item item;
        for (int i = 0; i < num_transactions; i++) begin
            item = new();
            if (!item.randomize()) $fatal("Randomization failed!");
            gen2drv.put(item);
        end
    endtask
endclass

// ============================================================================
// 6. Top Level Module
// ============================================================================
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

    // Testbench OOP Components
    Generator gen;
    Driver    drv;
    Checker   chk;
    mailbox #(axi_item) gen2drv;
    mailbox #(axi_item) drv2chk;

    initial begin
        // Init signals and mailboxes
        aresetn = 0;
        vif.awvalid = 0; vif.wvalid = 0; vif.bready = 0;
        vif.arvalid = 0; vif.rready = 0;
        
        gen2drv = new();
        drv2chk = new();
        
        // Number of random transactions to run
        gen = new(gen2drv, 10000); 
        drv = new(vif, gen2drv, drv2chk);
        chk = new(drv2chk);

        // Reset sequence
        #20 aresetn = 1;
        #20;

        $display("========================================");
        $display("  STARTING UVM-LITE RANDOMIZED TEST");
        $display("========================================");

        // Start threads
        fork
            drv.run();
            chk.run();
            gen.run(); // Generator will finish first
        join_any

        // Give the final transactions time to flush through the driver/checker
        #100;

        $display("========================================");
        $display("  TEST COMPLETE");
        $display("  Transactions : %0d", chk.passes + chk.errors);
        $display("  Passes       : %0d", chk.passes);
        $display("  Errors       : %0d", chk.errors);
        $display("========================================");
        $finish;
    end
endmodule
