`timescale 1ns/1ps
// =================================================================
// Testbench: tb_qam16
// DUT:
//   - qam_mapping_axis  (aclk/aresetn, 1-bit serial in, IQ out)
//   - qam_recovery      (clk/rst_n,    IQ in, 4-bit out)
// Output files:
//   wave_qam16.vcd         -- waveform dump
//   const_snrXXdB.csv      -- IQ constellation per SNR
//   ber_vs_snr.csv         -- BER vs SNR summary
// =================================================================
module tb_qam16;

// -----------------------------------------------------------------
// PARAMETERS — khớp chính xác với DUT
// -----------------------------------------------------------------
// qam_mapping_axis
localparam integer K_PER_AXIS = 2;    // số bits/trục  (2 cho 16-QAM)
localparam integer W_MAP      = 12;   // độ rộng integer trước scale
localparam integer FRAC_BITS  = 16;   // K = 2^16 = 65536

// qam_recovery
localparam integer W_DEM      = 16;   // IQ input = 2*W_DEM = 32 bits
localparam integer K_DEM      = 2;    // output   = 2*K_DEM =  4 bits

// Chung
localparam integer IQ_W      = 2 * FRAC_BITS;  // 32 bit — khớp cả 2 DUT
localparam integer NUM_BITS  = 10000;         // 10^4 bits
localparam integer NUM_SYMS  = NUM_BITS / 4;   // 4 bit/symbol
localparam real    PI        = 3.141592653589793;

// -----------------------------------------------------------------
// CLOCK & RESET
// -----------------------------------------------------------------
reg clk;
reg aresetn;   // active-low reset cho qam_mapping_axis
reg rst_n;     // active-low reset cho qam_recovery

initial  clk = 0;
always #5 clk = ~clk;   // 100 MHz

// -----------------------------------------------------------------
// MODULATOR — qam_mapping_axis PORTS
// -----------------------------------------------------------------
// Slave AXI-Stream  (TB → Modulator)
reg        mod_s_tdata;    // 1-bit serial input
reg        mod_s_tvalid;
wire       mod_s_tready;   // always 1 từ DUT
reg        mod_s_tlast;

// Master AXI-Stream (Modulator → Channel)
wire signed [IQ_W-1:0] mod_m_re;    // I fixed-point
wire signed [IQ_W-1:0] mod_m_im;    // Q fixed-point
wire                   mod_m_valid;
reg                    mod_m_ready; // TB giữ = 1
wire                   mod_m_last;

// -----------------------------------------------------------------
// DEMODULATOR — qam_recovery PORTS
// -----------------------------------------------------------------
// Slave AXI-Stream  (Channel → Demodulator)
reg  signed [IQ_W-1:0] dem_s_re;
reg  signed [IQ_W-1:0] dem_s_im;
reg                    dem_s_valid;
wire                   dem_s_ready;   // always 1 từ DUT

// Master AXI-Stream (Demodulator → TB)
// qam_recovery KHÔNG có m_axis_tlast
wire [2*K_DEM-1:0] dem_m_data;    // 4-bit recovered symbol
wire               dem_m_valid;
reg                dem_m_ready;   // TB giữ = 1

// -----------------------------------------------------------------
// NOISE (float)
// -----------------------------------------------------------------
real EsN0_dB, snr_lin, sigma;

// -----------------------------------------------------------------
// STORAGE & COUNTERS
// -----------------------------------------------------------------
reg tx_bits [0:NUM_BITS-1];   // unpacked memory — tránh PRPASZ warning
integer bit_err_cnt, rx_sym_cnt;

// loop variables (module-level cho Verilog-2001)
integer snr_int, k, b, bit_base, err_sym;
reg signed [IQ_W-1:0] rx_i_nx, rx_q_nx;
reg [3:0] rx_sym, tx_sym;

// file handles
integer fp_ber, fp_con;

// =================================================================
// INSTANTIATE: qam_mapping_axis
// =================================================================
qam_mapping_axis #(
    .K_PER_AXIS(K_PER_AXIS),   // = 2
    .W         (W_MAP),         // = 12
    .FRAC_BITS (FRAC_BITS)      // = 16
) u_mod (
    .aclk           (clk),
    .aresetn        (aresetn),
    .s_axis_tdata   (mod_s_tdata),
    .s_axis_tvalid  (mod_s_tvalid),
    .s_axis_tready  (mod_s_tready),
    .s_axis_tlast   (mod_s_tlast),
    .m_axis_tdata_re(mod_m_re),
    .m_axis_tdata_im(mod_m_im),
    .m_axis_tvalid  (mod_m_valid),
    .m_axis_tready  (mod_m_ready),
    .m_axis_tlast   (mod_m_last)
);

// =================================================================
// INSTANTIATE: qam_recovery
// CHÍNH XÁC: dùng clk/rst_n, tham số W/K, KHÔNG có tlast
// =================================================================
qam_recovery #(
    .W(W_DEM),    // = 16
    .K(K_DEM)     // = 2
) u_dem (
    .clk            (clk),
    .rst_n          (rst_n),
    .s_axis_tdata_re(dem_s_re),
    .s_axis_tdata_im(dem_s_im),
    .s_axis_tvalid  (dem_s_valid),
    .s_axis_tready  (dem_s_ready),
    .m_axis_tdata   (dem_m_data),
    .m_axis_tvalid  (dem_m_valid),
    .m_axis_tready  (dem_m_ready)
);

// =================================================================
// BOX-MULLER GAUSSIAN PAIR
//   z0, z1 ~ N(0,1)  độc lập
//   noise_fixed = z * sigma * 2^FRAC_BITS
// =================================================================
task gaussian_pair;
    output real z0, z1;
    real u1, u2;
    begin
        u1 = 0.0;
        while (u1 <= 0.0)   // tránh ln(0)
            u1 = ($random & 32'h7fff_ffff) / 2147483648.0;
        u2 = ($random & 32'h7fff_ffff) / 2147483648.0;
        z0 = $sqrt(-2.0 * $ln(u1)) * $cos(2.0 * PI * u2);
        z1 = $sqrt(-2.0 * $ln(u1)) * $sin(2.0 * PI * u2);
    end
endtask

task awgn_add_symbol;
    input  signed [IQ_W-1:0] tx_i, tx_q;
    output signed [IQ_W-1:0] rx_i, rx_q;
    real nI, nQ;
    begin
        gaussian_pair(nI, nQ);
        rx_i = tx_i + $rtoi(nI * sigma * (1 << FRAC_BITS));
        rx_q = tx_q + $rtoi(nQ * sigma * (1 << FRAC_BITS));
    end
endtask

// VCD DUMP — comment out nếu disk quota ít
// Bỏ comment 2 dòng dưới nếu cần xem waveform:
// initial begin
//     $dumpfile("wave_qam16.vcd");
//     $dumpvars(0, tb_qam16);
// end

// =================================================================
// MAIN
// =================================================================
initial begin : MAIN_SIM

    // khởi tạo
    aresetn      = 0; rst_n        = 0;
    mod_s_tdata  = 0; mod_s_tvalid = 0; mod_s_tlast = 0;
    mod_m_ready  = 1;
    dem_s_re     = 0; dem_s_im     = 0; dem_s_valid  = 0;
    dem_m_ready  = 1;

    // sinh TX bits ngẫu nhiên
    for (k = 0; k < NUM_BITS; k = k + 1)
        tx_bits[k] = $random % 2;

    // mở file BER
    fp_ber = $fopen("ber_vs_snr.csv", "w");
    $fdisplay(fp_ber, "SNR_dB,NUM_BITS,Bit_Errors,BER");

    // reset DUT
    repeat(5) @(posedge clk); #1;
    aresetn = 1; rst_n = 1;
    repeat(5) @(posedge clk);

    // =========================================================
    // QUÉT SNR: 0 → 20 dB, bước 2 dB
    // =========================================================
    for (snr_int = 0; snr_int <= 20; snr_int = snr_int + 2) begin  // 11 điểm SNR: 0,2,4,...,20 dB

        EsN0_dB = snr_int * 1.0;
        snr_lin = 10.0 ** (EsN0_dB / 10.0);
        sigma   = $sqrt(5.0 / snr_lin);   // std dev chuẩn hóa per-dim

        bit_err_cnt = 0;
        rx_sym_cnt  = 0;

        fp_con = $fopen($sformatf("const_snr%0ddB.csv", snr_int), "w");
        $fdisplay(fp_con, "TxI_fixed,TxQ_fixed,RxI_fixed,RxQ_fixed");

        // truyền từng symbol
        for (k = 0; k < NUM_SYMS; k = k + 1) begin

            // (1) gửi 4 bit serial vào modulator
            mod_s_tvalid = 1;
            for (b = 0; b < 4; b = b + 1) begin
                mod_s_tdata = tx_bits[k*4 + b];
                mod_s_tlast = ((k == NUM_SYMS-1) && (b == 3)) ? 1'b1 : 1'b0;
                @(posedge clk); #1;
                while (!mod_s_tready) begin @(posedge clk); #1; end
            end
            mod_s_tvalid = 0;
            mod_s_tlast  = 0;

            // (2) chờ modulator xuất IQ
            @(posedge clk); #1;
            while (!mod_m_valid) begin @(posedge clk); #1; end

            // (3) cộng nhiễu AWGN
            awgn_add_symbol(mod_m_re, mod_m_im, rx_i_nx, rx_q_nx);

            // (4) log constellation
            $fdisplay(fp_con, "%d,%d,%d,%d", mod_m_re, mod_m_im, rx_i_nx, rx_q_nx);

            // (5) gửi IQ có nhiễu vào demodulator
            dem_s_re    = rx_i_nx;
            dem_s_im    = rx_q_nx;
            dem_s_valid = 1;
            @(posedge clk); #1;
            dem_s_valid = 0;

            // (6) dem_m_valid=1 ngay sau posedge trên (NBA đã cập nhật)
            // Không thêm clock, kiểm tra ngay
            while (!dem_m_valid) begin @(posedge clk); #1; end

            // (7) đếm bit lỗi
            rx_sym   = dem_m_data;
            bit_base = k * 4;
            // tx_sym tương ứng thứ tự s2p: b0 vào trước → MSB của sym_bits
            tx_sym = {tx_bits[bit_base+0], tx_bits[bit_base+1],
                      tx_bits[bit_base+2], tx_bits[bit_base+3]};

            err_sym = (rx_sym[3] ^ tx_sym[3])
                    + (rx_sym[2] ^ tx_sym[2])
                    + (rx_sym[1] ^ tx_sym[1])
                    + (rx_sym[0] ^ tx_sym[0]);

            bit_err_cnt = bit_err_cnt + err_sym;
            rx_sym_cnt  = rx_sym_cnt  + 1;

        end // NUM_SYMS

        $fclose(fp_con);

        $display("SNR=%2.0f dB | Errors=%5d/%5d | BER=%e",
                 EsN0_dB, bit_err_cnt, NUM_BITS,
                 (bit_err_cnt == 0) ? 1.0e-10 : (bit_err_cnt * 1.0 / NUM_BITS));

        $fdisplay(fp_ber, "%0d,%0d,%0d,%e",
                  snr_int, NUM_BITS, bit_err_cnt,
                  (bit_err_cnt == 0) ? 1.0e-10 : (bit_err_cnt * 1.0 / NUM_BITS));

        // reset ngắn giữa các lần SNR
        aresetn = 0; rst_n = 0;
        repeat(4) @(posedge clk);
        aresetn = 1; rst_n = 1;
        repeat(4) @(posedge clk);

    end // SNR sweep

    $fclose(fp_ber);
    $display("================================================");
    $display("DONE! ber_vs_snr.csv + const_snrXXdB.csv saved.");
    $display("================================================");
    repeat(20) @(posedge clk);
    $finish;

end

endmodule
