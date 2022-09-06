module psram (
    input wire clk,

    input wire bank_sel,
    input wire [21:0] addr,

    input wire write_en,
    input wire [15:0] data_in,

    input wire read_en,
    output reg read_avail,
    output reg [15:0] data_out,

    // PSRAM signals
    output reg [21:16] cram_a,
    inout wire [15:0] cram_dq,
    input wire cram_wait,
    output  reg cram_clk = 0,
    output  reg cram_adv_n = 1,
    output  reg cram_cre = 0,
    output  reg cram_ce0_n = 1,
    output  reg cram_ce1_n = 1,
    output  reg cram_oe_n = 1,
    output  reg cram_we_n = 1,
    output  reg cram_ub_n = 1,
    output  reg cram_lb_n = 1
  );

  localparam STATE_NONE = 0;

  localparam STATE_WRITE_INIT = 1;
  localparam STATE_WRITE_ADDRESS_DONE = 2;
  localparam STATE_WRITE_DATA_START = 3;
  localparam STATE_WRITE_DATA_DELAY_1 = 4;
  localparam STATE_WRITE_DATA_DELAY_2 = 5;
  localparam STATE_WRITE_DATA_DELAY_3 = 6;
  localparam STATE_WRITE_DATA_DONE = 7;

  localparam STATE_READ_INIT = 10;
  localparam STATE_READ_ADDRESS_HOLD = 11;
  localparam STATE_READ_ADDRESS_DONE = 12;
  localparam STATE_READ_DATA_DELAY_1 = 13;
  localparam STATE_READ_DATA_DELAY_2 = 14;
  localparam STATE_READ_DATA_DELAY_3 = 15;
  localparam STATE_READ_DATA_RECEIVED = 16;

  reg [4:0] state = STATE_NONE;

  // If 1, route cram_data reg to cram_dq
  reg data_out_en = 0;
  reg [15:0] cram_data;

  reg [15:0] latched_data_in;

  assign cram_dq = data_out_en ? cram_data : 16'hZZ;

  always @(posedge clk)
  begin
    case (state)
      STATE_NONE:
      begin
        read_avail <= 0;

        if (write_en)
        begin
          // Enter write_init
          state <= STATE_WRITE_INIT;

          if (bank_sel)
            cram_ce1_n <= 0;
          else
            cram_ce0_n <= 0;

          cram_a <= addr[21:16];
          cram_data <= addr[15:0];
          data_out_en <= 1;
          latched_data_in <= data_in;

          cram_ub_n <= 0;
          cram_lb_n <= 0;
        end
        else if (read_en)
        begin
          state <= STATE_READ_INIT;

          if (bank_sel)
            cram_ce1_n <= 0;
          else
            cram_ce0_n <= 0;

          cram_a <= addr[21:16];
          cram_data <= addr[15:0];
          data_out_en <= 1;

          cram_ub_n <= 0;
          cram_lb_n <= 0;
        end
      end

      // Writes
      STATE_WRITE_INIT:
      begin
        state <= STATE_WRITE_ADDRESS_DONE;

        // We're asserting the address, now we need to clock adv so the memory latches it
        cram_adv_n <= 0;
      end
      STATE_WRITE_ADDRESS_DONE:
      begin
        state <= STATE_WRITE_DATA_START;

        cram_adv_n <= 1;

        cram_we_n <= 0;
      end
      STATE_WRITE_DATA_START:
      begin
        state <= STATE_WRITE_DATA_DELAY_1;

        // Provide data to write
        data_out_en <= 1;
        cram_data <= latched_data_in;
      end
      STATE_WRITE_DATA_DELAY_1:
      begin
        state <= STATE_WRITE_DATA_DELAY_2;
      end
      STATE_WRITE_DATA_DELAY_2:
      begin
        state <= STATE_WRITE_DATA_DELAY_3;
      end
      STATE_WRITE_DATA_DELAY_3:
      begin
        state <= STATE_WRITE_DATA_DONE;
      end
      STATE_WRITE_DATA_DONE:
      begin
        state <= STATE_NONE;

        // Unlatch write enable and banks
        cram_we_n <= 1;

        cram_ce0_n <= 1;
        cram_ce1_n <= 1;

        cram_ub_n <= 1;
        cram_lb_n <= 1;
      end

      // Reads
      STATE_READ_INIT:
      begin
        state <= STATE_READ_ADDRESS_HOLD;

        // We're asserting the address, now we need to clock adv so the memory latches it
        cram_adv_n <= 0;
      end
      STATE_READ_ADDRESS_HOLD:
      begin
        state <= STATE_READ_ADDRESS_DONE;

        // Continue holding address after setting adv high
        cram_adv_n <= 1;
      end
      STATE_READ_ADDRESS_DONE:
      begin
        state <= STATE_READ_DATA_DELAY_1;

        // No longer sending data on cram_dq
        data_out_en <= 0;
      end
      STATE_READ_DATA_DELAY_1:
      begin
        state <= STATE_READ_DATA_DELAY_2;
      end
      STATE_READ_DATA_DELAY_2:
      begin
        state <= STATE_READ_DATA_DELAY_3;

        // Data should arrive in two states, enable output
        cram_oe_n <= 0;
      end
      STATE_READ_DATA_DELAY_3:
      begin
        state <= STATE_READ_DATA_RECEIVED;
      end
      STATE_READ_DATA_RECEIVED:
      begin
        state <= STATE_NONE;

        // Actually read data
        read_avail <= 1;
        data_out <= cram_dq;

        // We're done reading, clean up
        cram_ce0_n <= 1;
        cram_ce1_n <= 1;

        cram_ub_n <= 1;
        cram_lb_n <= 1;

        cram_oe_n <= 1;
      end
    endcase
  end

endmodule
