// ============================================================================
// axi base transaction
// ============================================================================
class axi_item;
    rand bit       rnw;     // 0 = Write, 1 = Read
    rand bit [3:0] reg_idx; // Register index 0 to 15
    rand bit [DATA_WIDTH-1:0] data;    // Data to write (ignored on reads)
    rand bit [2:0] prot;    // Protection level

    // Computed properties
    bit [5:0] addr;
    
    // Response fields (populated by Driver)
    bit [1:0] resp;
    bit [DATA_WIDTH-1:0] rdata;

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
endclass : axi_item

// ============================================================================
//  axi base Driver
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
        vif.wvalid  <= 1'b1; vif.wdata  <= item.data; vif.wstrb <= 4'b0001;
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
        item.rdata = vif.rdata; // Capture DUT read data
        item.resp  = vif.rresp;      // Capture DUT response
        @(posedge vif.aclk);
        vif.rready <= 1'b0;
    endtask
endclass : Driver

// ============================================================================
//  axi base Checker
// ============================================================================
class Checker;
    mailbox #(axi_item) drv2chk;
    int errors = 0;
    int passes = 0;
    
    // Instantiate our custom register model
    sv_reg_map reg_model;

    function new(mailbox #(axi_item) drv2chk);
        this.drv2chk = drv2chk;
        this.reg_model = new(); // Build the register map
    endfunction

    task run();
        axi_item item;
        forever begin
            drv2chk.get(item);
            check_transaction(item);
        end
    endtask

    function void check_transaction(axi_item item);
        sv_reg target_reg;
        bit [1:0] exp_resp;
        bit [DATA_WIDTH-1:0] exp_data;
        bit       match = 1;

        // 1. Look up the register being accessed
        target_reg = reg_model.get_reg_by_addr(item.addr);
        if (target_reg == null) return; // Skip if invalid address

        // 2. Ask the register model to predict the outcome
        if (item.rnw == 0) begin
            // WRITE
            exp_resp = target_reg.predict_write(item.data, item.prot[0]);
            if (item.resp !== exp_resp) match = 0;
        end else begin
            // READ
            exp_resp = target_reg.predict_read(exp_data, item.prot[0]);
            if (item.resp !== exp_resp || item.rdata !== exp_data) match = 0;
        end

        // 3. Print Results
        if (match) begin
            passes++;
            item.print($sformatf("PASS (%s)", target_reg.name));
        end else begin
            errors++;
            item.print($sformatf("FAIL (%s)", target_reg.name));
            if (item.rnw == 1)
                $display("      -> Expected Data: %h, Expected Resp: %b", exp_data, exp_resp);
            else
                $display("      -> Expected Resp: %b", exp_resp);
        end
    endfunction
endclass :  Checker

// ============================================================================
//  axi base Generator
// ============================================================================
class Generator_base;
    mailbox #(axi_item) gen2drv;
    int num_transactions;

    function new(mailbox #(axi_item) gen2drv, int num_transactions);
        this.gen2drv = gen2drv;
        this.num_transactions = num_transactions;
    endfunction

    virtual task run(); // tihs will forece the derived class to implement the run task
    endtask
endclass : Generator_base

// ============================================================================
//  axi base test
// ============================================================================
class axi_test_base;
    string name;
    int num_transactions;
    virtual axi_vif vif;

    Generator_base gen;
    Driver    drv;
    Checker   chk;
    mailbox #(axi_item) gen2drv;
    mailbox #(axi_item) drv2chk;
    
    function new(string name = "axi_test_base", virtual axi_vif vif, int num_transactions);
        this.name = name;
        this.vif = vif;
        this.num_transactions = num_transactions;
        this.gen2drv = new();
        this.drv2chk = new();
        gen = new(this.gen2drv, this.num_transactions); 
        drv = new(this.vif, this.gen2drv, this.drv2chk);
        chk = new(this.drv2chk);
    endfunction

    task run();
        // initialize the interface signals
        vif.aresetn = 0;
        vif.awvalid = 0; vif.wvalid = 0; vif.bready = 0;
        vif.arvalid = 0; vif.rready = 0;
        // Reset sequence
        #20 vif.aresetn = 1;
        #20;
        $display("========================================");
        $display("  STARTING UVM-LITE : %s ", this.name);
        $display("========================================");

        // Start threads
        fork
            drv.run();
            chk.run();
            gen.run(); // Generator will finish first
        join_any

        // Wait until the Checker has verified every transaction generated
        while ((this.chk.passes + this.chk.errors) < this.gen.num_transactions) begin
            @(posedge this.vif.aclk);
        end

        // Give the final transactions time to flush through the driver/checker
        #100;

        $display("========================================");
        $display("  TEST COMPLETE : %s", this.name);
        $display("  Transactions : %0d", chk.passes + chk.errors);
        $display("  Passes       : %0d", chk.passes);
        $display("  Errors       : %0d", chk.errors);
        $display("========================================");
        $finish;

        
    endtask
endclass : axi_test_base
