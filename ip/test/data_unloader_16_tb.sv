`timescale 1 ns / 10 ps  // time-unit = 1 ns, precision = 10 ps

module data_unloader_16_tb;
  reg clk_74a = 0;
  reg clk_memory = 0;

  localparam period = 20;
  localparam half_period = period / 2;

  localparam period_mem = 10;
  localparam half_period_mem = period_mem / 2;

  // APF bridge lines
  reg bridge_rd;
  reg bridge_endian_little;
  reg [31:0] bridge_addr;
  wire [31:0] bridge_rd_data;

  wire read_en;
  wire [27:0] read_addr;
  reg [15:0] read_data;

  data_unloader #(.INPUT_WORD_SIZE(2)) data_unloader (
      .clk_74a(clk_74a),
      .clk_memory(clk_memory),

      .bridge_rd(bridge_rd),
      .bridge_endian_little(bridge_endian_little),
      .bridge_addr(bridge_addr),
      .bridge_rd_data(bridge_rd_data),

      .read_en  (read_en),
      .read_addr(read_addr),
      .read_data(read_data)
  );

  task test_send_byte(input [27:0] addr, input [15:0] data);
    begin
      // Request memory data
      assert (read_en == 1)
      else $error("read_en didn't go high");

      assert (read_addr == addr)
      else $error("read_addr wasn't 0x%d", addr);

      // Send return data
      read_data = data;

      #period_mem;

      // Read assertion should fall
      assert (read_en == 0)
      else $error("read_en didn't fall");
    end
  endtask

  always begin
    #half_period clk_74a = ~clk_74a;
  end

  always begin
    #half_period_mem clk_memory = ~clk_memory;
  end

  initial begin
    bridge_rd = 0;
    bridge_endian_little = 1;
    bridge_addr = 0;

    #(10 * period);

    // Nothing should be output
    assert (read_en == 0)
    else $error("read_en changed");

    $display("Sending first request");

    // Write first data
    bridge_rd   = 1;
    bridge_addr = 32'hC;

    #period;

    bridge_rd   = 0;
    bridge_addr = 0;

    // Nothing should be output for several cycles
    assert (read_en == 0)
    else $error("read_en changed");

    #(9 * period_mem);

    // Address data should appear in memory domain and it should begin requesting the memory
    test_send_byte(28'hC, 16'hAABB);
    #(4 * period_mem);

    test_send_byte(28'hE, 16'hCCDD);
    #(4 * period_mem);

    // Data should be available for reading by APF
    #(5 * period);

    assert (bridge_rd_data == 32'hCCDDAABB)
    else $error("bridge_rd_data was not correct");

    // Data should be held until new data is provided
    #(20 * period);

    assert (bridge_rd_data == 32'hCCDDAABB)
    else $error("bridge_rd_data was not held");

    $display("Sending second request");

    // Write data
    bridge_rd   = 1;
    bridge_addr = 32'h124;

    #period;

    bridge_rd   = 0;
    bridge_addr = 0;

    // Nothing should be output for several cycles
    assert (read_en == 0)
    else $error("read_en changed");

    #(8 * period_mem);

    // Address data should appear in memory domain and it should begin requesting the memory
    test_send_byte(28'h124, 16'hBBAA);
    #(4 * period_mem);

    test_send_byte(28'h126, 16'hDDCC);
    #(4 * period_mem);

    // Data should be available for reading by APF
    #(5 * period);

    assert (bridge_rd_data == 32'hDDCCBBAA)
    else $error("bridge_rd_data was not correct");

    $stop;
  end

endmodule
