# DCD_Project

Digital Circuit Design (DCD) Vivado Project with Git version control setup.

---

## 👥 Team Collaboration Workflow

### Can multiple team members work on the same Vivado project?
**Yes, but with standard hardware engineering practices:**
- **Do not commit build artifacts**: Vivado generates gigabytes of temporary files (`.runs/`, `.cache/`, `.hw/`, `.sim/`, `.log`, `.jou`). These are ignored by [.gitignore](file:///.gitignore).
- **RTL sources are independent**: Team members can work on different Verilog/SystemVerilog modules simultaneously and merge code via Git cleanly without conflicts.
- **Project Recreation (Tcl Flow)**: To avoid `.xpr` project file merge conflicts, this repository includes an automated Tcl script (`scripts/create_project.tcl`). Anyone on the team can clone the repository and recreate the Vivado project with one command.

---

## 🚀 Getting Started for Team Members

### 1. Clone the repository
```bash
git clone <repository_url>
cd DCD_Project
```

### 2. Recreate the Vivado Project
Run the following in the terminal to generate your local Vivado project from source files:
```bash
vivado -mode batch -source scripts/create_project.tcl -notrace
```
*(Or open Vivado GUI, navigate to the project directory in the Vivado Tcl Console, and run `source scripts/create_project.tcl`)*

### 3. Open in Vivado GUI
After running the script, open the project:
```bash
vivado vivado_project/DCD_Project.xpr &
```

---

## 📁 Repository Directory Structure

```text
DCD_Project/
├── .gitignore                    # Ignores build runs, caches, logs, bitstreams
├── README.md                     # Documentation & team guide
├── scripts/
│   ├── create_project.tcl        # Recreates the Vivado project from scratch
│   └── export_project.tcl        # Exports current GUI project state back to script
├── src/
│   ├── rtl/                      # Verilog / SystemVerilog design sources (e.g. top.v)
│   ├── tb/                       # Simulation testbenches (e.g. top_tb.v)
│   └── constrs/                  # FPGA pin and timing constraints (.xdc)
└── vivado_project/               # Local Vivado project (.xpr)
```

---

## 🛠️ Making Changes & Sharing with Team

1. **Adding new HDL files:** Place them into `src/rtl/` or `src/tb/` and add them to your Vivado project.
2. **Exporting Project Settings (if GUI settings or IP blocks changed):**
   In Vivado Tcl Console, run:
   ```tcl
   source scripts/export_project.tcl
   ```
3. **Commit & Push:**
   ```bash
   git add src/ scripts/ README.md .gitignore
   git commit -m "Add new module description"
   git push origin main
   ```
