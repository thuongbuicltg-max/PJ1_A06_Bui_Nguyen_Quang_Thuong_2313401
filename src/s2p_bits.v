module s2p_bits #(
        parameter BITS_PER_SYM = 4
)(
        input wire        clk,
        input wire        rst_n,
        input wire        in_bit,
        input wire        in_valid,
        output reg [BITS_PER_SYM-1:0] sym_bits,
        output reg        sym_valid
);
        localparam CNT_W = (BITS_PER_SYM <= 1) ? 1: $clog2(BITS_PER_SYM);
        reg [CNT_W-1:0] bit_cnt;
        reg [BITS_PER_SYM-1:0] shift_reg;

        always @(posedge clk or negedge rst_n) begin
                if (rst_n == 0) begin
                        bit_cnt   <= {CNT_W{1'b0}};
                        shift_reg <= {BITS_PER_SYM{1'b0}};
                        sym_bits  <= {BITS_PER_SYM{1'b0}};
                        sym_valid <= 1'b0;
                end else begin
                        sym_valid <= 1'b0;

                        if (in_valid) begin
                                shift_reg <= {shift_reg[BITS_PER_SYM-2:0], in_bit};

                                if (bit_cnt == BITS_PER_SYM-1) begin
                                        sym_bits  <= {shift_reg[BITS_PER_SYM-2:0], in_bit};
                                        sym_valid <= 1'b1;
                                        bit_cnt   <= {CNT_W{1'b0}};
                                end else begin
                                        bit_cnt <= bit_cnt + 1'b1;
                                end
                        end
                end
        end
endmodule
