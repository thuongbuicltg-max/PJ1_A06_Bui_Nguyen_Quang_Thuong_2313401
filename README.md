# Thiết kế và mô phỏng hệ thống điều chế – giải điều chế 16-QAM baseband IQ trên Verilog RTL với đánh giá BER theo SNR trong kênh AWGN

Dự án này thực hiện thiết kế, mô phỏng và đánh giá hiệu năng của bộ thu phát điều chế/giải điều chế **16-QAM ở băng thông cơ sở (Baseband IQ)** sử dụng ngôn ngữ mô tả phần cứng **Verilog RTL**. Dự án kiểm chứng hiệu năng tỷ lệ lỗi bit (BER) thực nghiệm so với lý thuyết thông qua phương pháp mô phỏng thống kê **Monte Carlo** dưới tác động của kênh nhiễu Gaussian trắng cộng (**AWGN**).

---

## 📌 Tổng quan dự án

Hệ thống bao gồm các khối chức năng chính được thiết kế ở mức truyền cấu trúc RTL, tuân thủ giao tiếp chuẩn công nghiệp **AMBA AXI-Stream**:
1. **S2P (Serial-to-Parallel)**: Chuyển đổi dòng bit ngõ vào nối tiếp sang các ký tự song song 4-bit.
2. **16-QAM Modulator (LUT mapping)**: Ánh xạ mã Gray 4-bit ngõ vào sang điểm tọa độ chòm sao tương ứng trên mặt phẳng IQ với hệ số tỉ lệ dấu chấm tĩnh (Fixed-point Scale) $K = 2^{16} = 65536$.
3. **Kênh nhiễu AWGN**: Được tích hợp trong Testbench thông qua thuật toán biến đổi **Box-Muller** sinh nhiễu phân phối chuẩn $\mathcal{N}(0, \sigma^2)$ và cộng trực tiếp vào trục I và Q.
4. **16-QAM Demodulator (Threshold Decision)**: Thực hiện giải điều chế quyết định cứng dựa trên các ngưỡng tĩnh tối ưu ($\pm 2K$ và $0$) để khôi phục dòng bit ngõ ra.
5. **Monte Carlo Testbench**: Quét dải SNR từ $0 \to 20\text{ dB}$ (bước $2\text{ dB}$), truyền $10^4$ bit trên mỗi điểm SNR để đo đạc và xuất dữ liệu BER thô cùng tọa độ chòm sao ra các file CSV.

---

## 📂 Cấu trúc thư mục dự án

```text
├── src/                      # Thư mục chứa mã nguồn chính và kịch bản vẽ đồ thị
│   ├── qam_mapping_axis.v    # Khối điều chế 16-QAM (tích hợp S2P + AXI-Stream interface)
│   ├── qam_recovery.v        # Khối giải điều chế quyết định cứng 16-QAM (AXI-Stream)
│   ├── qam_axis_lut.v        # Bảng tra tọa độ nhánh I (mã hóa Gray)
│   ├── qam_axis_lut_q.v      # Bảng tra tọa độ nhánh Q (mã hóa Gray)
│   ├── s2p_bits.v            # Khối chuyển đổi nối tiếp sang song song
│   ├── tb_qam16.v            # Testbench Monte Carlo quét SNR và xuất CSV kết quả
│   ├── plot_results.py       # Script Python vẽ đồ thị BER vs SNR và giản đồ chòm sao chuẩn
│   └── plot_extra.py         # Script Python vẽ Histogram nhiễu và giản đồ chòm sao Voronoi
│
├── code/                     # Nơi lưu trữ các kết quả ảnh PNG và dữ liệu CSV chạy thực tế
│   ├── ber_vs_snr.png
│   ├── constellation_grid.png
│   ├── noise_histogram.png
│   └── constellation_enhanced.png
│
├── latex/                    # Mã nguồn báo cáo LaTeX
│   └── report1/
│       ├── report_project1.tex  # File biên dịch chính của báo cáo
│       ├── branch_content/      # Nội dung chi tiết các chương (Chương 1 - 5)
│       └── input_picture/       # Các hình vẽ được chèn trực tiếp vào báo cáo
│
├── run_all_experiments.py    # Kịch bản tự động hóa toàn bộ thí nghiệm (Phần cứng + Đồ thị)
└── README.md                 # Tài liệu hướng dẫn sử dụng dự án (File này)
```

---

## 🛠️ Yêu cầu hệ thống và cài đặt

Dự án hỗ trợ chạy trên cả **Linux (Ubuntu)** và **Windows**. Theo báo cáo đồ án, môi trường mô phỏng phần cứng tối ưu được thiết lập trên máy ảo **Ubuntu 22.04 LTS (VirtualBox)**.

### 1. Đối với mô phỏng phần cứng (Verilog RTL)
Yêu cầu cài đặt **Icarus Verilog** (trình biên dịch) và **GTKWave** (nếu muốn xem giản đồ sóng):

* **Trên Linux (Ubuntu/Debian):**
  ```bash
  sudo apt-get update
  sudo apt-get install iverilog gtkwave
  ```
* **Trên Windows:**
  Tải và cài đặt gói cài đặt Icarus Verilog từ [cổng phân phối chính thức](http://bleyer.org/icarus/) và thêm đường dẫn thư mục `bin` vào biến môi trường `PATH` của hệ thống.

### 2. Đối với trực quan hóa và phân tích dữ liệu (Python)
Yêu cầu cài đặt **Python 3.x** và các thư viện tính toán, vẽ đồ thị:
```bash
pip install numpy scipy pandas matplotlib
```

---

## 🚀 Hướng dẫn chạy thí nghiệm

### Cách 1: Chạy tự động bằng Kịch bản Tích hợp (Khuyến nghị)
Chạy kịch bản thông minh duy nhất ở thư mục gốc:
```bash
python run_all_experiments.py
```
* **Nếu máy có sẵn Icarus Verilog:** Kịch bản sẽ tự động biên dịch, chạy mô phỏng phần cứng RTL, xuất dữ liệu CSV, sau đó gọi các kịch bản Python vẽ đồ thị, tự động cập nhật ảnh vào thư mục báo cáo LaTeX.
* **Nếu máy chưa cài Icarus Verilog:** Kịch bản sẽ in hướng dẫn chi tiết cách chạy trong máy ảo Ubuntu, sau đó tự động sử dụng dữ liệu mẫu thực nghiệm chuẩn để chạy vẽ đồ thị và cập nhật ảnh báo cáo, giúp bạn kiểm tra giao diện trực quan hóa ngay lập tức.

---

### Cách 2: Chạy thủ công từng bước

#### Bước 1: Biên dịch và chạy mô phỏng Verilog RTL
Di chuyển vào thư mục chứa code và thực hiện biên dịch bằng `iverilog` phiên bản chuẩn 2012:
```bash
cd src/
iverilog -g2012 -o sim tb_qam16.v qam_mapping_axis.v qam_recovery.v qam_axis_lut.v qam_axis_lut_q.v s2p_bits.v
vvp sim
```
* **Kết quả đầu ra:** 
  * `wave_qam16.vcd` (File giản đồ sóng để xem trên GTKWave).
  * `ber_vs_snr.csv` (File chứa số liệu BER thực nghiệm quét qua 11 điểm SNR).
  * `const_snr0dB.csv`, `const_snr8dB.csv`, `const_snr16dB.csv`, `const_snr20dB.csv` (Tọa độ IQ nhận phục vụ vẽ chòm sao).

#### Bước 2: Vẽ đồ thị trực quan hóa bằng Python
Di chuyển các file `.csv` vừa sinh ra từ bước 1 ra cùng thư mục với các script vẽ đồ thị hoặc cấu hình đường dẫn `RESULT_DIR` trong script, sau đó chạy:
```bash
# Vẽ đồ thị đường cong BER vs SNR và giản đồ chòm sao dạng lưới chuẩn
python plot_results.py

# Vẽ kiểm chứng histogram nhiễu AWGN (Box-Muller) và giản đồ chòm sao vùng quyết định Voronoi
python plot_extra.py
```
* **Các ảnh kết quả sinh ra:**
  1. `ber_vs_snr.png`: So sánh BER mô phỏng Verilog RTL (tam giác đỏ) và lý thuyết (đường thẳng xanh).
  2. `constellation_grid.png`: Giản đồ chòm sao 16-QAM ở 4 mức SNR tiêu biểu.
  3. `noise_histogram.png`: So sánh residual noise thực tế với phân phối lý thuyết $\mathcal{N}(0, \sigma^2)$, có đi kèm kiểm định Kolmogorov-Smirnov (KS-test).
  4. `constellation_enhanced.png`: Giản đồ chòm sao nâng cao có nền phân chia 16 vùng quyết định Voronoi tô màu nhạt.

---

## 📊 Mô tả dữ liệu sử dụng

* **Dữ liệu ngõ vào (Input Data)**: Được sinh giả ngẫu nhiên liên tục trong Testbench thông qua hàm `$random` của Verilog, tạo ra chuỗi bit truyền $10^4$ bit trên mỗi điểm SNR.
* **Dữ liệu nhiễu (Noise Data)**: Sinh trực tiếp từ thuật toán Box-Muller trong testbench phần cứng theo phân phối Gaussian thực tế, biểu diễn dấu chấm tĩnh với $K = 2^{16}$.
* **Dữ liệu đầu ra (Output Data)**:
  * File `ber_vs_snr.csv`: Có cấu trúc `SNR_dB,NUM_BITS,Bit_Errors,BER`.
  * File `const_snrXXdB.csv`: Có cấu trúc `TxI_fixed,TxQ_fixed,RxI_fixed,RxQ_fixed` tương ứng với tọa độ phát lý tưởng và tọa độ nhận có nhiễu thực tế.
