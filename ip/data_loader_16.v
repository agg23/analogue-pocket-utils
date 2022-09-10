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

// NOTE: The data loader 8 is more up to date than this component at the moment.
// I recommend you look at it instead
//
// A data loader for consuming APF bridge writes and directing them to some storage medium
//
// This takes the 32 bit words from APF, and splits it into two 16 bit words
module data_loader_16
  # (
      // Upper 4 bits of address
      parameter ADDRESS_MASK_UPPER_4,
      parameter ADDRESS_SIZE = 13
    )
    (
      // TODO: The memory isn't necessarily clocked at 74MHz. A second clock should be used and synced
      input wire clk_74a,

      input wire bridge_wr,
      input wire bridge_endian_little,
      input wire [31:0] bridge_addr,
      input wire [31:0] bridge_wr_data,

      output reg write_en,
      output reg [ADDRESS_SIZE:0] write_addr,
      output reg [15:0] write_data
    );

  reg bridge_write_high = 0;
  reg [31:0] cached_addr;
  reg [15:0] cached_data;

  always @(posedge clk_74a)
  begin
    write_en <= 0;

    if((bridge_wr && bridge_addr[31:28] == ADDRESS_MASK_UPPER_4) || bridge_write_high)
    begin
      reg [14:0] addr_temp;
      reg [13:0] addr;

      write_en <= 1;

      // TODO: Can this be removed?
      addr_temp = (bridge_write_high ? cached_addr : bridge_addr);
      // Address (every 4 bytes) mod 2
      write_addr <= {addr_temp[14:2], bridge_write_high};

      if(bridge_write_high)
      begin
        // High 2 bytes
        cached_addr <= 0;
        write_data <= cached_data;
      end
      else
      begin
        // Low 2 bytes
        write_data <= bridge_endian_little ? bridge_wr_data[15:0] : {bridge_wr_data[23:16], bridge_wr_data[31:24]};

        cached_addr <= bridge_addr;
        cached_data <= bridge_endian_little ? bridge_wr_data[31:16] : {bridge_wr_data[7:0], bridge_wr_data[15:8]};
      end

      bridge_write_high <= ~bridge_write_high;
    end
  end

endmodule
