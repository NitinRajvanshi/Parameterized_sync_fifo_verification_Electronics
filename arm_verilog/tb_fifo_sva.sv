`timescale 1ns/1ps

module tb_fifo_sva;

    localparam DATA_WIDTH = 8;
    localparam DEPTH = 5;

    reg clk;
    reg rst_n;
    reg wr_en;
    reg rd_en;
    reg [DATA_WIDTH-1:0] wr_data;

    wire [DATA_WIDTH-1:0] rd_data;
    wire full;
    wire empty;
    wire [$clog2(DEPTH):0] count;

    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .wr_data(wr_data),
        .rd_data(rd_data),
        .full(full),
        .empty(empty),
        .count(count)
    );

    always #5 clk = ~clk;

    // Assertion 1: count must never exceed DEPTH
    property count_never_exceeds_depth;
        @(posedge clk)
        disable iff (!rst_n)
        count <= DEPTH;
    endproperty

    assert property (count_never_exceeds_depth)
        else $error("SVA FAILED: count exceeded DEPTH");

    initial begin
        clk = 0;
        rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        wr_data = 0;

        #20;
        rst_n = 1;

        // Fill FIFO
        repeat (DEPTH) begin
            @(negedge clk);
            wr_en = 1;
            wr_data = wr_data + 1;
        end

        @(negedge clk);
        wr_en = 0;

        #50;

        $finish;
    end

endmodule