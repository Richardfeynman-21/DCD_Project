#!/usr/bin/env python3
"""
Generate a visual correlation guide between Vivado Simulation Waveforms
and the actual Real Camera-Trap Video Frames.
"""

import os
import cv2
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as patches

def main():
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    frames_dir = os.path.join(root_dir, "test_videos", "frames_wildlife")
    output_dir = os.path.join(root_dir, "test_results")
    os.makedirs(output_dir, exist_ok=True)
    out_path = os.path.join(output_dir, "waveform_timeline_guide.png")

    frames_data = [
        {
            "idx": 0,
            "tag": "REAL_F00_REFERENCE",
            "time_start": 2.23,
            "time_end": 2.60,
            "motion_alert": 0,
            "animal_alert": 0,
            "verdict": "NEGATIVE: Reference Baseline",
            "bbox": None,
            "color": "#6c757d",
            "desc": "Initial background frame loaded into BRAM.\nNo motion difference exists yet."
        },
        {
            "idx": 1,
            "tag": "REAL_F01_ANIMAL_ENTER",
            "time_start": 2.60,
            "time_end": 2.97,
            "motion_alert": 1,
            "animal_alert": 1,
            "verdict": "POSITIVE: ANIMAL DETECTED",
            "bbox": [46, 45, 116, 66],
            "centroid": (77, 54),
            "pixels": 183,
            "color": "#28a745",
            "desc": "Wild animal enters from right.\nBBox: W=71, H=22, Centroid=(77,54)"
        },
        {
            "idx": 2,
            "tag": "REAL_F02_ANIMAL_ADVANCE",
            "time_start": 2.97,
            "time_end": 3.34,
            "motion_alert": 1,
            "animal_alert": 1,
            "verdict": "POSITIVE: ANIMAL DETECTED",
            "bbox": [47, 44, 115, 70],
            "centroid": (80, 54),
            "pixels": 236,
            "color": "#28a745",
            "desc": "Animal strides forward.\nBBox: W=69, H=27, Centroid=(80,54)"
        },
        {
            "idx": 3,
            "tag": "REAL_F03_SOBEL_FUSION",
            "time_start": 3.34,
            "time_end": 3.71,
            "motion_alert": 1,
            "animal_alert": 0,
            "verdict": "NEGATIVE: Edge Fusion Mode",
            "bbox": [2, 22, 113, 67],
            "centroid": (79, 54),
            "pixels": 273,
            "color": "#17a2b8",
            "desc": "Testing Fusion Mode 01 (Sobel AND Motion).\nInternal edge diagnostic verification."
        },
        {
            "idx": 4,
            "tag": "REAL_F04_EDGE_OR_MOTION",
            "time_start": 3.71,
            "time_end": 4.09,
            "motion_alert": 1,
            "animal_alert": 0,
            "verdict": "NEGATIVE: Background Edges Rej.",
            "bbox": [0, 0, 127, 71],
            "centroid": (63, 34),
            "pixels": 8874,
            "color": "#fd7e14",
            "desc": "Testing Fusion Mode 10 (Dual-Path OR).\nCorrectly rejected: Full static edges."
        },
        {
            "idx": 5,
            "tag": "REAL_F05_ANIMAL_LOCALIZE",
            "time_start": 4.09,
            "time_end": 4.46,
            "motion_alert": 1,
            "animal_alert": 1,
            "verdict": "POSITIVE: ANIMAL DETECTED",
            "bbox": [49, 11, 110, 67],
            "centroid": (74, 54),
            "pixels": 285,
            "color": "#28a745",
            "desc": "Animal body tracked across field.\nBBox: W=62, H=57, Centroid=(74,54)"
        }
    ]

    # Create figure with 2 sections: Frame cards on top, Waveform traces on bottom
    fig = plt.figure(figsize=(19, 11), dpi=150, facecolor='#0f141c')
    gs = fig.add_gridspec(2, 6, height_ratios=[1.7, 1.0], hspace=0.35, wspace=0.25,
                           left=0.04, right=0.96, top=0.92, bottom=0.08)

    # 1. Title Banner
    fig.text(0.5, 0.965, "FPGA WILD ANIMAL DETECTION — SIMULATION WAVEFORM & IMAGE CORRELATION GUIDE",
             fontsize=16, fontweight='bold', color='white', ha='center', va='center')
    fig.text(0.5, 0.94, "Correlates Vivado Behavioral Simulation Timestamps with Real Camera-Trap Video Frames (Artix-7 Basys 3)",
             fontsize=10.5, color='#a0aec0', ha='center', va='center')

    # Top row: Frame Cards
    for i, fdata in enumerate(frames_data):
        ax = fig.add_subplot(gs[0, i])
        ax.set_facecolor('#1a202c')

        # Load image
        img_file = os.path.join(frames_dir, f"frame_{fdata['idx']:03d}.png")
        if os.path.exists(img_file):
            img = cv2.imread(img_file)
            img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            
            # Overlay BBox if animal
            if fdata["bbox"] is not None:
                x1, y1, x2, y2 = fdata["bbox"]
                cv2.rectangle(img, (x1, y1), (x2, y2), (255, 40, 40), 1)
                cx, cy = fdata["centroid"]
                cv2.drawMarker(img, (cx, cy), (0, 255, 0), cv2.MARKER_CROSS, 6, 1)
            ax.imshow(img)
        else:
            ax.text(0.5, 0.5, f"Frame {fdata['idx']}\n(Not found)", ha='center', va='center', color='white')

        ax.set_xticks([])
        ax.set_yticks([])

        # Border color based on alert
        for spine in ax.spines.values():
            spine.set_edgecolor(fdata["color"])
            spine.set_linewidth(3.0 if fdata["animal_alert"] else 1.5)

        # Title and verdict above/below card
        badge_text = "POSITIVE ALERT" if fdata["animal_alert"] else "NEGATIVE"
        ax.set_title(f"Frame #{fdata['idx']}\n[{fdata['time_start']:.2f} ms – {fdata['time_end']:.2f} ms]",
                     color='white', fontsize=10, fontweight='bold', pad=8)

        # Bottom label box
        status_bg = '#14532d' if fdata["animal_alert"] else '#374151'
        status_border = fdata['color']
        ax.text(0.5, -0.15, badge_text, transform=ax.transAxes,
                ha='center', va='top', fontsize=9.5, fontweight='bold', color='white',
                bbox=dict(boxstyle='round,pad=0.4', facecolor=status_bg, edgecolor=status_border, linewidth=1.5))

        ax.text(0.5, -0.32, fdata['desc'], transform=ax.transAxes,
                ha='center', va='top', fontsize=7.5, color='#cbd5e1')

    # Bottom Row: Aligned Waveform Timing Diagram (spans all 6 columns)
    ax_wave = fig.add_subplot(gs[1, :])
    ax_wave.set_facecolor('#131a26')
    ax_wave.grid(True, which='both', color='#2d3748', linestyle='--', linewidth=0.7)

    # Time bounds (2.0 ms to 4.6 ms)
    t_min, t_max = 2.1, 4.6
    ax_wave.set_xlim(t_min, t_max)
    ax_wave.set_ylim(-0.5, 4.8)

    # Draw vertical separator bands for each frame
    for fdata in frames_data:
        t1, t2 = fdata["time_start"], fdata["time_end"]
        fill_color = '#1b3a27' if fdata["animal_alert"] else '#1e2430'
        ax_wave.axvspan(t1, t2, color=fill_color, alpha=0.35)
        ax_wave.axvline(t1, color='#4a5568', linestyle=':', linewidth=1.0)
        # Frame label at top
        ax_wave.text((t1 + t2)/2, 4.4, f"Frame {fdata['idx']}\n({t1:.2f}-{t2:.2f}ms)",
                     ha='center', va='center', color='#93c5fd', fontsize=8.5, fontweight='bold')

    ax_wave.axvline(frames_data[-1]["time_end"], color='#4a5568', linestyle=':', linewidth=1.0)

    # Digital Traces
    time_pts = np.linspace(t_min, t_max, 2500)

    # Trace 1: animal_alert
    y_animal = np.zeros_like(time_pts)
    for fdata in frames_data:
        if fdata["animal_alert"]:
            # Goes high after processing (~halfway through frame window)
            t_assert = fdata["time_start"] + 0.18
            t_deassert = fdata["time_end"]
            mask = (time_pts >= t_assert) & (time_pts <= t_deassert)
            y_animal[mask] = 1.0

    # Trace 2: motion_alert
    y_motion = np.zeros_like(time_pts)
    for fdata in frames_data:
        if fdata["motion_alert"]:
            t_assert = fdata["time_start"] + 0.18
            t_deassert = fdata["time_end"]
            mask = (time_pts >= t_assert) & (time_pts <= t_deassert)
            y_motion[mask] = 1.0

    # Trace 3: process_busy
    y_busy = np.zeros_like(time_pts)
    for fdata in frames_data:
        t_load = fdata["time_start"] + 0.18
        t_done = fdata["time_end"] - 0.01
        mask = (time_pts >= t_load) & (time_pts <= t_done)
        y_busy[mask] = 1.0

    # Trace 4: positive_pulse (highlights verified animal)
    y_pulse = np.zeros_like(time_pts)
    for fdata in frames_data:
        if fdata["animal_alert"]:
            t_assert = fdata["time_start"] + 0.18
            t_deassert = fdata["time_end"]
            mask = (time_pts >= t_assert) & (time_pts <= t_deassert)
            y_pulse[mask] = 1.0

    # Plot Traces
    ax_wave.step(time_pts, y_pulse * 0.7 + 3.0, color='#facc15', where='post', linewidth=2.0, label='tb_positive_alert')
    ax_wave.step(time_pts, y_animal * 0.7 + 2.0, color='#22c55e', where='post', linewidth=2.2, label='animal_alert')
    ax_wave.step(time_pts, y_motion * 0.7 + 1.0, color='#ef4444', where='post', linewidth=1.8, label='motion_alert')
    ax_wave.step(time_pts, y_busy * 0.7 + 0.0, color='#e2e8f0', where='post', linewidth=1.2, label='process_busy')

    # Y-axis labels
    ax_wave.set_yticks([0.35, 1.35, 2.35, 3.35])
    ax_wave.set_yticklabels([
        'process_busy',
        'motion_alert',
        'animal_alert  [TARGET]',
        'tb_positive_alert'
    ], color='white', fontsize=10, fontweight='bold')

    ax_wave.set_xlabel("Simulation Time (Milliseconds) — Zoom to [2.2 ms .. 4.5 ms] in Vivado Waveform",
                       color='white', fontsize=11, fontweight='bold', labelpad=8)
    ax_wave.tick_params(axis='x', colors='white', labelsize=10)

    # Highlight Positive Zones
    for fdata in frames_data:
        if fdata["animal_alert"]:
            t1, t2 = fdata["time_start"] + 0.18, fdata["time_end"]
            ax_wave.text((t1+t2)/2, 2.35, "POSITIVE ALERT = 1", ha='center', va='center',
                         color='#14532d', fontsize=8.5, fontweight='bold',
                         bbox=dict(boxstyle='square,pad=0.2', facecolor='#86efac', edgecolor='#22c55e'))

    # Legend
    legend = ax_wave.legend(loc='lower left', ncol=4, framealpha=0.8,
                            facecolor='#1e293b', edgecolor='#475569', labelcolor='white', fontsize=9)

    plt.savefig(out_path, dpi=150, facecolor=fig.get_facecolor(), bbox_inches='tight')
    plt.close()
    print(f"[SUCCESS] Waveform timeline guide generated at: {out_path}")

if __name__ == "__main__":
    main()
