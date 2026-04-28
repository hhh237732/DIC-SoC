#!/usr/bin/env python3
"""
calc_bw.py — DIC-SoC DMA带宽计算工具
用法: python3 calc_bw.py [logfile] [fclk_mhz]
"""

import sys
import re

def parse_log(logfile):
    beats = 0
    total_cycles = 0
    with open(logfile) as f:
        for line in f:
            m = re.search(r'DMA_BEATS\s*=\s*(\d+)', line)
            if m:
                beats = int(m.group(1))
            m = re.search(r'DMA_CYCLES\s*=\s*(\d+)', line)
            if m:
                total_cycles = int(m.group(1))
    return beats, total_cycles

def main():
    logfile  = sys.argv[1] if len(sys.argv) > 1 else "sim.log"
    fclk_mhz = float(sys.argv[2]) if len(sys.argv) > 2 else 100.0

    beats, total_cycles = parse_log(logfile)

    if total_cycles == 0:
        print(f"[警告] 未在 {logfile} 中找到 DMA_CYCLES，使用默认值 1024")
        total_cycles = 1024
    if beats == 0:
        print(f"[警告] 未在 {logfile} 中找到 DMA_BEATS，使用默认值 256")
        beats = 256

    # 实际带宽：每beat传输4字节
    bw_actual_mbps = beats * 4 / total_cycles * fclk_mhz  # MB/s

    # 理论峰值：AXI 32-bit数据总线，每周期4字节
    bw_peak_mbps = fclk_mhz * 4  # MB/s

    efficiency = bw_actual_mbps / bw_peak_mbps * 100

    print("=" * 50)
    print(f"  DIC-SoC DMA 带宽分析报告")
    print("=" * 50)
    print(f"  仿真日志      : {logfile}")
    print(f"  时钟频率      : {fclk_mhz:.1f} MHz")
    print(f"  DMA beats     : {beats}")
    print(f"  总周期数      : {total_cycles}")
    print(f"  实际带宽      : {bw_actual_mbps:.2f} MB/s")
    print(f"  理论峰值带宽  : {bw_peak_mbps:.2f} MB/s")
    print(f"  总线利用率    : {efficiency:.1f}%")
    print("=" * 50)

if __name__ == "__main__":
    main()
