// A data loader for consuming APF bridge writes and directing them to some storage medium
//
// This takes the 32 bit words from APF, and splits it into four bytes. You can configure the cycle delay
// by setting WRITE_OUTPUT_CLOCK_DELAY
module data_loader_8
  # (
      // Upper 4 bits of address
      parameter ADDRESS_MASK_UPPER_4,
      parameter ADDRESS_SIZE = 14,
      // Number of clk_74a cycles to delay each write output. Allow up to 255 cycle delay
      // (though the APF will move data faster than that, so don't actually set the delay that high)
      parameter WRITE_OUTPUT_CLOCK_DELAY = 4
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
      output reg [7:0] write_data
    );

  reg [1:0] bridge_write_byte = 0;
  reg [7:0] bridge_write_delay_count = 0;

  reg [31:0] cached_addr;
  reg [7:0] cached_data [2:0];

  always @(posedge clk_74a)
  begin
    write_en <= 0;

    if(bridge_write_delay_count != 0)
    begin
      bridge_write_delay_count <= bridge_write_delay_count - 1;
    end

    if((bridge_wr && bridge_addr[31:28] == ADDRESS_MASK_UPPER_4) || (bridge_write_byte != 0 && bridge_write_delay_count == 0))
    begin
      reg [ADDRESS_SIZE:0] addr_temp;

      write_en <= 1;

      // TODO: Can this be removed?
      addr_temp = (bridge_write_byte != 0 ? cached_addr : bridge_addr);
      // write_addr <= {addr_temp[ADDRESS_SIZE - 2:0], bridge_write_byte};
      write_addr <= addr_temp + bridge_write_byte;

      if(bridge_write_byte != 0)
      begin
        // High 3 bytes
        // First byte in cache will have bridge_write_byte = 1
        write_data <= cached_data[bridge_write_byte - 1];

        bridge_write_delay_count <= WRITE_OUTPUT_CLOCK_DELAY;

        bridge_write_byte <= bridge_write_byte + 1;
      end
      else
      begin
        // First (low) byte
        write_data <= bridge_endian_little ? bridge_wr_data[7:0] : {bridge_wr_data[31:24]};

        // Set up buffered writes
        bridge_write_byte <= 1;
        bridge_write_delay_count <= WRITE_OUTPUT_CLOCK_DELAY;

        cached_addr <= bridge_addr;
        if(bridge_endian_little)
        begin
          cached_data[0] <= bridge_wr_data[15:8];
          cached_data[1] <= bridge_wr_data[23:16];
          cached_data[2] <= bridge_wr_data[31:24];
        end
        else
        begin
          cached_data[0] <= bridge_wr_data[23:16];
          cached_data[1] <= bridge_wr_data[15:8];
          cached_data[2] <= bridge_wr_data[7:0];
        end
      end
    end
  end

endmodule
