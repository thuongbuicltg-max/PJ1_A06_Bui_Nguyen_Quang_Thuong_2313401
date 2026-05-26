"""
plot_results.py
Vẽ 2 loại đồ thị từ kết quả mô phỏng 16-QAM:
  1. BER vs SNR (simulation + lý thuyết)
  2. Constellation diagram tại các SNR tiêu biểu
Chạy: python plot_results.py
Output: ber_vs_snr.png, constellation_grid.png
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from scipy.special import erfc
import os

# =========================================================
# CẤU HÌNH — chỉnh đường dẫn nếu cần
# =========================================================
RESULT_DIR = "."           # thư mục chứa các file CSV
OUT_DIR    = "."           # thư mục lưu ảnh PNG
FRAC_BITS  = 16            # K = 2^16 (fixed-point scale)
K_SCALE    = 1 << FRAC_BITS  # = 65536

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 11,
    "axes.grid": True,
    "grid.alpha": 0.3,
})

# =========================================================
# 1. BER vs SNR
# =========================================================
def ber_theory_16qam(snr_db):
    """BER lý thuyết 16-QAM AWGN (Gray coded)"""
    snr_lin = 10 ** (snr_db / 10.0)
    # Pe = (3/2) * erfc(sqrt(Es/(10*N0)))
    # Với Gray: BER ≈ (3/4) * erfc(sqrt(0.1 * Eb/N0 * 4))
    # Công thức chuẩn cho 16-QAM:
    # Ps = (3/2)*erfc(sqrt(snr_lin/10))
    # BER ≈ Ps / log2(16) * (số bit trung bình sai)
    # Xấp xỉ đơn giản nhất (hay dùng trong báo cáo):
    return 0.75 * erfc(np.sqrt(snr_lin / 10))

def plot_ber():
    csv_path = os.path.join(RESULT_DIR, "ber_vs_snr.csv")
    df = pd.read_csv(csv_path)

    snr_db  = df["SNR_dB"].values
    ber_sim = df["BER"].values

    snr_th  = np.linspace(0, 22, 200)
    ber_th  = ber_theory_16qam(snr_th)

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.semilogy(snr_db, ber_sim, 'r^--', linewidth=1.5,
                markersize=7, label="Mô phỏng (Simulation)")
    ax.semilogy(snr_th, ber_th,  'b-',  linewidth=2,
                label="Lý thuyết (Theory)")

    ax.set_xlabel("Es/N0 (dB)")
    ax.set_ylabel("BER")
    ax.set_title("BER vs SNR — 16-QAM AWGN (10⁴ bits / SNR point)")
    ax.legend(fontsize=11)
    ax.set_xlim([0, 22])
    ax.set_ylim([1e-5, 1])
    ax.grid(True, which='both', alpha=0.4)

    out = os.path.join(OUT_DIR, "ber_vs_snr.png")
    fig.tight_layout()
    fig.savefig(out, dpi=150, bbox_inches='tight')
    print(f"Saved: {out}")
    plt.close(fig)

# =========================================================
# 2. Constellation Diagrams
# =========================================================
SNR_SHOW = [0, 8, 16, 20]   # dB — chọn 4 mức tiêu biểu

def plot_constellation():
    fig = plt.figure(figsize=(12, 10))
    gs  = gridspec.GridSpec(2, 2, hspace=0.38, wspace=0.35)

    for idx, snr in enumerate(SNR_SHOW):
        csv_path = os.path.join(RESULT_DIR, f"const_snr{snr}dB.csv")
        if not os.path.exists(csv_path):
            print(f"  [WARNING] {csv_path} not found, skip.")
            continue

        df = pd.read_csv(csv_path)
        # Chuyển từ fixed-point về normalized
        rx_i = df["RxI_fixed"].values / K_SCALE
        rx_q = df["RxQ_fixed"].values / K_SCALE

        ax = fig.add_subplot(gs[idx // 2, idx % 2])
        ax.scatter(rx_i, rx_q, s=4, alpha=0.35, color='steelblue')

        # Vẽ các điểm lý thuyết
        ref = [-3, -1, 1, 3]
        for xi in ref:
            for yi in ref:
                ax.plot(xi, yi, 'r+', markersize=10, markeredgewidth=1.5)

        ax.set_title(f"SNR = {snr} dB")
        ax.set_xlabel("I (normalized)")
        ax.set_ylabel("Q (normalized)")
        ax.set_xlim([-6, 6])
        ax.set_ylim([-6, 6])
        ax.axhline(0, color='gray', linewidth=0.5)
        ax.axvline(0, color='gray', linewidth=0.5)
        # Vẽ decision thresholds
        for th in [-2, 2]:
            ax.axhline(th, color='orange', linewidth=0.8, linestyle='--', alpha=0.6)
            ax.axvline(th, color='orange', linewidth=0.8, linestyle='--', alpha=0.6)

    fig.suptitle("16-QAM Constellation Diagram tại các mức SNR", fontsize=13, fontweight='bold')
    out = os.path.join(OUT_DIR, "constellation_grid.png")
    fig.savefig(out, dpi=150, bbox_inches='tight')
    print(f"Saved: {out}")
    plt.close(fig)

# =========================================================
# MAIN
# =========================================================
if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    print("=== Plotting BER vs SNR ===")
    plot_ber()
    print("=== Plotting Constellation ===")
    plot_constellation()
    print("Done!")
