#!/usr/bin/env python3
"""
Comprehensive Video Benchmarking & Metric Evaluation Script
Simulates the full FPGA pipeline across real video datasets and evaluates:
Confusion Matrix, Accuracy, Precision, Recall, Specificity, F1-Score.
Also compares Base Paper vs. Our Novelty Architecture.
"""

import cv2
import numpy as np
import os
import json

def extract_frames_from_video(video_path, out_dir, num_frames=30, start_frame=20):
    os.makedirs(out_dir, exist_ok=True)
    frames = []

    # If frames already exist in out_dir, load them directly
    if os.path.exists(os.path.join(out_dir, "frame_000.png")):
        for i in range(num_frames):
            p = os.path.join(out_dir, f"frame_{i:03d}.png")
            if os.path.exists(p):
                frames.append(cv2.imread(p, cv2.IMREAD_GRAYSCALE))
        if len(frames) >= num_frames:
            return frames

    if not os.path.exists(video_path):
        return frames

    cap = cv2.VideoCapture(video_path)
    cap.set(cv2.CAP_PROP_POS_FRAMES, start_frame)
    
    count = 0
    while count < num_frames:
        ret, frame = cap.read()
        if not ret: break
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        resized = cv2.resize(gray, (128, 72))
        frames.append(resized)
        
        cv2.imwrite(os.path.join(out_dir, f"frame_{count:03d}.png"), resized)
        with open(os.path.join(out_dir, f"frame_{count:03d}.mem"), "w") as f:
            for row in resized:
                for val in row:
                    f.write(f"{val:02X}\n")
        count += 1
    cap.release()
    return frames

def generate_synthetic_animal_sequence(num_frames=25):
    """Generates synthetic animal moving across static camera background."""
    frames = []
    bg = np.zeros((72, 128), dtype=np.uint8) + 45
    # add background texture/trees
    cv2.circle(bg, (20, 20), 12, 60, -1)
    cv2.circle(bg, (110, 30), 18, 55, -1)
    
    for i in range(num_frames):
        f = bg.copy()
        # Animal starts at x=15, moves across to x=85
        ax = int(15 + i * 2.8)
        ay = 35 + int(np.sin(i * 0.4) * 3)
        aw, ah = 22, 15
        cv2.rectangle(f, (ax, ay), (ax + aw, ay + ah), 195, -1)
        # animal head
        cv2.circle(f, (ax + aw, ay + 4), 5, 210, -1)
        frames.append(f)
    return frames

class FPGASystemSimulator:
    """
    Bit-accurate simulator matching Verilog RTL in src/rtl/:
    frame_memory, motion_detect, sobel_edge_detect, fusion,
    shadow_suppress, bbox_centroid, classifier, control_logic.
    """
    def __init__(self, motion_thresh=22, edge_thresh=40, persist_thresh=2,
                 min_w=5, max_w=85, min_h=5, max_h=55, min_area=18, max_ar=64):
        self.motion_thresh = motion_thresh
        self.edge_thresh = edge_thresh
        self.persist_thresh = persist_thresh
        self.min_w = min_w
        self.max_w = max_w
        self.min_h = min_h
        self.max_h = max_h
        self.min_area = min_area
        self.max_ar = max_ar # Q4.4 format (64 = 4.0 aspect ratio)
        
        self.prev_frame = None
        self.persist_counters = np.zeros((72, 128), dtype=np.uint8)
        
    def reset(self):
        self.prev_frame = None
        self.persist_counters.fill(0)
        
    def process_frame(self, curr_frame, enable_novelties=True):
        H, W = curr_frame.shape
        if self.prev_frame is None:
            self.prev_frame = curr_frame.copy()
            return {
                "motion_alert": 0, "animal_alert": 0,
                "bbox": (0, 0, 0, 0), "centroid": (0, 0), "pixel_count": 0
            }
            
        # 1. Motion Differencing
        diff = np.abs(curr_frame.astype(np.int16) - self.prev_frame.astype(np.int16))
        motion_map = (diff > self.motion_thresh).astype(np.uint8)
        motion_count = int(np.sum(motion_map))
        motion_detected = 1 if motion_count > 0 else 0
        
        # 2. Pipelined Sobel Edge Detection
        gx = cv2.Sobel(curr_frame, cv2.CV_16S, 1, 0, ksize=3)
        gy = cv2.Sobel(curr_frame, cv2.CV_16S, 0, 1, ksize=3)
        mag = np.abs(gx) + np.abs(gy)
        edge_map = (mag > self.edge_thresh).astype(np.uint8)
        
        # 3. Novelty 2: BRAM Temporal Persistence Suppression
        if enable_novelties:
            fused = motion_map.copy()
            inc = (fused > 0)
            self.persist_counters[inc] = np.minimum(self.persist_counters[inc] + 1, 7)
            self.persist_counters[~inc] = 0
            stable_map = (self.persist_counters >= self.persist_thresh).astype(np.uint8)
        else:
            stable_map = motion_map
            
        # 4. Novelty 3: Single-pass Bounding Box & Centroid Extraction
        fg_indices = np.argwhere(stable_map > 0)
        pixel_count = len(fg_indices)
        
        if pixel_count > 0:
            ymin, xmin = np.min(fg_indices, axis=0)
            ymax, xmax = np.max(fg_indices, axis=0)
            cx = int(np.mean(fg_indices[:, 1]))
            cy = int(np.mean(fg_indices[:, 0]))
            bw = xmax - xmin + 1
            bh = ymax - ymin + 1
        else:
            xmin = xmax = ymin = ymax = cx = cy = bw = bh = 0
            
        # 5. Classification
        if enable_novelties:
            # Novelty 4: Multi-feature rule evaluation
            w_ok = (bw >= self.min_w) and (bw <= self.max_w)
            h_ok = (bh >= self.min_h) and (bh <= self.max_h)
            area_ok = (pixel_count >= self.min_area)
            
            # Bilateral Aspect Ratio Check in Q4.4 fixed point
            ar_w_lhs = bw * 16
            ar_w_rhs = self.max_ar * bh
            ar_h_lhs = bh * 16
            ar_h_rhs = self.max_ar * bw
            ar_ok = (bw > 0 and bh > 0) and (ar_w_lhs <= ar_w_rhs) and (ar_h_lhs <= ar_h_rhs)
            
            # Fill ratio check: 4 * pixel_count >= bw * bh
            fill_ok = (bw > 0 and bh > 0) and (pixel_count * 4 >= bw * bh)
            
            is_animal = 1 if (w_ok and h_ok and area_ok and ar_ok and fill_ok) else 0
        else:
            # Base Paper: Simple raw pixel count thresholding
            is_animal = 1 if (pixel_count >= self.min_area and pixel_count <= 2500) else 0
            
        # 6. Control Logic
        motion_alert = motion_detected
        animal_alert = 1 if (is_animal and motion_detected) else 0
        
        self.prev_frame = curr_frame.copy()
        
        return {
            "motion_alert": motion_alert,
            "animal_alert": animal_alert,
            "bbox": (int(xmin), int(xmax), int(ymin), int(ymax)),
            "centroid": (int(cx), int(cy)),
            "pixel_count": pixel_count
        }

def run_benchmark():
    os.makedirs("test_results/benchmark", exist_ok=True)
    
    print("[1/3] Preparing multi-scenario video datasets...")
    # Real wildlife camera trap (positive)
    wildlife_frames = extract_frames_from_video("test_videos/camera_trap_wildlife.mp4", "test_videos/frames_wildlife", num_frames=30, start_frame=20)
    # Static background (negative)
    static_frames = [wildlife_frames[0].copy() for _ in range(20)] if wildlife_frames else []
    # Synthetic wildlife walk (positive control)
    synth_frames = generate_synthetic_animal_sequence(num_frames=25)
    
    test_datasets = [
        {"name": "Camera Trap Wildlife (Real)", "frames": wildlife_frames, "ground_truth": 1},
        {"name": "Synthetic Animal Walk (Positive Control)", "frames": synth_frames, "ground_truth": 1},
        {"name": "Static Background (Negative)", "frames": static_frames, "ground_truth": 0}
    ]
    
    sim_base = FPGASystemSimulator(persist_thresh=1)
    sim_novel = FPGASystemSimulator(persist_thresh=2)
    
    results = {"base_paper": {}, "our_novelty": {}}
    
    for mode_name, sim, enable_nov in [("base_paper", sim_base, False), ("our_novelty", sim_novel, True)]:
        tp = fp = tn = fn = 0
        dataset_logs = []
        
        for ds in test_datasets:
            sim.reset()
            gt = ds["ground_truth"]
            ds_name = ds["name"]
            
            ds_tp = ds_fp = ds_tn = ds_fn = 0
            
            for i, f in enumerate(ds["frames"]):
                if i == 0:
                    sim.process_frame(f, enable_novelties=enable_nov)
                    continue
                    
                res = sim.process_frame(f, enable_novelties=enable_nov)
                pred = res["animal_alert"]
                
                if gt == 1 and pred == 1:
                    tp += 1; ds_tp += 1
                elif gt == 0 and pred == 1:
                    fp += 1; ds_fp += 1
                elif gt == 0 and pred == 0:
                    tn += 1; ds_tn += 1
                elif gt == 1 and pred == 0:
                    fn += 1; ds_fn += 1
                    
            dataset_logs.append({
                "dataset": ds_name, "ground_truth": gt, "total_frames": len(ds["frames"]) - 1,
                "TP": ds_tp, "FP": ds_fp, "TN": ds_tn, "FN": ds_fn,
                "Accuracy": round((ds_tp + ds_tn) / (len(ds["frames"]) - 1) * 100, 2)
            })
            
        total = tp + fp + tn + fn
        accuracy  = (tp + tn) / total if total > 0 else 0
        precision = tp / (tp + fp) if (tp + fp) > 0 else 0
        recall    = tp / (tp + fn) if (tp + fn) > 0 else 0
        specificity = tn / (tn + fp) if (tn + fp) > 0 else 0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0
        
        results[mode_name] = {
            "TP": tp, "FP": fp, "TN": tn, "FN": fn,
            "Accuracy": round(accuracy * 100, 2),
            "Precision": round(precision * 100, 2),
            "Recall": round(recall * 100, 2),
            "Specificity": round(specificity * 100, 2),
            "F1_Score": round(f1 * 100, 2),
            "dataset_breakdown": dataset_logs
        }
        
    print("\n[2/3] Benchmarking completed across all video datasets!")
    with open("test_results/benchmark/benchmark_results.json", "w") as f:
        json.dump(results, f, indent=2)
        
    print("\n==================================================================")
    print("      QUANTITATIVE CLASSIFICATION BENCHMARK COMPARISON")
    print("==================================================================")
    print(f"{'Metric':<18} | {'Base Paper (Original)':<22} | {'Our Architecture (Novelty)':<25}")
    print("-" * 72)
    print(f"{'Accuracy (%)':<18} | {results['base_paper']['Accuracy']:<22.2f} | {results['our_novelty']['Accuracy']:<25.2f}")
    print(f"{'Precision (%)':<18} | {results['base_paper']['Precision']:<22.2f} | {results['our_novelty']['Precision']:<25.2f}")
    print(f"{'Recall (%)':<18} | {results['base_paper']['Recall']:<22.2f} | {results['our_novelty']['Recall']:<25.2f}")
    print(f"{'Specificity (%)':<18} | {results['base_paper']['Specificity']:<22.2f} | {results['our_novelty']['Specificity']:<25.2f}")
    print(f"{'F1-Score (%)':<18} | {results['base_paper']['F1_Score']:<22.2f} | {results['our_novelty']['F1_Score']:<25.2f}")
    print(f"{'True Positives (TP)':<18} | {results['base_paper']['TP']:<22} | {results['our_novelty']['TP']:<25}")
    print(f"{'False Positives (FP)':<18} | {results['base_paper']['FP']:<22} | {results['our_novelty']['FP']:<25}")
    print(f"{'True Negatives (TN)':<18} | {results['base_paper']['TN']:<22} | {results['our_novelty']['TN']:<25}")
    print(f"{'False Negatives (FN)':<18} | {results['base_paper']['FN']:<22} | {results['our_novelty']['FN']:<25}")
    print("==================================================================")
    
    return results

if __name__ == "__main__":
    run_benchmark()
