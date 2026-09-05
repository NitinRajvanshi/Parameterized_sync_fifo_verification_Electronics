// ============================================================================
// fifo.v  -  Parameterizable synchronous FIFO (First-In-First-Out buffer)
// ----------------------------------------------------------------------------
// Plain Verilog-2001 so it runs on any simulator (Icarus, Verilator, etc.).
//
//   DATA_WIDTH : width of each stored word, in bits.
//   DEPTH      : number of words the FIFO can hold. Need NOT be a power of two,
//                because we track occupancy with a counter rather than by
//                comparing wrapped pointers.
//
// Interface (all synchronous to the rising edge of clk):
//   wr_en / wr_data : request to push wr_data this cycle.
//   rd_en           : request to pop this cycle.
//   rd_data         : the popped word. Registered => valid the cycle AFTER a
//                     successful pop (this 1-cycle read latency matters for the
//                     testbench, see README).
//   full  / empty   : occupancy flags.
//   count           : current number of stored words (handy for debug/coverage).
//
// Edge-case policy:
//   * Write while full  -> ignored (data dropped, no corruption).
//   * Read  while empty -> ignored (rd_data holds its previous value).
//   * Simultaneous read+write:
//       - when neither full nor empty : both happen, count unchanged.
//       - when full  : read frees a slot, so the write is ALSO accepted
//                       (count stays == DEPTH). This is the tricky case.
//       - when empty : nothing to read, so only the write happens.
// ============================================================================
module fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16
) (
    input                        clk,
    input                        rst_n,     // active-low synchronous reset
    input                        wr_en,
    input      [DATA_WIDTH-1:0]  wr_data,
    input                        rd_en,
    output reg [DATA_WIDTH-1:0]  rd_data,
    output                       full,
    output                       empty,
    // count needs enough bits to represent the value DEPTH itself (0..DEPTH),
    // so it is one bit wider than an address. Sized inline with $clog2 because
    // the ADDR_WIDTH localparam below is not visible up here in the port list.
    output reg [$clog2(DEPTH):0] count
);

    // clog2 so DEPTH need not be a power of two. ADDR_WIDTH addresses DEPTH
    // words. Guard DEPTH<=1 so the address bus is never zero-width.
    localparam ADDR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    // Decide what actually happens this cycle. A write is accepted if the FIFO
    // isn't full, OR a simultaneous read is making room.
    wire do_read  = rd_en && !empty;
    wire do_write = wr_en && (!full || do_read);

    // Pointer that wraps at DEPTH (works for non-power-of-two depths too).
    // Note DEPTH-1 wrap rather than relying on natural counter overflow.
    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (do_write) begin
            mem[wr_ptr] <= wr_data;
            wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1'b1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rd_ptr  <= 0;
            rd_data <= 0;
        end else if (do_read) begin
            rd_data <= mem[rd_ptr];
            rd_ptr  <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1'b1;
        end
    end

    // Occupancy counter. Only changes when exactly one of read/write fires.
    always @(posedge clk) begin
        if (!rst_n) begin
            count <= 0;
        end else begin
            case ({do_write, do_read})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: count <= count;   // 00 (idle) or 11 (simultaneous)
            endcase
        end
    end

endmodule
