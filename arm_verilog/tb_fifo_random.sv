// ============================================================================
// tb_fifo_random.sv  -  Step 2 + 3: constrained-random stimulus + scoreboard
// ----------------------------------------------------------------------------
// This is the "real" verification environment. Compared to the directed test,
// nothing here hand-picks input values or expected outputs. Instead:
//
//   * A transaction class describes ONE cycle of stimulus (wr_en, rd_en, data)
//     and randomizes it under CONSTRAINTS (legal, weighted stimulus).
//   * A software reference model (a SystemVerilog queue, `ref_q`) mirrors what
//     an ideal FIFO would contain.
//   * A scoreboard compares every value the DUT pops against what the reference
//     queue says should come out, and checks the occupancy count too.
//   * Anything wrong -> automatic FAIL with the cycle and values, no waveform
//     staring required.
//
// RECOMMENDED SIMULATOR: Aldec Riviera-PRO / Synopsys VCS / Questa / Xcelium
// on EDA Playground (free, non-commercial). Icarus/Verilator won't handle the
// constraints + covergroup properly. Coverage lives in a separate file
// (fifo_coverage.sv) added in step 4; this file is the stimulus+checking core.
// ============================================================================
`timescale 1ns/1ps

module tb_fifo_random;

    // --- DUT parameters --------------------------------------------------
    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 16;
    localparam int NUM_TXNS   = 5000;   // how many random cycles to run

    // --- DUT connections -------------------------------------------------
    logic                    clk = 0, rst_n;
    logic                    wr_en, rd_en;
    logic [DATA_WIDTH-1:0]   wr_data;
    logic [DATA_WIDTH-1:0]   rd_data;
    logic                    full, empty;
    logic [$clog2(DEPTH):0]  count;

    fifo #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) dut (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en), .wr_data(wr_data),
        .rd_en(rd_en), .rd_data(rd_data),
        .full(full), .empty(empty), .count(count)
    );

    always #5 clk = ~clk;   // 100 MHz

    // =====================================================================
    // Transaction: one cycle of stimulus.
    //   `rand` = "solver picks a value each time we call randomize()".
    //   Constraints keep the randomness LEGAL and USEFUL:
    //     - c_valid_data : nothing special, data spans full range.
    //     - c_bias       : weight the enables. Early on we want to WRITE more
    //                      than we read so the FIFO actually fills up and we hit
    //                      `full`; the `wr_bias` knob (0..100) is set by the
    //                      test to steer this. This is the essence of
    //                      constrained-random: random, but nudged toward the
    //                      interesting corners.
    // =====================================================================
    class fifo_txn;
        rand bit                  wr_en;
        rand bit                  rd_en;
        rand bit [DATA_WIDTH-1:0] wr_data;

        // knob (not rand): the current write-vs-read bias, 0..100.
        int wr_bias = 50;

        // Weighted enables. dist gives "pick 1 with weight wr_bias, else 0".
        constraint c_bias {
            wr_en dist { 1 := wr_bias,       0 := (100 - wr_bias) };
            rd_en dist { 1 := (100-wr_bias), 0 := wr_bias         };
        }
    endclass

    // =====================================================================
    // Reference model + scoreboard state.
    //   ref_q  : the "golden" FIFO, a plain queue. push on accepted write,
    //            pop on accepted read.
    //   Because rd_data is REGISTERED (valid the cycle AFTER a pop), we pop the
    //   expected value when the read is accepted, stash it in `exp_data`, and
    //   compare one cycle later. Getting this 1-cycle offset right is the whole
    //   game -- a naive scoreboard that compares in the same cycle will report
    //   false failures.
    // =====================================================================
    logic [DATA_WIDTH-1:0] ref_q [$];   // SV queue: our software FIFO
    int errors  = 0;
    int n_write = 0, n_read = 0, n_simul = 0, n_drop = 0;

    // Pre-edge views of the accept logic (must match the RTL exactly).
    bit do_read, do_write;
    logic [DATA_WIDTH-1:0] exp_data;
    bit read_pending = 0;

    task automatic apply_reset();
        wr_en = 0; rd_en = 0; wr_data = 0; rst_n = 0;
        ref_q.delete();
        read_pending = 0;
        repeat (3) @(negedge clk);
        rst_n = 1;
        @(negedge clk);
        if (!(empty && count == 0))
            report_fail($sformatf("post-reset not empty: empty=%0b count=%0d",
                                  empty, count));
    endtask

    task automatic report_fail(string msg);
        $display("  [FAIL @ %0t] %s", $time, msg);
        errors++;
    endtask

    // The scoreboard step for ONE cycle. Called after enables are driven at
    // negedge (so full/empty reflect pre-edge occupancy), then it waits for the
    // posedge and checks the registered outputs.
    task automatic step_and_check();
        // Predict acceptance using the SAME conditions as the RTL, sampled
        // before the clock edge.
        do_read  = rd_en && !empty;
        do_write = wr_en && (!full || do_read);

        // Update the reference model to mirror the DUT.
        if (do_write) ref_q.push_back(wr_data);
        if (do_read)  begin exp_data = ref_q.pop_front(); read_pending = 1; end
        else          read_pending = 0;

        // bookkeeping for the summary / later coverage
        if (do_write && do_read) n_simul++;
        else if (do_write)       n_write++;
        else if (do_read)        n_read++;
        if (wr_en && full && !do_read) n_drop++;   // a write we correctly dropped

        // Advance one clock; rd_data updates on this edge.
        @(posedge clk);
        #1;  // let nonblocking updates settle before sampling

        // Check 1: popped data matches the golden queue.
        if (read_pending && (rd_data !== exp_data))
            report_fail($sformatf("data mismatch: got %02h expected %02h",
                                  rd_data, exp_data));

        // Check 2: occupancy matches the reference queue depth. This catches
        // off-by-one bugs in full/empty/count that the data check alone misses.
        if (count !== ref_q.size())
            report_fail($sformatf("count mismatch: dut=%0d ref=%0d",
                                  count, ref_q.size()));

        // Check 3: flags are consistent with count.
        if (full  !== (count == DEPTH)) report_fail("full flag inconsistent");
        if (empty !== (count == 0))     report_fail("empty flag inconsistent");
    endtask

    // =====================================================================
    // Main test
    // =====================================================================
    fifo_txn tr;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_fifo_random);

        tr = new();
        apply_reset();

        for (int i = 0; i < NUM_TXNS; i++) begin
            // Shift the write/read bias across the run so we sweep through
            // "mostly filling", "balanced", and "mostly draining" regimes --
            // this is what drives us into full AND empty repeatedly.
            if      (i < NUM_TXNS/3)   tr.wr_bias = 75;   // fill up, hit full
            else if (i < 2*NUM_TXNS/3) tr.wr_bias = 50;   // churn near middle
            else                       tr.wr_bias = 25;   // drain, hit empty

            if (!tr.randomize())
                report_fail("randomize() failed");

            @(negedge clk);              // drive stimulus for this cycle
            wr_en   = tr.wr_en;
            rd_en   = tr.rd_en;
            wr_data = tr.wr_data;

            step_and_check();            // predict + advance + self-check
        end

        // idle
        @(negedge clk); wr_en = 0; rd_en = 0;

        $display("\n===== RANDOM TEST SUMMARY =====");
        $display("  transactions      : %0d", NUM_TXNS);
        $display("  write-only cycles : %0d", n_write);
        $display("  read-only  cycles : %0d", n_read);
        $display("  simultaneous r+w  : %0d", n_simul);
        $display("  writes dropped    : %0d", n_drop);
        $display("  errors            : %0d", errors);
        if (errors == 0) $display("  RESULT: PASSED\n");
        else             $display("  RESULT: FAILED\n");
        $finish;
    end

    // Safety net: never hang forever.
    initial begin
        #2_000_000;
        $display("  [FAIL] global timeout");
        $finish;
    end

endmodule
