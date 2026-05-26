module qam_axis_lut_q #(
        parameter K = 2,
        parameter W = 12
)(
        input wire [K-1:0] g_in,
        output reg signed [W-1:0] a_out
);
        localparam L = 1<<K;
        reg signed [W-1:0] lut [0:L-1];
        integer i;

        initial begin
                for (i=0; i<L; i=i+1) begin : init_lut_q
                        integer g2, b2, q_gray_rev, level;

                        b2 = i; g2 = i;
                        repeat (K-1) begin
                                b2 = b2>>1;
                                g2 = g2 ^ b2;
                        end

                        q_gray_rev = g2 ^ (L-1);
                        level = (q_gray_rev << 1) - (L-1);
                        lut[i] = level;
                end
        end

        always @(*) a_out = lut[g_in];
endmodule
