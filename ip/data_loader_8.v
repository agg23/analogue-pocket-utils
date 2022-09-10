// MIT License

// Copyright (c) 2022 Adam Gastineau

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
////////////////////////////////////////////////////////////////////////////////

// A data loader for consuming APF bridge writes and directing them to some storage medium
//
// This takes the 32 bit words from APF, and splits it into four bytes. You can configure the cycle delay
// by setting WRITE_OUTPUT_CLOCK_DELAY
module data_loader_8 #(
    // Upper 4 bits of address
    parameter ADDRESS_MASK_UPPER_4,
    parameter ADDRESS_SIZE = 14,
    // Number of clk_74a cycles to delay each write output. Allow up to 255 cycle delay
    // (though the APF will move data faster than that, so don't actually set the delay that high)
    parameter WRITE_OUTPUT_MAIN_CLOCK_DELAY = 10
) (
    input wire clk_74a,
    input wire clk_memory,

    input wire bridge_wr,
    input wire bridge_endian_little,
    input wire [31:0] bridge_addr,
    input wire [31:0] bridge_wr_data,

    // These outputs are synced to the memory clock
    output wire write_en,
    output wire [ADDRESS_SIZE:0] write_addr,
    output wire [7:0] write_data
);

  localparam WRITE_EN_LENGTH = WRITE_OUTPUT_MAIN_CLOCK_DELAY / 2;

  // Output without sync
  reg int_write_en;
  reg [ADDRESS_SIZE:0] int_write_addr;
  reg [7:0] int_write_data;

  synch_3 en_s (
      int_write_en,
      write_en,
      clk_memory
  );

  synch_3 #(
      .WIDTH(ADDRESS_SIZE + 1)
  ) addr_s (
      int_write_addr,
      write_addr,
      clk_memory
  );

  synch_3 #(
      .WIDTH(8)
  ) data_s (
      int_write_data,
      write_data,
      clk_memory
  );

  reg [1:0] bridge_write_byte = 0;
  reg [7:0] bridge_write_delay_count = 0;

  reg [31:0] cached_addr;
  reg [7:0] cached_data[2:0];

  always @(posedge clk_74a) begin
    if (bridge_write_delay_count < WRITE_EN_LENGTH) begin
      // Leave write_en on for WRITE_EN_LENGTH
      int_write_en <= 0;
    end

    if (bridge_write_delay_count != 0) begin
      bridge_write_delay_count <= bridge_write_delay_count - 1;
    end

    if((bridge_wr && bridge_addr[31:28] == ADDRESS_MASK_UPPER_4) || (bridge_write_byte != 0 && bridge_write_delay_count == 0))
    begin
      reg [ADDRESS_SIZE:0] addr_temp;

      int_write_en <= 1;

      // TODO: Can this be removed?
      addr_temp = (bridge_write_byte != 0 ? cached_addr : bridge_addr);
      int_write_addr <= addr_temp + bridge_write_byte;

      if (bridge_write_byte != 0) begin
        // High 3 bytes
        // First byte in cache will have bridge_write_byte = 1
        int_write_data <= cached_data[bridge_write_byte-1];

        bridge_write_delay_count <= WRITE_OUTPUT_MAIN_CLOCK_DELAY;

        bridge_write_byte <= bridge_write_byte + 1;
      end else begin
        // First (low) byte
        int_write_data <= bridge_endian_little ? bridge_wr_data[7:0] : {bridge_wr_data[31:24]};

        // Set up buffered writes
        bridge_write_byte <= 1;
        bridge_write_delay_count <= WRITE_OUTPUT_MAIN_CLOCK_DELAY;

        cached_addr <= bridge_addr;
        if (bridge_endian_little) begin
          cached_data[0] <= bridge_wr_data[15:8];
          cached_data[1] <= bridge_wr_data[23:16];
          cached_data[2] <= bridge_wr_data[31:24];
        end else begin
          cached_data[0] <= bridge_wr_data[23:16];
          cached_data[1] <= bridge_wr_data[15:8];
          cached_data[2] <= bridge_wr_data[7:0];
        end
      end
    end
  end

endmodule
