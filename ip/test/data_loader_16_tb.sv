`timescale 1 ns / 10 ps  // time-unit = 1 ns, precision = 10 ps

module data_loader_16_tb;
  reg clk_74a = 0;
  reg clk_memory = 0;

  localparam period = 20;
  localparam half_period = period / 2;

  localparam period_mem = 10;
  localparam half_period_mem = period_mem / 2;

  // APF bridge lines
  reg bridge_wr;
  reg bridge_endian_little;
  reg [31:0] bridge_addr;
  reg [31:0] bridge_wr_data;

  wire write_en;
  wire [14:0] write_addr;
  wire [15:0] write_data;

  data_loader #(.OUTPUT_WORD_SIZE(2)) data_loader (
      .clk_74a(clk_74a),
      .clk_memory(clk_memory),

      .bridge_wr(bridge_wr),
      .bridge_endian_little(bridge_endian_little),
      .bridge_addr(bridge_addr),
      .bridge_wr_data(bridge_wr_data),

      .write_en  (write_en),
      .write_addr(write_addr),
      .write_data(write_data)
  );

  task test_word(input [14:0] addr, input [15:0] data);
    begin
          assert (write_en == 1)
          else $error("write_en didn't go high");
          assert (write_addr == addr)
          else $error("write_addr wasn't 0x%h", addr);
          assert (write_data == data)
          else $error("write_data wasn't 0x%h", data);

          // We should continue seeing this data for 9 more cycles, with write_en dropping after 1
          #period_mem;

          assert (write_en == 0)
          else $error("write_en didn't drop");

          #(2 * period_mem);

          assert (write_en == 0)
          else $error("write_en didn't stay low");
    end
  endtask

  always begin
    #half_period clk_74a = ~clk_74a;
  end

  always begin
    #half_period_mem clk_memory = ~clk_memory;
  end

  initial begin
    bridge_wr = 0;
    bridge_endian_little = 0;
    bridge_addr = 0;
    bridge_wr_data = 0;

    #period;

    #(10 * period);

    // Nothing should be output
    assert (write_en == 0)
    else $error("write_en changed");

    $display("Sending first word");

    // Write first data
    bridge_wr = 1;
    bridge_addr = 32'hC;
    bridge_wr_data = 32'hAABBCCDD;

    #period;

    bridge_wr = 0;
    bridge_addr = 0;
    bridge_wr_data = 0;

    // Nothing should be output for several cycles
    assert (write_en == 0)
    else $error("write_en changed");

    // After 9 mem periods, we should start seeing data
    #(9 * period_mem);
    test_word(15'hC, 16'hBBAA);
  
    #period_mem;
    test_word(15'hE, 16'hDDCC);

    $display("Sending second word");

    #(2 * period);
    bridge_wr = 1;
    bridge_addr = 32'h20;
    bridge_wr_data = 32'hFFEEDDCC;

    #period;

    bridge_wr = 0;
    bridge_addr = 0;
    bridge_wr_data = 0;

    // Nothing should be output for several cycles
    assert (write_en == 0)
    else $error("write_en changed");

    // After 9 mem periods, we should start seeing data
    #(9 * period_mem);
    test_word(15'h20, 16'hEEFF);
  
    #period_mem;
    test_word(15'h22, 16'hCCDD);

    $stop;
  end
endmodule
