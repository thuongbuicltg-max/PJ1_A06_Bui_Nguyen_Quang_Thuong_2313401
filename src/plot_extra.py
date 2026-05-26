"""
plot_extra.py
=============
Vẽ hai đồ thị bổ sung cho báo cáo 16-QAM:

  [1] Histogram phân phối nhiễu AWGN tại 4 mức SNR
      Mục đích: kiểm chứng Box-Muller sinh đúng N(0, sigma^2)
      Output : noise_histogram.png

  [2] Giản đồ chòm sao CẢI TIẾN:
      - Nền Voronoi (vùng quyết định) tô màu nhạt phân biệt 16 ô
      - Điểm nhận (scatter, màu xanh)
      - Điểm lý tưởng (hình sao đỏ lớn)
      - Ngưỡng quyết định (đường cam đậm)
      Output : constellation_enhanced.png

Chạy: python plot_extra.py
Yêu cầu: numpy, scipy, matplotlib, pandas (pip install nếu chưa có)
"""

import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.colors import ListedColormap
from scipy.special import erfc
from scipy.stats import norm

# =========================================================
# CẤU HÌNH — chỉnh đường dẫn nếu file CSV ở thư mục khác
# =========================================================
RESULT_DIR = "."         # thư mục chứa CSV
OUT_DIR    = "."         # thư mục lưu PNG
FRAC_BITS  = 16
K_SCALE    = 1 << FRAC_BITS  # 65536

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size":   11,
})

# =====================================================================
# [1]  HISTOGRAM PHÂN PHỐI NHIỄU
#      Từ file const_snrXXdB.csv, trừ điểm lý tưởng gần nhất để
#      lấy residual noise, rồi so sánh với đường Gaussian lý thuyết
# =====================================================================

def nearest_ideal(x, levels=np.array([-3, -1, 1, 3])):
    """Trả về điểm lý tưởng gần nhất với x (normalized)."""
    idx = np.argmin(np.abs(levels - x))
    return levels[idx]

def plot_noise_histogram():
    SNR_HIST = [0, 8, 16, 20]  # 4 mức SNR để vẽ histogram

    fig, axes = plt.subplots(2, 2, figsize=(12, 8))
    axes = axes.flatten()

    for idx, snr in enumerate(SNR_HIST):
        csv_path = os.path.join(RESULT_DIR, f"const_snr{snr}dB.csv")
        if not os.path.exists(csv_path):
            print(f"  [SKIP] {csv_path} not found")
            continue

        df = pd.read_csv(csv_path)

        # --- Tính TRUE residual noise = Rx - Tx (không phải nearest_ideal) ---
        tx_i = df["TxI_fixed"].values / K_SCALE
        tx_q = df["TxQ_fixed"].values / K_SCALE
        rx_i = df["RxI_fixed"].values / K_SCALE
        rx_q = df["RxQ_fixed"].values / K_SCALE

        noise_i   = rx_i - tx_i      # true noise per dimension I
        noise_q   = rx_q - tx_q      # true noise per dimension Q
        noise_all = np.concatenate([noise_i, noise_q])  # gộp 2 trục

        # Sigma lý thuyết per-dimension
        snr_lin  = 10 ** (snr / 10.0)
        sigma_th = np.sqrt(5.0 / snr_lin)

        ax = axes[idx]

        # Histogram chuẩn hóa
        n, bins, _ = ax.hist(noise_all, bins=60, density=True,
                              color='steelblue', alpha=0.65,
                              label='Nhiễu mô phỏng')

        # Đường Gaussian lý thuyết N(0, sigma^2)
        x_line = np.linspace(bins[0], bins[-1], 300)
        y_line = norm.pdf(x_line, loc=0, scale=sigma_th)
        ax.plot(x_line, y_line, 'r-', linewidth=2,
                label=f'Lý thuyết $\\mathcal{{N}}(0,\\,{sigma_th:.3f}^2)$')

        ax.set_title(f"SNR = {snr} dB  ($\\sigma_{{th}}={sigma_th:.3f}$)")
        ax.set_xlabel("Biên độ nhiễu (chuẩn hóa)")
        ax.set_ylabel("Mật độ xác suất")
        ax.legend(fontsize=9)
        ax.grid(True, alpha=0.3)

        # KS-test kiểm tra phân phối
        from scipy.stats import kstest
        stat, pval = kstest(noise_all, 'norm', args=(0, sigma_th))
        color_ks = 'darkgreen' if pval > 0.05 else 'darkred'
        result   = '✓ PASS' if pval > 0.05 else '✗ FAIL'
        ax.text(0.97, 0.95,
                f"KS p-val = {pval:.3f}  {result}",
                transform=ax.transAxes, ha='right', va='top',
                fontsize=9, color=color_ks)

    fig.suptitle("Kiểm chứng phân phối nhiễu AWGN (Box-Muller)\n"
                 "16-QAM, $N=10^4$ mẫu / điểm SNR  —  Residual = Rx − Tx",
                 fontsize=13, fontweight='bold')
    fig.tight_layout(rect=[0, 0, 1, 0.93])

    out = os.path.join(OUT_DIR, "noise_histogram.png")
    fig.savefig(out, dpi=150, bbox_inches='tight')
    print(f"Saved: {out}")
    plt.close(fig)


# =====================================================================
# [2]  CONSTELLATION DIAGRAM CẢI TIẾN
#      Nền Voronoi 16 ô màu nhạt + điểm nhận + điểm lý tưởng (sao đỏ)
# =====================================================================

# 16 màu nhạt phân biệt cho 16 vùng Voronoi
VORONOI_COLORS = [
    "#fff0f0", "#ffe8d0", "#fffacc", "#e8ffe8",  # hàng Q=+3
    "#e0f0ff", "#f0e8ff", "#ffeaf5", "#e8fff5",  # hàng Q=+1
    "#fff5e8", "#eaffea", "#e0eeff", "#ffe0e0",  # hàng Q=-1
    "#fdf5ff", "#fffde0", "#e0fff5", "#f5e0ff",  # hàng Q=-3
]

def draw_voronoi_background(ax):
    """Tô nền 16 ô Voronoi bằng màu nhạt phân biệt."""
    # Ranh giới x: -inf, -2, 0, +2, +inf
    # Ranh giới y: +inf, +2, 0, -2, -inf  (Q giảm từ trên xuống)
    x_bounds = [-6, -2, 0, 2, 6]
    y_bounds = [ 6,  2, 0, -2, -6]

    color_idx = 0
    for row in range(4):          # Q từ cao xuống thấp
        for col in range(4):      # I từ trái sang phải
            x0, x1 = x_bounds[col],   x_bounds[col+1]
            y0, y1 = y_bounds[row+1], y_bounds[row]   # y0 < y1
            rect = mpatches.FancyArrowPatch(
                (x0, y0), (x1, y1), arrowstyle='simple',
                mutation_scale=0)
            ax.add_patch(plt.Rectangle(
                (x0, y0), x1-x0, y1-y0,
                facecolor=VORONOI_COLORS[color_idx],
                edgecolor='none', zorder=0))
            color_idx += 1

def plot_constellation_enhanced():
    SNR_SHOW = [0, 8, 16, 20]

    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    axes = axes.flatten()

    for idx, snr in enumerate(SNR_SHOW):
        csv_path = os.path.join(RESULT_DIR, f"const_snr{snr}dB.csv")
        if not os.path.exists(csv_path):
            print(f"  [SKIP] {csv_path} not found")
            continue

        df   = pd.read_csv(csv_path)
        rx_i = df["RxI_fixed"].values / K_SCALE
        rx_q = df["RxQ_fixed"].values / K_SCALE
        tx_i = df["TxI_fixed"].values / K_SCALE
        tx_q = df["TxQ_fixed"].values / K_SCALE

        ax = axes[idx]

        # 1) Vẽ nền Voronoi
        draw_voronoi_background(ax)

        # 2) Vẽ điểm nhận
        ax.scatter(rx_i, rx_q, s=5, alpha=0.40, color='steelblue',
                   zorder=2, label='Điểm nhận')

        # 3) Vẽ điểm lý tưởng (hình sao, lớn, rõ)
        ideal = [-3, -1, 1, 3]
        for xi in ideal:
            for yi in ideal:
                ax.plot(xi, yi, 'r*', markersize=14, zorder=4,
                        markeredgecolor='darkred', markeredgewidth=0.5)

        # 4) Ngưỡng quyết định (đường cam đậm)
        for th in [-2, 2]:
            ax.axhline(th, color='darkorange', linewidth=1.5,
                       linestyle='--', zorder=3, alpha=0.9)
            ax.axvline(th, color='darkorange', linewidth=1.5,
                       linestyle='--', zorder=3, alpha=0.9)

        # 5) Trục tham chiếu nhẹ
        ax.axhline(0, color='gray', linewidth=0.6, zorder=1)
        ax.axvline(0, color='gray', linewidth=0.6, zorder=1)

        # 6) Tính BER ước lượng từ đồ thị
        snr_lin  = 10 ** (snr / 10.0)
        ber_th   = 0.375 * erfc(np.sqrt(snr_lin / 10.0))

        ax.set_title(f"SNR = {snr} dB    "
                     f"(BER$_{{th}}$ = {ber_th:.2e})",
                     fontsize=11)
        ax.set_xlabel("I (chuẩn hóa)")
        ax.set_ylabel("Q (chuẩn hóa)")
        ax.set_xlim([-5.5, 5.5])
        ax.set_ylim([-5.5, 5.5])
        ax.set_aspect('equal')
        ax.grid(True, alpha=0.25, zorder=1)

        # Chú thích legend chỉ cho ô đầu
        if idx == 0:
            star_patch = plt.Line2D([0], [0], marker='*', color='w',
                markerfacecolor='red', markersize=12, label='Điểm lý tưởng')
            dot_patch  = plt.Line2D([0], [0], marker='o', color='w',
                markerfacecolor='steelblue', markersize=8, label='Điểm nhận')
            th_line    = plt.Line2D([0], [0], color='darkorange',
                linestyle='--', linewidth=1.5, label='Ngưỡng quyết định')
            ax.legend(handles=[star_patch, dot_patch, th_line],
                      fontsize=8, loc='upper right')

    fig.suptitle("Giản đồ chòm sao 16-QAM với vùng quyết định Voronoi\n"
                 "($10^4$ ký tự / điểm SNR)",
                 fontsize=13, fontweight='bold')
    fig.tight_layout(rect=[0, 0, 1, 0.93])

    out = os.path.join(OUT_DIR, "constellation_enhanced.png")
    fig.savefig(out, dpi=150, bbox_inches='tight')
    print(f"Saved: {out}")
    plt.close(fig)


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)

    print("=== [1] Plotting AWGN Noise Histogram ===")
    plot_noise_histogram()

    print("=== [2] Plotting Enhanced Constellation ===")
    plot_constellation_enhanced()

    print("=== Completed! ===")
    print(f"  Output: noise_histogram.png")
    print(f"  Output: constellation_enhanced.png")
