
// ============================================================================
//  axi Random Generator
// ============================================================================
class Generator_random extends Generator_base;

    function new(mailbox #(axi_item) gen2drv, int num_transactions);
        super.new(gen2drv, num_transactions);
    endfunction

    task run();
        axi_item item;
        for (int i = 0; i < num_transactions; i++) begin
            item = new();
            if (!item.randomize()) $fatal("Randomization failed!");
            gen2drv.put(item);
        end
    endtask
endclass : Generator_random

// ============================================================================
//  axi Direct Generator
// ============================================================================
class Generator_direct extends Generator_base;

    function new(mailbox #(axi_item) gen2drv, int num_transactions);
        super.new(gen2drv, num_transactions);
    endfunction

    task run();
        axi_item item;
        for (int i = 0; i < num_transactions; i++) begin
            // write transaction
            item = new();
            item.rnw = 0; // write
            item.reg_idx = i;
            item.data = $urandom;
            gen2drv.put(item);

            // read transaction for the same register
            item = new();
            item.rnw = 1; // read
            item.reg_idx = i;
            gen2drv.put(item);  
        end
    endtask
endclass : Generator_direct

// ============================================================================
//  axi random test
// ============================================================================

class axi_test_random extends axi_test_base;
    Generator_random temp_gen;
    function new(virtual axi_vif vif, int num_transactions);
        super.new("axi_test_random", vif, num_transactions);
        this.temp_gen = new(this.gen2drv, this.num_transactions);
        this.gen = this.temp_gen;
    endfunction
endclass : axi_test_random

// ============================================================================
//  axi direct test
// ============================================================================

class axi_test_direct extends axi_test_base;
    Generator_direct temp_gen;
    function new(virtual axi_vif vif, int num_transactions);
        super.new("axi_test_direct", vif, num_transactions);
        this.temp_gen = new(this.gen2drv, this.num_transactions);
        this.gen = this.temp_gen;
    endfunction
endclass : axi_test_direct
