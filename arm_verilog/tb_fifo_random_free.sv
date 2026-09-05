`timescale 1ns/1ps

module tb_fifo_random_free;

    // ============================================================
    // Configuration
    // ============================================================

    localparam DATA_WIDTH = 8;
    localparam DEPTH      = 5;
    localparam NUM_CYCLES = 10000;

    // ============================================================
    // DUT signals
    // ============================================================

    reg clk = 0;
    reg rst_n;

    reg                  wr_en;
    reg                  rd_en;
    reg [DATA_WIDTH-1:0] wr_data;

    wire [DATA_WIDTH-1:0] rd_data;
    wire                  full;
    wire                  empty;
    wire [$clog2(DEPTH):0] count;

    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (wr_en),
        .wr_data (wr_data),
        .rd_en   (rd_en),
        .rd_data (rd_data),
        .full    (full),
        .empty   (empty),
        .count   (count)
    );

    // 100 MHz clock
    always #5 clk = ~clk;


    // ============================================================
    // SOFTWARE REFERENCE MODEL
    // ============================================================

    reg [DATA_WIDTH-1:0] ref_mem [0:DEPTH-1];

    integer ref_head;
    integer ref_tail;
    integer ref_count;

    reg [DATA_WIDTH-1:0] expected_data;

    // ============================================================
    // Statistics
    // ============================================================

    integer errors;
    integer cycle_num;

    integer write_only_count;
    integer read_only_count;
    integer simultaneous_count;

    integer dropped_write_count;
    integer dropped_read_count;


    // ============================================================
    // FUNCTIONAL COVERAGE
    //
    // Icarus-friendly manual coverage.
    //
    // Instead of covergroup/coverpoint, we count whether each
    // important condition occurred.
    // ============================================================

    integer cov_full;
    integer cov_empty;
    integer cov_simultaneous;

    integer cov_full_write;
    integer cov_empty_read;

    integer cov_full_simul;
    integer cov_empty_simul;
    integer coverage_bins;
    integer coverage_hits;
    integer coverage_percent;


    // ============================================================
    // Reference model initialization
    // ============================================================

    task reset_reference_model;
        begin
            ref_head  = 0;
            ref_tail  = 0;
            ref_count = 0;
        end
    endtask


    // ============================================================
    // Reference model PUSH
    // ============================================================

    task reference_push(input [DATA_WIDTH-1:0] data);
        begin

            ref_mem[ref_tail] = data;

            if (ref_tail == DEPTH-1)
                ref_tail = 0;
            else
                ref_tail = ref_tail + 1;

            ref_count = ref_count + 1;
        end
    endtask


    // ============================================================
    // Reference model POP
    // ============================================================

    task reference_pop;
        begin

            expected_data = ref_mem[ref_head];

            if (ref_head == DEPTH-1)
                ref_head = 0;
            else
                ref_head = ref_head + 1;

            ref_count = ref_count - 1;
        end
    endtask


    // ============================================================
    // Error reporting
    // ============================================================

    task fail(input string message);
    begin
        $display(
            "[FAIL] cycle=%0d time=%0t : %s",
            cycle_num,
            $time,
            message
        );

        errors = errors + 1;
    end
endtask


    // ============================================================
    // Reset
    // ============================================================

    task apply_reset;
        begin

            rst_n  = 0;
            wr_en  = 0;
            rd_en  = 0;
            wr_data = 0;

            reset_reference_model();

            repeat (3)
                @(negedge clk);

            rst_n = 1;

            @(posedge clk);
            #1;

            if (count !== 0)
                fail("FIFO count is not zero after reset");

            if (!empty)
                fail("FIFO empty flag is not asserted after reset");

            if (full)
                fail("FIFO full flag asserted after reset");

            $display("[OK] reset complete");
        end
    endtask


    // ============================================================
    // Generate random stimulus
    //
    // This is our "constraint-like" random generator.
    //
    // bias:
    //
    // 75 -> mostly writes
    // 50 -> balanced
    // 25 -> mostly reads
    // ============================================================

    task generate_transaction(input integer bias);

        integer random_value;

        begin

            random_value = $urandom_range(0,99);

            if (random_value < bias)
                wr_en = 1;
            else
                wr_en = 0;


            random_value = $urandom_range(0,99);

            if (random_value < (100-bias))
                rd_en = 1;
            else
                rd_en = 0;


            wr_data = $urandom_range(0,255);

        end

    endtask


    // ============================================================
    // One verification cycle
    // ============================================================

    task verify_cycle;

        reg do_read;
        reg do_write;

        begin

            // ----------------------------------------------------
            // Predict what DUT should accept
            // ----------------------------------------------------

            do_read = rd_en && !empty;

            do_write = wr_en && (!full || do_read);


            // ----------------------------------------------------
            // Functional coverage
            // ----------------------------------------------------

            if (full)
                cov_full = cov_full + 1;

            if (empty)
                cov_empty = cov_empty + 1;

            if (wr_en && rd_en)
                cov_simultaneous = cov_simultaneous + 1;


            if (full && wr_en)
                cov_full_write = cov_full_write + 1;

            if (empty && rd_en)
                cov_empty_read = cov_empty_read + 1;

            if (full && wr_en && rd_en)
                cov_full_simul = cov_full_simul + 1;

            if (empty && wr_en && rd_en)
                cov_empty_simul = cov_empty_simul + 1;


            // ----------------------------------------------------
            // Track dropped operations
            // ----------------------------------------------------

            if (wr_en && full && !do_read)
                dropped_write_count = dropped_write_count + 1;

            if (rd_en && empty)
                dropped_read_count = dropped_read_count + 1;


            // ----------------------------------------------------
            // Save expected read value BEFORE DUT clock edge
            // ----------------------------------------------------

            if (do_read)
                reference_pop();


            // ----------------------------------------------------
            // Write accepted data into reference FIFO
            //
            // IMPORTANT:
            //
            // For simultaneous full read/write:
            //
            // pop old data
            // push new data
            //
            // The queue therefore remains DEPTH deep.
            // ----------------------------------------------------

            if (do_write)
                reference_push(wr_data);


            // ----------------------------------------------------
            // Statistics
            // ----------------------------------------------------

            if (do_write && do_read)
                simultaneous_count = simultaneous_count + 1;
            else if (do_write)
                write_only_count = write_only_count + 1;
            else if (do_read)
                read_only_count = read_only_count + 1;


            // ----------------------------------------------------
            // Clock edge
            // ----------------------------------------------------

            @(posedge clk);

            #1;


            // ----------------------------------------------------
            // Check registered read data
            // ----------------------------------------------------

            if (do_read) begin

                if (rd_data !== expected_data) begin

                    fail(
                        $sformatf(
                            "DATA mismatch: DUT=%02h EXPECTED=%02h",
                            rd_data,
                            expected_data
                        )
                    );

                end

            end


            // ----------------------------------------------------
            // Check count
            // ----------------------------------------------------

            if (count !== ref_count) begin

                fail(
                    $sformatf(
                        "COUNT mismatch: DUT=%0d REF=%0d",
                        count,
                        ref_count
                    )
                );

            end


            // ----------------------------------------------------
            // Check flags
            // ----------------------------------------------------

            if (full !== (ref_count == DEPTH))
                fail("FULL flag incorrect");


            if (empty !== (ref_count == 0))
                fail("EMPTY flag incorrect");


            // ----------------------------------------------------
            // Safety checks
            // ----------------------------------------------------

            if (ref_count < 0)
                fail("Reference FIFO count went negative");


            if (ref_count > DEPTH)
                fail("Reference FIFO exceeded DEPTH");

        end

    endtask


    // ============================================================
    // Main test
    // ============================================================

    integer bias;

    initial begin

        errors = 0;

        write_only_count = 0;
        read_only_count = 0;
        simultaneous_count = 0;

        dropped_write_count = 0;
        dropped_read_count = 0;

        cov_full = 0;
        cov_empty = 0;
        cov_simultaneous = 0;

        cov_full_write = 0;
        cov_empty_read = 0;

        cov_full_simul = 0;
        cov_empty_simul = 0;


        // --------------------------------------------------------
        // VCD waveform
        // --------------------------------------------------------

        $dumpfile("fifo_random.vcd");
        $dumpvars(0, tb_fifo_random_free);


        // --------------------------------------------------------
        // Reset
        // --------------------------------------------------------

        apply_reset();


        // --------------------------------------------------------
        // Random regression
        // --------------------------------------------------------

        for (cycle_num = 0;
             cycle_num < NUM_CYCLES;
             cycle_num = cycle_num + 1) begin


            // -----------------------------------------------
            // Change random distribution during simulation
            //
            // First third:
            //     mostly WRITE -> reach FULL
            //
            // Middle:
            //     balanced
            //
            // Last third:
            //     mostly READ -> reach EMPTY
            // -----------------------------------------------

            if (cycle_num < NUM_CYCLES/3)
                bias = 75;

            else if (cycle_num < (2*NUM_CYCLES)/3)
                bias = 50;

            else
                bias = 25;


            // Generate randomized transaction
            @(negedge clk);

            generate_transaction(bias);


            // Check it
            verify_cycle();

        end
      
      
      coverage_bins = 7;
coverage_hits = 0;

if (cov_full > 0)
    coverage_hits = coverage_hits + 1;

if (cov_empty > 0)
    coverage_hits = coverage_hits + 1;

if (cov_simultaneous > 0)
    coverage_hits = coverage_hits + 1;

if (cov_full_write > 0)
    coverage_hits = coverage_hits + 1;

if (cov_empty_read > 0)
    coverage_hits = coverage_hits + 1;

if (cov_full_simul > 0)
    coverage_hits = coverage_hits + 1;

if (cov_empty_simul > 0)
    coverage_hits = coverage_hits + 1;

coverage_percent = (coverage_hits * 100) / coverage_bins;


        // --------------------------------------------------------
        // Final report
        // --------------------------------------------------------

        $display("");
        $display("============================================");
        $display("        FIFO RANDOM TEST SUMMARY");
        $display("============================================");

        $display("Total cycles          : %0d", NUM_CYCLES);

        $display("Write-only cycles     : %0d",
                 write_only_count);

        $display("Read-only cycles      : %0d",
                 read_only_count);

        $display("Simultaneous r+w      : %0d",
                 simultaneous_count);

        $display("Dropped writes        : %0d",
                 dropped_write_count);

        $display("Dropped reads         : %0d",
                 dropped_read_count);

        $display("--------------------------------------------");

        $display("FULL observed         : %0d", cov_full);
        $display("EMPTY observed        : %0d", cov_empty);
        $display("R+W observed          : %0d", cov_simultaneous);

        $display("FULL + WRITE          : %0d",
                 cov_full_write);

        $display("EMPTY + READ          : %0d",
                 cov_empty_read);

        $display("FULL + R+W            : %0d",
                 cov_full_simul);

        $display("EMPTY + R+W           : %0d",
                 cov_empty_simul);

        $display("--------------------------------------------");

        $display("Reference FIFO count  : %0d", ref_count);

        $display("Errors                : %0d", errors);

        $display("============================================");
     
$display("FUNCTIONAL COVERAGE");
$display("Coverage bins hit : %0d / %0d", coverage_hits, coverage_bins);
$display("Coverage          : %0d%%", coverage_percent);
      $display("============================================");


        if (errors == 0)
            $display("RESULT: RANDOM TEST PASSED");
        else
            $display("RESULT: RANDOM TEST FAILED");


        $display("============================================");

        $finish;

    end


    // ============================================================
    // Timeout protection
    // ============================================================

    initial begin

        #2_000_000;

        $display("[FAIL] Global timeout");

        $finish;

    end

endmodule