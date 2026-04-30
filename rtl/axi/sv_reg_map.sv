class sv_reg_map;
    // Associative array of registers keyed by address
    sv_reg regs[int]; 

    function new();
        // Zone 1: Registers 0-7 (Normal RW)
        for (int i = 0; i < 8; i++) begin
            regs[i*4] = new($sformatf("RW_REG_%0d", i), i*4, REG_RW, 8'h00);
        end
        
        // Zone 2: Registers 8-11 (Read-Only)
        // Reset value is set to 8'hAA based on our DUT design
        for (int i = 8; i < 12; i++) begin
            regs[i*4] = new($sformatf("RO_REG_%0d", i), i*4, REG_RO, 8'hAA);
        end
        
        // Zone 3: Registers 12-15 (Privileged RW)
        for (int i = 12; i < 16; i++) begin
            regs[i*4] = new($sformatf("PRIV_REG_%0d", i), i*4, REG_PRIV_RW, 8'h00);
        end
    endfunction

    // Helper function to fetch a register by its AXI address
    function sv_reg get_reg_by_addr(bit [5:0] addr);
        if (regs.exists(addr)) begin
            return regs[addr];
        end else begin
            $error("Address %0h does not map to any register!", addr);
            return null;
        end
    endfunction
endclass
