#!/usr/bin/env python3
"""
Video to FPGA Frame Converter
Converts any real video (.mp4, .avi, .webm, etc.) into 128x72 grayscale .mem hex files
and .png frames for Verilog testbench simulation.

Usage:
    python scripts/video_to_frames.py <video_file> [output_dir] [num_frames] [start_frame]

Examples:
    python scripts/video_to_frames.py test_videos/camera_trap_wildlife.mp4 test_videos/frames_wildlife 30 0
    python scripts/video_to_frames.py my_video.mp4 test_videos/frames_custom 20 10
"""

import sys
import os
import cv2
import numpy as np

def convert_video(video_path, output_dir=None, num_frames=30, start_frame=0):
    if not os.path.exists(video_path):
        print(f"[ERROR] Video file not found: {video_path}")
        return False

    if output_dir is None:
        base_name = os.path.splitext(os.path.basename(video_path))[0]
        output_dir = os.path.join("test_videos", f"frames_{base_name}")

    os.makedirs(output_dir, exist_ok=True)

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"[ERROR] Could not open video file: {video_path}")
        return False

    total_video_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    print("==================================================================")
    print("   VIDEO TO FPGA TESTBENCH FRAME GENERATOR")
    print("==================================================================")
    print(f" Input Video   : {video_path}")
    print(f" Native Specs  : {width}x{height} @ {fps:.1f} fps ({total_video_frames} frames)")
    print(f" Output Target : {output_dir}")
    print(f" Target Res    : 128x72 (FPGA Hardware Resolution)")
    print(f" Frame Count   : {num_frames} frames (starting at frame #{start_frame})")
    print("==================================================================")

    cap.set(cv2.CAP_PROP_POS_FRAMES, start_frame)

    count = 0
    while count < num_frames:
        ret, frame = cap.read()
        if not ret:
            print(f"[INFO] Reached end of video stream after {count} frames.")
            break

        # 1. Convert to Grayscale
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        # 2. Resize to FPGA resolution (128x72)
        resized = cv2.resize(gray, (128, 72), interpolation=cv2.INTER_AREA)

        # 3. Save PNG for visual inspection
        png_path = os.path.join(output_dir, f"frame_{count:03d}.png")
        cv2.imwrite(png_path, resized)

        # 4. Save Verilog $readmemh compatible hex memory file (9216 lines)
        mem_path = os.path.join(output_dir, f"frame_{count:03d}.mem")
        with open(mem_path, "w") as f:
            for row in resized:
                for pixel in row:
                    f.write(f"{int(pixel):02X}\n")

        count += 1
        if count % 10 == 0 or count == num_frames:
            print(f"  -> Generated {count}/{num_frames} frames...")

    cap.release()

    print("\n[SUCCESS] Extraction completed!")
    print(f"Generated {count} .mem and .png frames in '{output_dir}'.")
    print("\nTo simulate these frames in Vivado:")
    print("  1. Open Vivado and load the project.")
    print("  2. In top_tb.v, the testbench will automatically stream these frames.")
    print("  3. Click 'Run Behavioral Simulation' in the Vivado GUI.")
    print("==================================================================")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    v_path = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else None
    n_frames = int(sys.argv[3]) if len(sys.argv) > 3 else 30
    s_frame = int(sys.argv[4]) if len(sys.argv) > 4 else 0

    success = convert_video(v_path, out_dir, n_frames, s_frame)
    sys.exit(0 if success else 1)
