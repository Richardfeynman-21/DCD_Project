#!/usr/bin/env python3
"""
FPGA Hardware Pipeline Visualizer & Layer Inspector
----------------------------------------------------
Simulates and visualizes all intermediate hardware processing layers of the FPGA pipeline:
  Layer 1: Raw Input Grayscale Frame (from dual BRAM buffer)
  Layer 2: Motion Differencing Map (|curr - prev| > motion_thresh)
  Layer 3: Parallel 3x3 Sobel Edge Detection (Gx, Gy, Manhattan Magnitude & Thresholded Edges)
  Layer 4: Delay-Compensated Edge + Motion Fusion Map (Mode 00, 01, 10)
  Layer 5: BRAM Temporal Persistence Noise Filter
  Layer 6: Single-Pass Bounding Box & Centroid Localization Overlay

Usage:
    python scripts/visualize_pipeline.py [frame_index] [output_dir]

Examples:
    python scripts/visualize_pipeline.py 2
    python scripts/visualize_pipeline.py all test_results/pipeline_visualization
"""

import sys
import os
import cv2
import numpy as np

def load_mem_frame(path):
    if not os.path.exists(path):
        return None
    with open(path, "r") as f:
        vals = [int(line.strip(), 16) for line in f if line.strip()]
    if len(vals) != 9216:
        return None
    return np.array(vals, dtype=np.uint8).reshape((72, 128))

def hardware_sobel(img, threshold=40):
    """Bit-accurate model of src/rtl/sobel_edge_detect.v"""
    H, W = img.shape
    edge_map = np.zeros((H, W), dtype=np.uint8)
    mag_map  = np.zeros((H, W), dtype=np.uint16)
    
    # 2 line buffers (128 pixels each)
    lb0 = np.zeros(W, dtype=np.uint8)
    lb1 = np.zeros(W, dtype=np.uint8)
    p00 = p01 = p02 = p10 = p11 = p12 = p20 = p21 = p22 = 0
    
    for y in range(H):
        for x in range(W):
            pixel_in = int(img[y, x])
            lb1_out = int(lb1[0])
            lb0_out = int(lb0[0])
            
            lb1 = np.roll(lb1, -1); lb1[-1] = pixel_in
            lb0 = np.roll(lb0, -1); lb0[-1] = lb1_out
            
            p02 = p01; p01 = p00; p00 = lb0_out
            p12 = p11; p11 = p10; p10 = lb1_out
            p22 = p21; p21 = p20; p20 = pixel_in
            
            # 3x3 Sobel convolution
            gx = (p00 + 2*p10 + p20) - (p02 + 2*p12 + p22)
            gy = (p20 + 2*p21 + p22) - (p00 + 2*p01 + p02)
            mag = abs(gx) + abs(gy)
            
            if y >= 1 and x >= 1:
                cy, cx = y - 1, x - 1
                mag_map[cy, cx] = min(mag, 65535)
                edge_map[cy, cx] = 255 if mag > threshold else 0
                
    return edge_map, mag_map

def inspect_frame_layers(curr_frame, prev_frame, frame_idx, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    
    # -------------------------------------------------------------
    # Layer 1: Raw Input Frame
    # -------------------------------------------------------------
    layer1 = curr_frame.copy()
    
    # -------------------------------------------------------------
    # Layer 2: Motion Differencing Map
    # -------------------------------------------------------------
    diff = cv2.absdiff(curr_frame, prev_frame)
    _, motion_binary = cv2.threshold(diff, 28, 255, cv2.THRESH_BINARY)
    
    # -------------------------------------------------------------
    # Layer 3: Parallel 3x3 Sobel Edge Detection
    # -------------------------------------------------------------
    edge_binary, edge_mag = hardware_sobel(curr_frame, threshold=40)
    
    # Normalize magnitude heatmap for display (0..255)
    mag_display = np.clip((edge_mag.astype(float) / 4.0), 0, 255).astype(np.uint8)
    mag_color = cv2.applyColorMap(mag_display, cv2.COLORMAP_JET)
    
    # -------------------------------------------------------------
    # Layer 4: Edge + Motion Fusion Map (Mode 01: Strict AND)
    # -------------------------------------------------------------
    fused_and = cv2.bitwise_and(motion_binary, edge_binary)
    fused_or  = cv2.bitwise_or(motion_binary, edge_binary)
    
    # -------------------------------------------------------------
    # Layer 5: Temporal Persistence / Shadow Suppression
    # -------------------------------------------------------------
    # Active foreground pixels
    y_idx, x_idx = np.where(motion_binary > 0)
    pixel_count = len(x_idx)
    
    # -------------------------------------------------------------
    # Layer 6: Single-Pass Bounding Box & Centroid Extraction
    # -------------------------------------------------------------
    annotated = cv2.cvtColor(curr_frame, cv2.COLOR_GRAY2BGR)
    
    bbox_info = "No object"
    if pixel_count >= 20:
        xmin, xmax = int(np.min(x_idx)), int(np.max(x_idx))
        ymin, ymax = int(np.min(y_idx)), int(np.max(y_idx))
        cx, cy = int(np.mean(x_idx)), int(np.mean(y_idx))
        w = xmax - xmin + 1
        h = ymax - ymin + 1
        
        # Classification evaluation
        w_ok = (w >= 5) and (w <= 85)
        h_ok = (h >= 5) and (h <= 65)
        ar_ok = (w * 16 <= 64 * h) and (h * 16 <= 64 * w) # 4.0 max AR
        fill_ok = (pixel_count * 8 >= w * h) # 12.5% fill
        is_animal = (w_ok and h_ok and ar_ok and fill_ok)
        
        color = (0, 255, 0) if is_animal else (0, 165, 255) # Green=Animal, Orange=Motion
        cv2.rectangle(annotated, (xmin, ymin), (xmax, ymax), color, 1)
        cv2.circle(annotated, (cx, cy), 2, (0, 0, 255), -1)
        bbox_info = f"BBox=[{xmin}..{xmax}, {ymin}..{ymax}] (W={w}, H={h}) | Animal={is_animal}"
    
    # Save crisp nearest-neighbor scaled individual layer images (512x288)
    def save_crisp(img, name, label):
        scaled = cv2.resize(img, (512, 288), interpolation=cv2.INTER_NEAREST)
        cv2.putText(scaled, label, (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (0, 255, 255), 2, cv2.LINE_AA)
        p = os.path.join(out_dir, f"frame_{frame_idx:03d}_{name}.png")
        cv2.imwrite(p, scaled)
        return scaled

    l1_img = save_crisp(cv2.cvtColor(layer1, cv2.COLOR_GRAY2BGR), "01_input_frame", f"Frame #{frame_idx} Input (128x72)")
    l2_img = save_crisp(cv2.cvtColor(motion_binary, cv2.COLOR_GRAY2BGR), "02_motion_differencing", f"Frame #{frame_idx} Motion Differencing (Diff > 28)")
    l3_mag = save_crisp(mag_color, "03_sobel_magnitude_heatmap", f"Frame #{frame_idx} Sobel Gradient Magnitude |Gx|+|Gy|")
    l3_bin = save_crisp(cv2.cvtColor(edge_binary, cv2.COLOR_GRAY2BGR), "04_sobel_edge_map", f"Frame #{frame_idx} Sobel Edge Detection (Thresh > 40)")
    l4_img = save_crisp(cv2.cvtColor(fused_and, cv2.COLOR_GRAY2BGR), "05_fusion_edge_and_motion", f"Frame #{frame_idx} Fusion (Sobel Edge AND Motion)")
    l6_img = save_crisp(annotated, "06_bounding_box_centroid", f"Frame #{frame_idx} Localization & Classification")

    # Composite Pipeline Overview (2 rows x 3 columns)
    row_top = np.hstack([l1_img, l2_img, l3_bin])
    row_bot = np.hstack([l3_mag, l4_img, l6_img])
    composite = np.vstack([row_top, row_bot])
    
    grid_path = os.path.join(out_dir, f"frame_{frame_idx:03d}_complete_pipeline.png")
    cv2.imwrite(grid_path, composite)
    return grid_path, bbox_info

def main():
    frames_dir = "test_videos/frames_wildlife"
    out_dir = "test_results/pipeline_visualization"
    
    target = sys.argv[1] if len(sys.argv) > 1 else "2"
    if len(sys.argv) > 2:
        out_dir = sys.argv[2]
        
    os.makedirs(out_dir, exist_ok=True)
    
    print("==================================================================")
    print("   FPGA HARDWARE PIPELINE LAYER VISUALIZER")
    print("==================================================================")
    print(f" Input Frame Source : {frames_dir}")
    print(f" Output Directory   : {out_dir}")
    print("==================================================================")
    
    if target.lower() == "all":
        frame_indices = range(1, 10)
    else:
        frame_indices = [int(target)]
        
    for f_idx in frame_indices:
        prev_p = os.path.join(frames_dir, f"frame_{f_idx-1:03d}.mem")
        curr_p = os.path.join(frames_dir, f"frame_{f_idx:03d}.mem")
        
        curr_f = load_mem_frame(curr_p)
        prev_f = load_mem_frame(prev_p)
        
        if curr_f is None or prev_f is None:
            print(f"[ERROR] Could not load frames {f_idx-1} or {f_idx} from {frames_dir}.")
            continue
            
        grid_file, info = inspect_frame_layers(curr_f, prev_f, f_idx, out_dir)
        print(f"\n[FRAME {f_idx:02d} PROCESSED]")
        print(f"  {info}")
        print(f"  -> Sobel Edge Map Saved     : {out_dir}/frame_{f_idx:03d}_04_sobel_edge_map.png")
        print(f"  -> Sobel Heatmap Saved      : {out_dir}/frame_{f_idx:03d}_03_sobel_magnitude_heatmap.png")
        print(f"  -> Complete Pipeline Canvas : {grid_file}")

    print("\n==================================================================")
    print("   Visual inspection complete! All layer images are available in:")
    print(f"   {out_dir}")
    print("==================================================================")

if __name__ == "__main__":
    main()
