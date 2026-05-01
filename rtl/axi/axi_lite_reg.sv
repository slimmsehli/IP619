`timescale 1ns / 1ps

module axi_lite_reg (
    input  logic        aclk,
    input  logic        aresetn,
    
    // Write Address Channel (AW)
    input  logic [5:0]  awaddr,
    input  logic [2:0]  awprot,   // Protection Signal
    input  logic        awvalid,
    output logic        awready,
    
    // Write Data Channel (W)
    input  logic [31:0] wdata,
    input  logic [3:0]  wstrb,
    input  logic        wvalid,
    output logic        wready,
    
    // Write Response Channel (B)
    output logic [1:0]  bresp,
    output logic        bvalid,
    input  logic        bready,
    
    // Read Address Channel (AR)
    input  logic [5:0]  araddr,
    input  logic [2:0]  arprot,   // Protection Signal
    input  logic        arvalid,
    output logic        arready,
    
    // Read Data Channel (R)
    output logic [31:0] rdata,
    output logic [1:0]  rresp,
    output logic        rvalid,
    input  logic        rready
);
    parameter DATA_WIDTH = 32;
    // 16 Registers of 8-bit width
    logic [DATA_WIDTH-1:0] slv_reg [0:15];
    
    logic [3:0] write_idx;
    logic [3:0] read_idx;
    
    assign write_idx = awaddr[5:2];
    assign read_idx  = araddr[5:2];

    localparam RESP_OKAY   = 2'b00;
    localparam RESP_SLVERR = 2'b10;

    // Keep ready asserted in idle; this avoids one-cycle pulse races.
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            awready <= 1'b0;
            wready  <= 1'b0;
            arready <= 1'b0;
        end else begin
            awready <= 1'b1;
            wready  <= 1'b1;
            arready <= 1'b1;
        end
    end

    // --- Register Write Logic & Response ---
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            bvalid <= 1'b0;
            bresp  <= RESP_OKAY;
            for (int i = 0; i < 16; i++) begin
                slv_reg[i] <= 8'h00;
            end
        end else begin
            // Clear bvalid when accepted by master
            if (bready && bvalid) bvalid <= 1'b0;

            if (awvalid && wvalid && ~bvalid) begin
                bvalid <= 1'b1;
                
                // Write Access Control Policy
                if (write_idx <= 7) begin
                    // Normal Read-Write
                    if (wstrb[0]) slv_reg[write_idx] <= wdata[7:0];
                    bresp <= RESP_OKAY;
                end else if (write_idx >= 8 && write_idx <= 11) begin
                    // Read-Only (silently ignore write)
                    bresp <= RESP_OKAY;
                end else begin
                    // Privileged Read-Write
                    if (awprot[0]) begin // If privileged
                        if (wstrb[0]) slv_reg[write_idx] <= wdata[7:0];
                        bresp <= RESP_OKAY;
                    end else begin
                        // Block write and return SLVERR
                        bresp <= RESP_SLVERR;
                    end
                end
            end
        end
    end

    // --- Read Data (R) Handshake & Logic ---
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rvalid <= 1'b0;
            rresp  <= RESP_OKAY;
            rdata  <= 32'h0;
        end else begin
            // Clear rvalid when accepted by master
            if (rvalid && rready) rvalid <= 1'b0;

            if (arvalid && ~rvalid) begin
                rvalid <= 1'b1;
                
                // Read Access Control Policy
                if (read_idx <= 7) begin
                    // Normal Read
                    rdata <= {24'h0, slv_reg[read_idx]};
                    rresp <= RESP_OKAY;
                end else if (read_idx >= 8 && read_idx <= 11) begin
                    // Read-Only Status Regs (Return dummy 8'hAA)
                    rdata <= {24'h0, 8'hAA};
                    rresp <= RESP_OKAY;
                end else begin
                    // Privileged Read
                    if (arprot[0]) begin
                        rdata <= {24'h0, slv_reg[read_idx]};
                        rresp <= RESP_OKAY;
                    end else begin
                        // Block read, return 0 and SLVERR
                        rdata <= 32'h0;
                        rresp <= RESP_SLVERR;
                    end
                end
            end
        end
    end

endmodule
