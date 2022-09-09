`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps

module psram_tb;

  reg clk = 0;
  localparam period = 20;
  localparam half_period = period / 2;

  // PSRAM lines
  reg bank_sel = 0;
  reg [21:0] address;
  reg [15:0] data_in;
  reg [15:0] data_out;
  reg write_en;
  reg read_en;
  reg read_avail;

  // RAM lines
  wire [21:16] cram_a;
  wire [15:0] cram_dq;

  reg [15:0] cram_data_q_reg;
  reg cram_data_out = 0;

  assign cram_dq = cram_data_out ? cram_data_q_reg : 16'hZZ;

  wire cram_clk;
  wire cram_adv_n;
  wire cram_cre;
  wire cram_ce0_n;
  wire cram_ce1_n;
  wire cram_oe_n;
  wire cram_we_n;
  wire cram_ub_n;
  wire cram_lb_n;

  reg cram_wait;

  psram psram (
          .clk(clk),
          .bank_sel(bank_sel),
          .addr(address),
          .write_en(write_en),
          .read_en(read_en),
          .read_avail(read_avail),

          .data_in(data_in),
          .data_out(data_out),

          .cram_a(cram_a),
          .cram_dq(cram_dq),
          .cram_wait(cram_wait),
          .cram_clk(cram_clk),
          .cram_adv_n(cram_adv_n),
          .cram_cre(cram_cre),
          .cram_ce0_n(cram_ce0_n),
          .cram_ce1_n(cram_ce1_n),
          .cram_oe_n(cram_oe_n),
          .cram_we_n(cram_we_n),
          .cram_ub_n(cram_ub_n),
          .cram_lb_n(cram_lb_n)
        );

  always
  begin
    #half_period clk = ~clk;
  end

  initial
  begin
    // Constant assertions
    // assert property (!(~cram_ce0_n and ~cram_ce1_n)) else
    //            $error("Multiple banks selected");

    // Write initial data
    bank_sel = 0;
    address = 22'h2F0B00;
    write_en = 1;
    data_in = 16'hCCBB;

    #period;

    bank_sel = 1;
    address = 0;
    write_en = 0;
    data_in = 16'hFFFF;

    // Write init -> addr done
    assert (cram_ce0_n == 0) else
             $error("Did not set ce0");

    #period;

    // Write address done -> data
    assert (cram_a == 6'h2F) else
             $error("Did not set high address");
    assert (cram_dq == 16'h0B00) else
             $error("Did not set low address");
    assert (cram_adv_n == 0) else
             $error("Did not send adv low");

    #period;

    // Write data start -> data delay 1
    assert (cram_adv_n == 1) else
             $error("Did not send adv high");
    assert (cram_we_n == 0) else
             $error("Did not send we low");

    #(period * 4);

    // Write data delays -> data done
    assert (cram_dq == 16'hCCBB) else
             $error("Did not send data");

    assert (cram_ce0_n == 0) else
             $error("ce0 rose too early");

    #period;

    // write data done -> none
    assert (cram_we_n == 1) else
             $error("we didn't rise");

    assert (cram_ce0_n == 1) else
             $error("ce0 didn't rise");

    #(period * 10);

    // Read data

    bank_sel = 0;
    address = 22'h2F0B00;
    read_en = 1;

    #period;

    bank_sel = 1;
    address = 0;
    read_en = 0;

    // Read init -> addr hold
    assert (cram_ce0_n == 0) else
             $error("Did not set ce0");

    #period;

    // Read addr hold -> addr done
    assert (cram_adv_n == 0) else
             $error("Did not send adv low");

    #period;

    // Read addr done -> data delay 1
    assert (cram_adv_n == 1) else
             $error("Did not send adv high");

    assert (cram_a == 6'h2F) else
             $error("Did not set high address");
    assert (cram_dq == 16'h0B00) else
             $error("Did not set low address");

    #(period * 3);

    // Read data delays -> Read data delays
    assert (cram_oe_n == 0) else
             $error("Did not send oe low");

    assert (cram_ce0_n == 0) else
             $error("ce0 rose too early");

    #period;

    // Read data received -> none
    assert (cram_oe_n == 0) else
             $error("oe rose too early");

    cram_data_q_reg = 16'hABCD;
    cram_data_out = 1;
    #period;

    // none
    assert (cram_oe_n == 1) else
             $error("oe didn't rise");

    assert (cram_ce0_n == 1) else
             $error("ce0 didn't rise");

    assert (data_out == 16'hABCD) else
             $error("Did not receive read data");
    assert (read_avail == 1) else
             $error("Read data wasn't available");

    cram_data_out = 0;

    // #period;

    // // Read initial data
    // address = 0;
    // read_en = 0;

    // #period;

    // assert (data_out == 16'hCCBB) else
    //          $error("Could not read address 0");

    $stop;
  end

endmodule
