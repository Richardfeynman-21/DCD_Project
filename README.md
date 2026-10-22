# FPGA-Based Wild Animal Detection System

Digital Circuit Design (DCD) Vivado Project implementing a real-time, FPGA-accelerated wildlife surveillance pipeline.
Based on **Abhishek & Megalingam (2025)** with **4 Novelty Architectural Improvements**:
1. **Parallel 3x3 Pipelined Sobel Edge Detection** (line buffer windowing, 1-cycle throughput)
2. **BRAM-Based Temporal Persistence Filter** (anti-flicker and shadow suppression)
3. **Single-Pass Hardware Bounding Box & Centroid Extraction**
4. **Lightweight Multi-Feature Spatial Classifier** (area, aspect ratio, fill factor)

---

## 🎬 Testing with Real Video & Frame Sequences

The repository includes the real wildlife camera trap video dataset and pre-extracted frame sequences:
- `test_videos/camera_trap_wildlife.mp4` (Surveillance camera-trap footage)
- `test_videos/frames_wildlife/` (30 frames in both 128x72 `.mem` hex and `.png` format)

### Converting Any Other Real Video into Simulation Frames:
You can supply **any** video file (`.mp4`, `.avi`, `.webm`, etc.) and convert it into 128x72 FPGA frames:
```bash
python scripts/video_to_frames.py <path_to_video.mp4> [output_directory] [num_frames]
```
Example:
```bash
python scripts/video_to_frames.py test_videos/camera_trap_wildlife.mp4 test_videos/frames_wildlife 30
```

---

## 🧪 Running Simulation in Vivado

### Option A: Vivado GUI (One Click)
1. Double-click `launch_vivado_gui.bat` (Windows) or open `vivado_project/DCD_Project.xpr` in Vivado.
2. In the Vivado **Flow Navigator** on the left panel, click **Run Simulation** -> **Run Behavioral Simulation**.
3. The simulation automatically runs:
   - **Part 1 (Synthetic Test Cases)**: Tests static background, animal entry, movement tracking, noise rejection, and edge fusion.
   - **Part 2 (Real Video Frame Sequence)**: Streams real video frames (`test_videos/frames_wildlife`) directly into the FPGA hardware model and prints frame-by-frame detection status, bounding box coordinates $[X_{min}..X_{max}, Y_{min}..Y_{max}]$, centroid $(X, Y)$, and classification alerts in the Tcl Console!

### Option B: Windows 1-Click Simulation Runner
Simply double-click:
```text
run_simulation_windows.bat
```
This automatically configures the environment PATH, runs behavioral simulation in batch mode, and displays test results.

### Option C: Vivado Tcl Console (Cross-Platform)
Inside the Vivado Tcl Console, enter:
```tcl
source scripts/run_simulation.tcl
```

---

## 🚀 Getting Started for Team Members (Lab Vivado 2018 & Windows Vivado 2023)

### 1. Recreate the Vivado Project for your specific Vivado version:
In the terminal / Tcl Console:
```bash
vivado -mode batch -source scripts/create_project.tcl
```
*(Or in Vivado GUI Tcl Console: `source scripts/create_project.tcl`)*

---

## 📁 Repository Directory Structure

```text
DCD_Project/
├── launch_vivado_gui.bat         # 1-click launcher with auto-configured environment
├── run_simulation_windows.bat    # 1-click batch simulation runner
├── scripts/
│   ├── create_project.tcl        # Recreates native Vivado project for any version (2018-2026)
│   ├── run_simulation.tcl        # Batch behavioral simulation runner
│   ├── video_to_frames.py        # Converts any video to 128x72 .mem hex frames
│   ├── test_sobel_edge.py        # Compares FPGA Sobel hardware against OpenCV
│   └── run_full_benchmark.py     # Comprehensive surveillance metrics & confusion matrix
├── src/
│   ├── rtl/                      # Verilog RTL synthesizable source modules
│   │   ├── top.v                 # Top-level integration pipeline
│   │   ├── sobel_edge_detect.v   # Parallel 3x3 Sobel edge filter (Novelty 1)
│   │   ├── motion_detect.v       # Frame differencing engine
│   │   ├── fusion.v              # Temporal/spatial delay-compensated fusion
│   │   ├── shadow_suppress.v     # BRAM temporal persistence filter (Novelty 2)
│   │   ├── bbox_centroid.v       # Single-pass bounding box & centroid (Novelty 3)
│   │   ├── classifier.v          # Multi-feature rule classifier (Novelty 4)
│   │   ├── control_logic.v       # Alert generation logic
│   │   ├── frame_memory.v        # Ping-pong BRAM frame buffer
│   │   ├── line_buffer.v         # 128-pixel shift register FIFO
│   │   └── divider.v             # Restoring integer divider for centroid
│   ├── tb/                       # Simulation testbenches
│   │   └── top_tb.v              # Master simulation testbench (Synthetic + Real Video)
│   └── constrs/                  # FPGA pin and timing constraints (.xdc)
├── test_videos/                  # Real surveillance video clips & frame sequences
│   ├── camera_trap_wildlife.mp4  # Camera trap video
│   └── frames_wildlife/          # 30 frames (.mem hex & .png)
└── vivado_project/               # Local Vivado project (.xpr)
```
