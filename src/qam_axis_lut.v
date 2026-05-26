// ============================================================
// Module : qam_axis_lut
// Desc   : Look-Up Table dung chung cho ca hai truc I va Q.
//          Chuyen doi K-bit binary dau vao -> muc bien do Gray-coded.
//          Voi K=2, L=4 muc: {-3, -1, 1, 3}
//          Anh xa chuan Gray: 00->-3, 01->-1, 10->+3, 11->+1
//          (vi moi cap ke nhau chi khac 1 bit - chuan Gray)
//
// Parameters:
//   K : so bit tren moi truc (default 2 cho 16-QAM)
//   W : do rong output (integer, truoc khi scale fixed-point)
// ============================================================
module qam_axis_lut #(
    parameter integer K = 2,
    parameter integer W = 12
)(
    input  wire [K-1:0]      g_in,   // K-bit binary input (bit nhom tu s2p)
    output reg  signed [W-1:0] a_out // bien do integer dau ra
);

    localparam integer L = 1 << K;           // so muc = 2^K = 4

    reg signed [W-1:0] lut [0:L-1];

    integer idx, b2, g2;

    // Khoi tao LUT trong initial block (chi chay khi mô phong)
    initial begin : init_lut
        for (idx = 0; idx < L; idx = idx + 1) begin
            // Buoc 1: Chuyen binary -> Gray
            b2 = idx;
            g2 = idx;
            repeat (K-1) begin
                b2 = b2 >> 1;
                g2 = g2 ^ b2;
            end
            // Buoc 2: Gray code -> bien do deu deu
            // g2 tu 0 den L-1 anh xa vao {-(L-1), -(L-3), ..., (L-3), (L-1)}
            // cong thuc: level = (g2 * 2) - (L - 1)
            lut[idx] = $signed((g2 << 1) - (L - 1));
        end
    end

    // Doc LUT: toi thieu (combinational)
    always @(*) begin
        a_out = lut[g_in];
    end

endmodule
