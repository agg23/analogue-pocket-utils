`timescale 1 ns / 10 ps  // time-unit = 1 ns, precision = 10 ps

module sync_fifo_tb;
  reg clk_write = 0;
  reg clk_read = 0;

  localparam period = 20;
  localparam half_period = period / 2;

  localparam period_read = 10;
  localparam half_period_read = period_read / 2;

  reg write_en;
  reg [31:0] data_in;
  wire [31:0] data_out;

  sync_fifo #(
      .WIDTH(32)
  ) sync_fifo (
      .clk_write(clk_write),
      .clk_read (clk_read),

      .write_en(write_en),
      .data_in (data_in),
      .data_out(data_out)
  );

  always begin
    #half_period clk_write = ~clk_write;
  end

  always begin
    #half_period_read clk_read = ~clk_read;
  end

  initial begin
    write_en = 0;
    data_in  = 0;

    #period;

    write_en = 1;
    data_in  = 32'hAABBCCDD;

    #period;

    write_en = 0;
    data_in  = 32'hFFFFFFFF;

    #(4 * period_read);

    // Empty should go low

    #(3 * period_read);
    // Data should be available
    assert (data_out == 'hAABBCCDD) else $error("data_out wasn't set");

    #(10 * period);

    // Data should still be available
    assert (data_out == 'hAABBCCDD) else $error("data_out wasn't held");

    // Write new data
    write_en = 1;
    data_in  = 32'hDDCCBBAA;

    #period;

    write_en = 0;
    data_in  = 32'hFFFFFFFF;

    #(6 * period_read);
    // Data should be available
    assert (data_out == 'hDDCCBBAA) else $error("data_out wasn't set");

    $stop;
  end
endmodule
