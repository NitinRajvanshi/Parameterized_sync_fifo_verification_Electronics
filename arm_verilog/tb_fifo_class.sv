`timescale 1ns/1ps

class fifo_transaction;

    rand bit        wr_en;
    rand bit        rd_en;
    rand bit [7:0]  wr_data;

    // Don't allow both operations to be disabled
    constraint valid_operation {
        wr_en || rd_en;
    }

    function void print();
        $display(
            "TRANSACTION: wr_en=%0b rd_en=%0b wr_data=%0d",
            wr_en,
            rd_en,
            wr_data
        );
    endfunction

endclass


module tb_fifo_class;

    fifo_transaction tr;

    initial begin

        tr = new();

        repeat (10) begin

            if (!tr.randomize()) begin
                $error("Randomization failed");
                $finish;
            end

            tr.print();

        end

        $finish;

    end

endmodule