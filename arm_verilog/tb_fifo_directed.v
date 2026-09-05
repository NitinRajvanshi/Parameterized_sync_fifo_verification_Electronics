// ============================================================================
// tb_fifo_directed.v  -  Step 1 smoke test for fifo.v
// ----------------------------------------------------------------------------
// Not the real verification env (that comes later, in SystemVerilog). This is
// a hand-written directed test that walks through the behaviors we care about
// so we can eyeball that the RTL is sane before building the random env:
//   1. reset -> empty
//   2. fill to full, confirm `full` asserts and extra writes are dropped
//   3. drain to empty, confirm data comes out in order (FIFO!) and `empty`
//   4. a simultaneous read+write while full (the tricky edge case)
//
// Uses a small DEPTH so the full/empty corners are quick to hit.
// ============================================================================
`timescale 1ns/1ps
module tb_fifo_directed;

    localparam DATA_WIDTH = 8;
    localparam DEPTH      = 4;

    reg                   clk = 0, rst_n, wr_en, rd_en;
    reg  [DATA_WIDTH-1:0] wr_data;
    wire [DATA_WIDTH-1:0] rd_data;
    wire                  full, empty;
    wire [$clog2(DEPTH):0] count;

    integer errors = 0;

    fifo #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) dut (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en), .wr_data(wr_data),
        .rd_en(rd_en), .rd_data(rd_data),
        .full(full), .empty(empty), .count(count)
    );

    always #5 clk = ~clk;   // 100 MHz

    // Simple check helper.
    task check(input cond, input [255:0] msg);
        begin
            if (!cond) begin
                $display("  [FAIL] %0s (time=%0t)", msg, $time);
                errors = errors + 1;
            end else begin
                $display("  [ok]   %0s", msg);
            end
        end
    endtask

    // Push one word (assumes not full).
    task push(input [DATA_WIDTH-1:0] d);
        begin
            @(negedge clk); wr_en = 1; wr_data = d; rd_en = 0;
            @(negedge clk); wr_en = 0;
        end
    endtask

    initial begin
        wr_en = 0; rd_en = 0; wr_data = 0; rst_n = 0;
        repeat (2) @(negedge clk);
        rst_n = 1;

        // 1. reset -> empty
        check(empty && !full && count==0, "after reset: empty, count 0");

        // 2. fill to full
        push(8'hA0); push(8'hA1); push(8'hA2); push(8'hA3);
        check(full && count==DEPTH, "after 4 pushes: full");

        // extra write while full must be dropped
        push(8'hFF);
        check(full && count==DEPTH, "write-while-full dropped, still full");

        // 3. drain, expect A0..A3 in order (1-cycle read latency: sample the
        //    cycle after asserting rd_en).
        @(negedge clk); rd_en = 1; wr_en = 0;
        @(negedge clk); check(rd_data==8'hA0, "pop #1 == A0");
        @(negedge clk); check(rd_data==8'hA1, "pop #2 == A1");
        @(negedge clk); check(rd_data==8'hA2, "pop #3 == A2");
        @(negedge clk); rd_en = 0;
        check(rd_data==8'hA3, "pop #4 == A3");
        check(empty && count==0, "after draining: empty");

        // 4. simultaneous read+write while full: count must stay at DEPTH.
        push(8'hB0); push(8'hB1); push(8'hB2); push(8'hB3);
        check(full, "refilled to full");
        @(negedge clk); wr_en = 1; rd_en = 1; wr_data = 8'hC0;
        @(negedge clk); wr_en = 0; rd_en = 0;
        check(count==DEPTH, "simultaneous r+w while full keeps count==DEPTH");
        check(rd_data==8'hB0, "simultaneous r+w popped B0");

        if (errors == 0) $display("\nDIRECTED TEST PASSED\n");
        else             $display("\nDIRECTED TEST FAILED: %0d error(s)\n", errors);
        $finish;
    end

endmodule
