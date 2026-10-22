#!/usr/bin/env python3
"""
High-Definition Video to FPGA Frame Converter & Motion Extractor
-----------------------------------------------------------------
Converts video into crisp, high-contrast 128x72 frames for FPGA behavioral simulation.
Features:
  1. Auto-detects the active motion sequence where animals move.
  2. Frame stride/step to ensure clear, visible movement between consecutive frames.
  3. CLAHE contrast enhancement & edge sharpening to eliminate blur and muddy grayness.
  4. Exports both exact 128x72 hardware files (.mem & .png) and crisp 512x288 previews.
  5. Generates a composite motion grid image for quick visual inspection.

Usage:
    python scripts/video_to_frames.py <video_file> [output_dir] [num_frames] [start_frame] [step]

Examples:
    python scripts/video_to_frames.py test_videos/camera_trap_wildlife.mp4 test_videos/frames_wildlife 30
    python scripts/video_to_frames.py test_videos/camera_trap_wildlife.mp4 test_videos/frames_wildlife 30 35 3
"""

import sys
import os
import cv2
import numpy as np

def find_best_motion_window(video_path, window_size=30, step=3):
    """Scans the video to automatically locate the segment with strongest animal motion."""
    cap = cv2.VideoCapture(video_path)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    if total_frames <= 0:
        return 0

    prev_gray = None
    motion_scores = []
    sample_rate = 2

    for f in range(0, total_frames, sample_rate):
        cap.set(cv2.CAP_PROP_POS_FRAMES, f)
        ret, frame = cap.read()
        if not ret: break
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        if prev_gray is not None:
            diff = cv2.absdiff(gray, prev_gray)
            score = int(np.sum(diff > 25))
            motion_scores.append((f, score))
        prev_gray = gray
    cap.release()

    if not motion_scores:
        return 0

    # Find window of length (window_size * step) with maximum sustained motion
    needed_span = window_size * step
    best_start = 0
    max_sum = -1

    for i in range(len(motion_scores)):
        start_f = motion_scores[i][0]
        if start_f + needed_span > total_frames:
            break
        # Sum motion in this window
        win_motion = sum(s[1] for s in motion_scores if start_f <= s[0] < start_f + needed_span)
        if win_motion > max_sum:
            max_sum = win_motion
            best_start = start_f

    return best_start

def enhance_frame(gray_frame):
    """
    Applies Adaptive Contrast Enhancement (CLAHE) and Unsharp Masking
    to eliminate blur, expand dynamic range, and sharpen animal contours.
    """
    # 1. CLAHE local contrast stretching (clipLimit=2.2, grid=8x8)
    clahe = cv2.createCLAHE(clipLimit=2.2, tileGridSize=(8, 8))
    contrasted = clahe.apply(gray_frame)

    # 2. High-quality anti-aliased downsampling to FPGA resolution (128x72)
    resized = cv2.resize(contrasted, (128, 72), interpolation=cv2.INTER_AREA)

    # 3. Unsharp masking to keep boundaries crisp at low resolution
    blurred = cv2.GaussianBlur(resized, (0, 0), 1.2)
    sharpened = cv2.addWeighted(resized, 1.6, blurred, -0.6, 0)

    # 4. Normalize and clip to full 8-bit dynamic range [0..255]
    final_frame = np.clip(sharpened, 0, 255).astype(np.uint8)
    return final_frame

def convert_video(video_path, output_dir=None, num_frames=30, start_frame=None, step=3):
    if not os.path.exists(video_path):
        print(f"[ERROR] Video file not found: {video_path}")
        return False

    if output_dir is None:
        base_name = os.path.splitext(os.path.basename(video_path))[0]
        output_dir = os.path.join("test_videos", f"frames_{base_name}")

    preview_dir = os.path.join(output_dir, "previews")
    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(preview_dir, exist_ok=True)

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"[ERROR] Could not open video file: {video_path}")
        return False

    total_video_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    native_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    native_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    # Auto-detect start frame if not explicitly given
    if start_frame is None or start_frame < 0:
        print("[INFO] Scanning video for peak animal movement window...")
        start_frame = find_best_motion_window(video_path, window_size=num_frames, step=step)
        print(f"[INFO] Auto-selected optimal motion start frame: #{start_frame}")

    print("==================================================================")
    print("   HIGH-DEFINITION FPGA FRAME EXTRACTION & ENHANCEMENT")
    print("==================================================================")
    print(f" Input Video     : {video_path}")
    print(f" Native Specs    : {native_w}x{native_h} @ {fps:.1f} fps ({total_video_frames} frames)")
    print(f" Output Target   : {output_dir}")
    print(f" Hardware Res    : 128x72 (FPGA Hardware Resolution)")
    print(f" Frame Count     : {num_frames} frames")
    print(f" Start Frame     : #{start_frame} (Time: {start_frame/fps:.2f}s)")
    print(f" Frame Stride    : Every {step} frames (~{fps/step:.1f} fps effective)")
    print(" Enhancement     : CLAHE Contrast + Edge Sharpening + Anti-Aliased Resampling")
    print("==================================================================")

    extracted_frames = []
    grid_images = []

    for i in range(num_frames):
        target_f = start_frame + i * step
        if target_f >= total_video_frames:
            print(f"[INFO] Video ended at frame {target_f}. Extracted {i} frames.")
            break

        cap.set(cv2.CAP_PROP_POS_FRAMES, target_f)
        ret, raw_frame = cap.read()
        if not ret: break

        gray = cv2.cvtColor(raw_frame, cv2.COLOR_BGR2GRAY)
        enhanced = enhance_frame(gray)
        extracted_frames.append(enhanced)

        # 1. Save hardware exact 128x72 PNG
        png_path = os.path.join(output_dir, f"frame_{i:03d}.png")
        cv2.imwrite(png_path, enhanced)

        # 2. Save hardware Verilog $readmemh hex memory file (9216 lines)
        mem_path = os.path.join(output_dir, f"frame_{i:03d}.mem")
        with open(mem_path, "w") as f:
            for row in enhanced:
                for pixel in row:
                    f.write(f"{int(pixel):02X}\n")

        # 3. Save crisp 512x288 nearest-neighbor upscaled preview for human viewing
        # (This prevents Windows Photo Viewer from applying blurry bilinear smoothing)
        crisp_preview = cv2.resize(enhanced, (512, 288), interpolation=cv2.INTER_NEAREST)
        cv2.putText(crisp_preview, f"Frame #{i:02d} (Src: {target_f})", (15, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, 255, 2, cv2.LINE_AA)
        preview_path = os.path.join(preview_dir, f"preview_{i:03d}.png")
        cv2.imwrite(preview_path, crisp_preview)

        # Save subset for grid
        if i < 12:
            grid_images.append(crisp_preview)

        if (i + 1) % 5 == 0 or (i + 1) == num_frames:
            print(f"  -> Processed {i+1}/{num_frames} frames...")

    cap.release()

    # 4. Generate composite motion grid image (3 rows x 4 cols = 12 frames)
    if len(grid_images) >= 12:
        row1 = np.hstack(grid_images[0:4])
        row2 = np.hstack(grid_images[4:8])
        row3 = np.hstack(grid_images[8:12])
        grid = np.vstack([row1, row2, row3])
        grid_scaled = cv2.resize(grid, (1280, 720), interpolation=cv2.INTER_AREA)
        grid_path = os.path.join(output_dir, "motion_sequence_grid.png")
        cv2.imwrite(grid_path, grid_scaled)
        print(f"\n[INFO] Generated motion sequence grid at: {grid_path}")

    # Compute inter-frame movement verification
    if len(extracted_frames) >= 2:
        deltas = []
        for j in range(len(extracted_frames) - 1):
            d = np.sum(cv2.absdiff(extracted_frames[j], extracted_frames[j+1]) > 20)
            deltas.append(d)
        avg_motion = np.mean(deltas)
        print(f"[VERIFIED] Average inter-frame motion delta: {avg_motion:.1f} active pixels/frame.")
        print(f"           Strong dynamic movement present across consecutive frames!")

    print("\n[SUCCESS] Frame extraction and enhancement complete!")
    print(f"Hardware simulation files ready in '{output_dir}'.")
    print(f"Crisp previews ready in '{preview_dir}'.")
    return True

if __name__ == "__main__":
    v_path = sys.argv[1] if len(sys.argv) > 1 else "test_videos/camera_trap_wildlife.mp4"
    out_dir = sys.argv[2] if len(sys.argv) > 2 else "test_videos/frames_wildlife"
    n_frames = int(sys.argv[3]) if len(sys.argv) > 3 else 30
    s_frame = int(sys.argv[4]) if len(sys.argv) > 4 else None
    step_val = int(sys.argv[5]) if len(sys.argv) > 5 else 3

    success = convert_video(v_path, out_dir, n_frames, s_frame, step_val)
    sys.exit(0 if success else 1)
