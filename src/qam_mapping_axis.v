module qam_mapping_axis #(
        parameter integer K_PER_AXIS = 2,
        parameter W                  = 12,
        parameter FRAC_BITS          = 16
)(
        input wire aclk,
        input wire aresetn,

        input wire [0:0]                s_axis_tdata,
        input wire                      s_axis_tvalid,
        output wire                     s_axis_tready,
        input wire                      s_axis_tlast,

        output reg [2*FRAC_BITS-1:0]   m_axis_tdata_re, m_axis_tdata_im,
        output reg                      m_axis_tvalid,
        input wire                      m_axis_tready,
        output reg                      m_axis_tlast
);

        localparam integer BITS_PER_SYM = 2*K_PER_AXIS;
// 1) serial bits -> symbol bits
        wire [BITS_PER_SYM-1:0]        sym_bits;
        wire                            sym_valid;

        s2p_bits #(
                .BITS_PER_SYM(BITS_PER_SYM)
        ) u_s2p_bits (
                .clk            (aclk),
                .rst_n          (aresetn),
                .in_bit         (s_axis_tdata[0]),
                .in_valid       (s_axis_tvalid & s_axis_tready),
                .sym_bits       (sym_bits),
                .sym_valid      (sym_valid)
        );

        assign s_axis_tready = 1'b1;

        localparam CNTW = (BITS_PER_SYM <= 1) ? 1 : $clog2(BITS_PER_SYM);
        reg [CNTW-1:0]  bit_pos;
        reg             sym_last_flag;

        always @(posedge aclk or negedge aresetn) begin
                if ( aresetn == 0) begin
                        bit_pos       <= {CNTW{1'b0}};
                        sym_last_flag <= 1'b0;
                end else begin
                        if (s_axis_tvalid && s_axis_tready) begin

                                if((bit_pos == BITS_PER_SYM-1) && s_axis_tlast)
                                        sym_last_flag <= 1'b1;
                                if (bit_pos == BITS_PER_SYM - 1)
                                        bit_pos <= {CNTW{1'b0}};
                                else
                                        bit_pos <= bit_pos + 1'b1;
                        end

                        if (m_axis_tvalid && m_axis_tready)
                                sym_last_flag <= 1'b0;
                end
        end

// 2) symbol bits -> integer amplitude levels

        wire [K_PER_AXIS-1:0] i_bits = sym_bits[BITS_PER_SYM-1 : K_PER_AXIS];
        wire [K_PER_AXIS-1:0] q_bits = sym_bits[K_PER_AXIS-1 : 0];

        wire signed [W-1:0] i_amp_int;
        wire signed [W-1:0] q_amp_int;

        qam_axis_lut #(
                .K(K_PER_AXIS),
                .W(W)
        ) u_i_lut (
                .g_in (i_bits),
                .a_out(i_amp_int)
        );

        qam_axis_lut_q #(
                .K(K_PER_AXIS),
                .W(W)
        ) u_q_lut (
                .g_in(q_bits),
                .a_out(q_amp_int)
        );
// 3) integer amplitude -> fixed-point Q-format

        wire signed [2*FRAC_BITS-1:0] i_amp_fx;
        wire signed [2*FRAC_BITS-1:0] q_amp_fx;

        assign i_amp_fx = $signed(i_amp_int) <<< FRAC_BITS;
        assign q_amp_fx = $signed(q_amp_int) <<< FRAC_BITS;

// 4) AXIS output

        wire fire_out = m_axis_tvalid && m_axis_tready;

        always @(posedge aclk or negedge aresetn) begin
                if(aresetn ==0) begin
                        m_axis_tdata_re <= {(2*FRAC_BITS){1'b0}};
                        m_axis_tdata_im <= {(2*FRAC_BITS){1'b0}};
                        m_axis_tvalid   <= 1'b0;
                        m_axis_tlast    <= 1'b0;
                end else begin
                        if (fire_out) begin
                                m_axis_tvalid   <= 1'b0;
                                m_axis_tlast    <= 1'b0;
                        end

                        if (sym_valid && (m_axis_tready || !m_axis_tvalid)) begin
                                m_axis_tdata_re <= i_amp_fx;
                                m_axis_tdata_im <= q_amp_fx;
                                m_axis_tvalid   <= 1'b1;
                                m_axis_tlast    <= sym_last_flag;
                        end
                end
        end

endmodule
