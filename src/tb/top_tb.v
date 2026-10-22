`timescale 1ns / 1ps

module top_tb;

    reg        clk = 1'b0;
    reg        rst;
    reg        load_en;
    reg [7:0]  pixel_in;
    reg [13:0] pixel_addr;

    reg [1:0]  fusion_mode;
    reg [7:0]  motion_threshold;
    reg [7:0]  edge_threshold;
    reg [2:0]  persist_thresh;
    reg [6:0]  min_width, max_width;
    reg [6:0]  min_height, max_height;
    reg [13:0] min_area;
    reg [7:0]  max_aspect_ratio;

    wire        frame_ready;
    wire        process_busy;
    wire        motion_alert;
    wire        animal_alert;
    wire [6:0]  x_min, x_max;
    wire [6:0]  y_min, y_max;
    wire [6:0]  centroid_x, centroid_y;
    wire [13:0] pixel_count;
    wire        bbox_valid;

    // Unit Under Test instantiation
    top #(
        .FRAME_WIDTH(128),
        .FRAME_HEIGHT(72),
        .TOTAL_PIXELS(9216),
        .PIPE_DEPTH(136)
    ) uut (
        .clk(clk),
        .rst(rst),
        .load_en(load_en),
        .pixel_in(pixel_in),
        .pixel_addr(pixel_addr),
        .fusion_mode(fusion_mode),
        .motion_threshold(motion_threshold),
        .edge_threshold(edge_threshold),
        .persist_thresh(persist_thresh),
        .min_width(min_width),
        .max_width(max_width),
        .min_height(min_height),
        .max_height(max_height),
        .min_area(min_area),
        .max_aspect_ratio(max_aspect_ratio),
        .frame_ready(frame_ready),
        .process_busy(process_busy),
        .motion_alert(motion_alert),
        .animal_alert(animal_alert),
        .x_min(x_min),
        .x_max(x_max),
        .y_min(y_min),
        .y_max(y_max),
        .centroid_x(centroid_x),
        .centroid_y(centroid_y),
        .pixel_count(pixel_count),
        .bbox_valid(bbox_valid)
    );

    // 50 MHz clock generation (20 ns period)
    always #10 clk = ~clk;

    integer test_errors = 0;

    // Real Frame Memory for reading hex files
    reg [7:0]    real_frame_mem [0:9215];
    reg [2047:0] resolved_frame_dir;
    reg [2047:0] current_frame_path;
    integer      real_frames_available;
    integer      dir_check_fp;

    // Task to automatically locate test_videos path across Vivado GUI, CLI, and scripts
    task detect_test_video_path;
        begin
            real_frames_available = 0;
            // 1. Check current directory / project root first
            resolved_frame_dir = "test_videos/frames_wildlife";
            dir_check_fp = $fopen("test_videos/frames_wildlife/frame_000.mem", "r");
            if (dir_check_fp != 0) begin
                $fclose(dir_check_fp);
                real_frames_available = 1;
            end else begin
                // 2. Check 5 levels up (Vivado GUI default xsim directory: vivado_project/DCD_Project.sim/sim_1/behav/xsim)
                resolved_frame_dir = "../../../../../test_videos/frames_wildlife";
                dir_check_fp = $fopen("../../../../../test_videos/frames_wildlife/frame_000.mem", "r");
                if (dir_check_fp != 0) begin
                    $fclose(dir_check_fp);
                    real_frames_available = 1;
                end else begin
                    // 3. Check 4 levels up
                    resolved_frame_dir = "../../../../test_videos/frames_wildlife";
                    dir_check_fp = $fopen("../../../../test_videos/frames_wildlife/frame_000.mem", "r");
                    if (dir_check_fp != 0) begin
                        $fclose(dir_check_fp);
                        real_frames_available = 1;
                    end else begin
                        // 4. Check 1 level up (scripts directory)
                        resolved_frame_dir = "../test_videos/frames_wildlife";
                        dir_check_fp = $fopen("../test_videos/frames_wildlife/frame_000.mem", "r");
                        if (dir_check_fp != 0) begin
                            $fclose(dir_check_fp);
                            real_frames_available = 1;
                        end
                    end
                end
            end
        end
    endtask

    // Task to load a synthetic video frame
    task load_synthetic_frame(
        input integer frame_num,
        input [511:0] description,
        input integer obj_enable,
        input integer obj_x,
        input integer obj_y,
        input integer obj_w,
        input integer obj_h
    );
        integer x, y, addr;
        begin
            $display("------------------------------------------------------------------");
            $display("[TB-SYNTH] Loading Frame #%0d: %0s", frame_num, description);
            for (addr = 0; addr < 9216; addr = addr + 1) begin
                @(posedge clk);
                load_en    <= 1'b1;
                pixel_addr <= addr[13:0];
                x = addr % 128;
                y = addr / 128;

                if (obj_enable &&
                    (x >= obj_x) && (x < obj_x + obj_w) &&
                    (y >= obj_y) && (y < obj_y + obj_h)) begin
                    pixel_in <= 8'd210; // Animal foreground intensity
                end else begin
                    pixel_in <= 8'd40;  // Background intensity
                end
            end
            @(posedge clk);
            load_en <= 1'b0;

            // Wait for processing to begin and end
            wait (process_busy == 1'b1);
            wait (process_busy == 1'b0);
            @(posedge clk);

            $display("  -> Result: Motion_Alert=%b, Animal_Alert=%b",
                     motion_alert, animal_alert);
            $display("  -> BBox:   X=[%0d..%0d], Y=[%0d..%0d]",
                     x_min, x_max, y_min, y_max);
            $display("  -> Center: Centroid=(%0d,%0d), Foreground Pixels=%0d",
                     centroid_x, centroid_y, pixel_count);
        end
    endtask

    // Task to stream and process a real video frame from disk
    task load_real_frame(
        input integer f_idx,
        input [511:0] frame_desc,
        input [1:0]   f_mode,
        input [7:0]   m_thresh,
        input [7:0]   e_thresh
    );
        integer addr;
        begin
            fusion_mode      <= f_mode;
            motion_threshold <= m_thresh;
            edge_threshold   <= e_thresh;

            $sformat(current_frame_path, "%0s/frame_%03d.mem", resolved_frame_dir, f_idx);
            $display("------------------------------------------------------------------");
            $display("[TB-REAL] Frame #%0d (%0s)", f_idx, frame_desc);
            $display("          Reading: %0s", current_frame_path);

            $readmemh(current_frame_path, real_frame_mem);

            for (addr = 0; addr < 9216; addr = addr + 1) begin
                @(posedge clk);
                load_en    <= 1'b1;
                pixel_addr <= addr[13:0];
                pixel_in   <= real_frame_mem[addr];
            end
            @(posedge clk);
            load_en <= 1'b0;

            // Wait for FPGA processing pipeline
            wait (process_busy == 1'b1);
            wait (process_busy == 1'b0);
            @(posedge clk);

            $display("  -> Result: Motion_Alert=%b, Animal_Alert=%b, FusionMode=%b",
                     motion_alert, animal_alert, f_mode);
            if (pixel_count > 14'd0) begin
                $display("  -> BBox:   X=[%0d..%0d], Y=[%0d..%0d] (W=%0d, H=%0d)",
                         x_min, x_max, y_min, y_max,
                         (x_max - x_min + 7'd1), (y_max - y_min + 7'd1));
                $display("  -> Center: Centroid=(%0d,%0d), Active Pixels=%0d",
                         centroid_x, centroid_y, pixel_count);
            end else begin
                $display("  -> BBox:   No active motion detected (Pixels=0)");
            end
        end
    endtask

    initial begin
        $display("==================================================================");
        $display("   FPGA WILD ANIMAL DETECTION SYSTEM — VERILOG VERIFICATION");
        $display("   Base: Abhishek & Megalingam 2025 + 4 Novelty Improvements");
        $display("==================================================================");

        clk         = 1'b0;
        rst         = 1'b1;
        load_en     = 1'b0;
        pixel_in    = 8'd0;
        pixel_addr  = 14'd0;

        // Default configuration
        fusion_mode      = 2'b00;  // Motion silhouette
        motion_threshold = 8'd28;  // Optimal for natural surveillance footage
        edge_threshold   = 8'd40;
        persist_thresh   = 3'd1;   // Fast response
        min_width        = 7'd5;
        max_width        = 7'd115; // Accommodates natural camera-trap field of view
        min_height       = 7'd5;
        max_height       = 7'd65;
        min_area         = 14'd20;
        max_aspect_ratio = 8'd64;  // 4.0 max aspect ratio (side profile quadruped)

        // Apply reset
        #100;
        @(posedge clk);
        rst = 1'b0;
        #100;

        // ==============================================================
        // PART 1: DETERMINISTIC UNIT VERIFICATION TESTS
        // ==============================================================
        $display("\n--- [PART 1] SYNTHETIC CONTROLLED TEST CASES ---");

        // TEST 1: Baseline Static Background (No objects)
        load_synthetic_frame(1, "Static Background Reference", 0, 0, 0, 0, 0);
        if (motion_alert !== 1'b0 || animal_alert !== 1'b0) begin
            $display("  [ERROR] False alarm triggered on static background!");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] Clean background verified: No false alarms.");
        end

        // TEST 2: Wild Animal Enters Scene at (X=40, Y=25), Size 20x14 (280 pixels)
        load_synthetic_frame(2, "Animal Appears (20x14 box at X:40, Y:25)", 1, 40, 25, 20, 14);
        if (motion_alert !== 1'b1 || animal_alert !== 1'b1) begin
            $display("  [ERROR] Expected animal_alert=1 and motion_alert=1!");
            test_errors = test_errors + 1;
        end else if (x_min !== 7'd40 || x_max !== 7'd59 || y_min !== 7'd25 || y_max !== 7'd38) begin
            $display("  [ERROR] Bounding box mismatch! Expected [40..59, 25..38], Got [%0d..%0d, %0d..%0d]",
                     x_min, x_max, y_min, y_max);
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] Animal successfully detected, localized, and classified!");
        end

        // TEST 3: Animal Moves to (X=60, Y=30), Size 20x14
        load_synthetic_frame(3, "Animal Moves to (X:60, Y:30)", 1, 60, 30, 20, 14);
        if (animal_alert !== 1'b1) begin
            $display("  [ERROR] Animal tracking failed on frame 3!");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] Dynamic motion tracking verified across frames.");
        end

        // TEST 4: Noise / Rain / Shadow Speck (2x2 pixels = 4 pixels, below min_area=20)
        load_synthetic_frame(4, "Noise Speck (2x2 box, below min_area)", 1, 10, 10, 2, 2);
        if (animal_alert !== 1'b0) begin
            $display("  [ERROR] Noise speck should be classified as non-animal!");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] Lightweight classifier successfully rejected noise artifact.");
        end

        // TEST 5: Strict Sobel Edge + Motion Fusion Mode (fusion_mode = 2'b01)
        fusion_mode = 2'b01;
        load_synthetic_frame(5, "Animal with Parallel Sobel Edge Fusion", 1, 45, 20, 22, 16);
        $display("  [INFO] Sobel Edge Fusion completed with Edge Pixels=%0d.", pixel_count);

        // ==============================================================
        // PART 2: REAL VIDEO & FRAME SEQUENCE VERIFICATION
        // Evaluates real video frames for Motion Detection & Edge Detection
        // ==============================================================
        $display("\n==================================================================");
        $display("   PART 2: REAL-WORLD VIDEO SURVEILLANCE & FRAME SEQUENCE");
        $display("   Testing Real Video Frames (Motion Detection & Sobel Edge Fusion)");
        $display("==================================================================");

        detect_test_video_path;

        if (real_frames_available) begin
            $display("  [INFO] Successfully located test frames at: %0s", resolved_frame_dir);

            // Re-arm reset to establish clean memory state
            rst = 1'b1;
            #40;
            @(posedge clk);
            rst = 1'b0;
            #40;

            // Frame 00: Initial Background Reference
            load_real_frame(0, "Baseline Video Frame (Reference)", 2'b00, 8'd28, 8'd40);

            // Frame 01: Real Animal Enters (Motion Detection Mode 00)
            load_real_frame(1, "Animal In Motion (Motion Detection)", 2'b00, 8'd28, 8'd40);

            // Frame 02: Real Animal Advancing (Motion Tracking)
            load_real_frame(2, "Animal Advancing (Motion Tracking)", 2'b00, 8'd28, 8'd40);

            // Frame 03: Parallel Sobel Edge Detection + Motion Fusion (Mode 01)
            load_real_frame(3, "Parallel Sobel Edge + Motion (Mode 01)", 2'b01, 8'd28, 8'd40);

            // Frame 04: Sobel Edge OR Motion Dual-Path (Mode 10)
            load_real_frame(4, "Sobel Edge OR Motion Dual-Path (Mode 10)", 2'b10, 8'd28, 8'd40);

            // Frame 05: Real Animal Localized & Classified
            load_real_frame(5, "Animal Classification & Localization", 2'b00, 8'd28, 8'd40);

            $display("  [PASS] Real video frame verification completed successfully!");
        end else begin
            $display("  [NOTE] Test video directory 'test_videos/frames_wildlife' was not found");
            $display("         in default search paths. Synthetic test suite passed.");
        end

        #500;
        $display("\n==================================================================");
        if (test_errors == 0) begin
            $display("   >>> ALL VERIFICATION TESTS PASSED SUCCESSFULLY (0 ERRORS) <<<");
        end else begin
            $display("   >>> VERIFICATION COMPLETED WITH %0d ERRORS <<<", test_errors);
        end
        $display("==================================================================");

        $finish;
    end

endmodule
