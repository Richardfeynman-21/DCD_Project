# FPGA Wildlife Detection System — Verification Metrics Table

## Summary of Intermediate Pipeline Stages (Frame #01: Wild Animal Entry)

| Pipeline Stage | Verilog Module | Input Resolution | Active Output Elements | Data Representation | Latency (Cycles) | Function / Purpose |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **1. Raw Frame Read** | `frame_memory.v` | 128x72 (9,216 px) | 9,216 pixels | 8-bit Grayscale (0..255) | 1 cycle | Dual-port synchronous BRAM frame buffer |
| **2. Motion Differencing** | `motion_detect.v` | 128x72 | 183 motion pixels | 1-bit Binary Mask | 2 cycles | Inter-frame temporal differencing ($|F_t - F_{t-1}| \ge 35$) |
| **3. Sobel Edge Gradient** | `sobel_edge_detect.v` | 128x72 | 1,420 edge pixels | 1-bit Edge + 8-bit Mag | 130 cycles | $3\times 3$ Line buffer parallel convolution ($|G_x| + |G_y| \ge 40$) |
| **4. Edge-Motion Fusion** | `fusion.v` | 128x72 | 183 fused pixels | 1-bit Binary Mask | 1 cycle | Delay-compensated spatiotemporal fusion |
| **5. Temporal Persistence** | `shadow_suppress.v` | 128x72 | 183 stable pixels | 1-bit Stable Mask | 2 cycles | $9216\times 3$-bit BRAM stability filter against wind/shadows |
| **6. Localization (BBox)** | `bbox_centroid.v` | 128x72 | $W=71, H=22$ | 7-bit Coords ($X, Y$) | Single Pass | One-pass coordinate boundary extractor [$X_{min}..X_{max}, Y_{min}..Y_{max}$] |
| **7. Centroid Calculation** | `divider.v` | 128x72 | Centroid=(77, 54) | 7-bit Coordinates | 14 cycles | Non-blocking restoring binary hardware divider |
| **8. Multi-Feature Classifier** | `classifier.v` | 183 pixels | **`is_animal = 1`** | 1-bit Boolean Verdict | 1 cycle | Evaluates 5 morphological rules concurrently |

---

## Final Classification Parameters & Verdict
* **Bounding Box:** $X=[46..116], Y=[45..66]$ ($W=71, H=22$)
* **Centroid:** $(77, 54)$
* **Active Foreground Pixels:** 183
* **Fill Occupancy Ratio:** 11.7% (Passes Rule 5: $\ge 6.25\%$)
* **Aspect Ratio:** 3.23 (Passes Rule 4: $\le 4.0$)
* **Hardware Output Alert:** `animal_alert = 1`, `motion_alert = 1`
