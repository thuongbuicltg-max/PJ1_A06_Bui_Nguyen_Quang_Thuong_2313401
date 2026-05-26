module qam_recovery #(
        parameter W = 16,
        parameter K = 2
)(
        input wire                      clk,
        input wire                      rst_n,

        input wire signed [2*W-1:0]     s_axis_tdata_re,
        input wire signed [2*W-1:0]     s_axis_tdata_im,
        input wire                      s_axis_tvalid,
        output wire                     s_axis_tready,

        output reg [2*K-1:0]            m_axis_tdata,
        output reg                      m_axis_tvalid,
        input wire                      m_axis_tready
);

        assign s_axis_tready = 1'b1;

        // STEP 1
        localparam signed [2*W-1:0] TH_NEG2 = -2*65536; // - 2
        localparam signed [2*W-1:0] TH_0    = 0;
        localparam signed [2*W-1:0] TH_POS2 = 2*65536; // 2

        reg [K-1:0] gray_i_axis;
        reg [K-1:0] gray_q_axis;

        always @(*) begin
                // I AXIS
                if (s_axis_tdata_re < TH_NEG2)
                        gray_i_axis = 2'b00;
                else if (s_axis_tdata_re < TH_0)
                        gray_i_axis = 2'b01;
                else if (s_axis_tdata_re < TH_POS2)
                        gray_i_axis = 2'b11;
                else
                        gray_i_axis = 2'b10;

                // Q AXIS — reversed Gray (lut_q: 00→+3, 01→+1, 10→-3, 11→-1)
                if (s_axis_tdata_im < TH_NEG2)
                        gray_q_axis = 2'b10;   // amplitude<-2 → q_in=10 → output 10
                else if (s_axis_tdata_im < TH_0)
                        gray_q_axis = 2'b11;   // -2≤amp<0   → q_in=11 → output 11
                else if (s_axis_tdata_im < TH_POS2)
                        gray_q_axis = 2'b01;   // 0≤amp<2    → q_in=01 → output 01
                else
                        gray_q_axis = 2'b00;   // amp≥2      → q_in=00 → output 00

        end

        // Fix: dùng trực tiếp gray_i_axis và gray_q_axis làm output
        // (không cần gray2bin vì modulator LUT đã mã hóa đúng các biết binary)
        wire [2*K-1:0] bits_raw;
        assign bits_raw = {gray_i_axis, gray_q_axis};

        reg iq_valid_d1;
        // Gộp 1 always block duy nhất — fix multiple-driver bug
        always @(posedge clk or negedge rst_n) begin
                if (rst_n == 0) begin
                        m_axis_tdata  <= {2*K{1'b0}};
                        m_axis_tvalid <= 1'b0;
                        iq_valid_d1   <= 1'b0;
                end else begin
                        iq_valid_d1 <= s_axis_tvalid;
                        if (s_axis_tvalid) begin
                                m_axis_tdata <= bits_raw;
                        end
                        // Flow control: giữ valid nếu downstream chưa sẵn sàng
                        if (m_axis_tvalid && !m_axis_tready) begin
                                m_axis_tvalid <= 1'b1;        // hold
                        end else begin
                                m_axis_tvalid <= s_axis_tvalid; // 1 cycle latency
                        end
                end
        end

endmodule
