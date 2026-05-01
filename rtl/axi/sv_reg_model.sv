// Access Policies
typedef enum {REG_RW, REG_RO, REG_PRIV_RW} reg_access_e;

class sv_reg;
    string       name;
    bit [5:0]    addr;
    reg_access_e access;
    bit [DATA_WIDTH-1:0]    reset_val;
    
    // The "Golden" mirrored value
    bit [DATA_WIDTH-1:0]    mirrored_val; 

    function new(string n, bit [5:0] a, reg_access_e acc, bit [DATA_WIDTH-1:0] rst = 32'h00000000);
        this.name = n;
        this.addr = a;
        this.access = acc;
        this.reset_val = rst;
        this.mirrored_val = rst;
    endfunction

    // Predicts the DUT's response and updates the mirror if a write is valid
    function bit [1:0] predict_write(bit [DATA_WIDTH-1:0] wdata, bit is_priv);
        if (access == REG_RW) begin
            mirrored_val = wdata;
            return 2'b00; // OKAY
            
        end else if (access == REG_RO) begin
            return 2'b00; // OKAY (Writes silently ignored)
            
        end else if (access == REG_PRIV_RW) begin
            if (is_priv) begin
                mirrored_val = wdata;
                return 2'b00; // OKAY
            end else begin
                return 2'b10; // SLVERR (Blocked)
            end
        end
    endfunction

    // Predicts the DUT's read data and response
    function bit [1:0] predict_read(output bit [DATA_WIDTH-1:0] rdata, input bit is_priv);
        if (access == REG_RW || access == REG_RO) begin
            rdata = mirrored_val;
            return 2'b00; // OKAY
            
        end else if (access == REG_PRIV_RW) begin
            if (is_priv) begin
                rdata = mirrored_val;
                return 2'b00; // OKAY
            end else begin
                rdata = 32'h00000000;
                return 2'b10; // SLVERR (Blocked)
            end
        end
    endfunction
endclass
