
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.stop;

entity hex_loader_tb is
end entity;

-- A test bench for testing APF writes through the hex_loader component
architecture rtl of hex_loader_tb is
  signal clk : std_logic := '0';
  signal clk2 : std_logic := '0';

  signal bridge_wr : std_logic := '0';
  signal bridge_endian_little : std_logic := '0';
  signal bridge_addr : unsigned (31 downto 0);
  signal bridge_wr_data : unsigned (31 downto 0);

  signal write_addr : unsigned (14 downto 0) := 15b"0";
  signal address_b : unsigned (13 downto 0) := 14b"0";

  signal write_en : std_logic;
  signal write_data : unsigned (7 downto 0) := 8b"0";
  -- signal data_b : unsigned (15 downto 0) := 16b"0";

  signal output_a : unsigned (7 downto 0);
  signal output_b : unsigned (15 downto 0);

  signal hex_line : unsigned (8 * 44 - 1 downto 0);

  constant apf_word_time : time := 4000 ns;

  constant period : time := 140 ns;
  constant half_period : time := period / 2;

  constant period2 : time := 1000 ns;
  constant half_period2 : time := period2 / 2;

  -- From https://stackoverflow.com/a/22905922
  -- String to std_logic_vector convert in 8-bit format using character'pos(c)
  --
  -- Argument(s):
  -- - str: String to convert
  --
  -- Result: std_logic_vector(8 * str'length - 1 downto 0) with left-most
  -- character at MSBs.
  function to_slv(str : string; length : integer) return unsigned is
    alias str_norm : string(length downto 1) is str;
    variable res_v : unsigned(8 * length - 1 downto 0);
  begin
    for idx in str_norm'range loop
      res_v(8 * idx - 1 downto 8 * idx - 8) :=
      to_unsigned(character'pos(str_norm(idx)), 8);
    end loop;
    return res_v;
  end function;

  shared variable apf_write_buffer : unsigned (31 downto 0) := 32b"0";
  shared variable apf_write_buffer_fill : integer := 0;
begin
  clk <= not clk after half_period;
  clk2 <= not clk2 after half_period2;

  ROM : entity work.rom port map (
    address_a => write_addr,
    address_b => address_b,

    clock_a => clk,
    clock_b => clk2,

    data_a => write_data,
    data_b => 16b"0",
    wren_a => write_en,
    wren_b => '0',

    q_a => output_a,
    q_b => output_b
    );

  LOADER : entity work.hex_loader port map (
    clk_74a => clk,
    reset_n => '1',

    bridge_wr => bridge_wr,
    bridge_endian_little => bridge_endian_little,
    bridge_addr => bridge_addr,
    bridge_wr_data => bridge_wr_data,

    write_en => write_en,
    write_addr => write_addr,
    write_data => write_data
    );

  process
    -- Writes a 4 byte word to APF
    procedure apf_write_word(word : unsigned (31 downto 0)) is
    begin
      -- report "Sending 0x" & to_hstring(apf_write_buffer);

      bridge_wr <= '1';
      bridge_wr_data <= word;

      wait for period;

      bridge_wr <= '0';
      bridge_wr_data <= 32b"0";
      bridge_addr <= bridge_addr + 4;

      wait for apf_word_time;
    end procedure;

    -- Buffers a byte for writing to APF. Will send 4 byte word when full
    procedure apf_prepare_write_byte(byte : unsigned (7 downto 0)) is
    begin
      apf_write_buffer(7 downto 0) := byte;

      if apf_write_buffer_fill = 3 then
        apf_write_word(apf_write_buffer);

        apf_write_buffer_fill := 0;
        apf_write_buffer := 32b"0";
      else
        apf_write_buffer := shift_left(apf_write_buffer, 8);
        apf_write_buffer_fill := apf_write_buffer_fill + 1;
      end if;
    end procedure;

    -- Sends any buffered writes over APF
    procedure apf_finalize is
    begin
      if apf_write_buffer_fill > 0 then
        -- Unshift last shift
        apf_write_buffer := shift_right(apf_write_buffer, 8);
        apf_write_word(apf_write_buffer);
      end if;
    end procedure;

    -- Sends a hex line over APF
    procedure send_line(str : string; length : integer) is
      variable hex_line : unsigned (8 * length - 1 downto 0);
      variable acc : unsigned (31 downto 0);
      variable acc_fill : integer;
    begin
      report "Sending " & str;
      hex_line := to_slv(str, length);

      for i in length downto 1 loop
        apf_prepare_write_byte(hex_line(8 * i - 1 downto 8 * (i - 1)));
      end loop;
    end procedure;

    -- Convert ASCII byte into the actual nibble that the character represents
    function ascii_to_hex(ascii : unsigned (7 downto 0)) return unsigned is
      variable data : unsigned (7 downto 0);
    begin
      if ascii > 8x"40" then
        data := ascii - 8x"37";
      else
        data := ascii - 8x"30";
      end if;

      return data(3 downto 0);
    end function;

    function build_ascii_byte(data : string; offset : integer) return unsigned is
      variable acc : unsigned (7 downto 0);
    begin
      acc(7 downto 4) := ascii_to_hex(to_unsigned(character'pos(data(offset + 1)), 8));
      acc(3 downto 0) := ascii_to_hex(to_unsigned(character'pos(data(offset + 2)), 8));

      return acc;
    end function;

    -- Consumes four ASCII bytes and returns the two actual bytes the characters represent
    function build_ascii_two_byte_word(data : string; offset : integer) return unsigned is
      variable acc : unsigned (15 downto 0);
      variable acc_fill : integer;
    begin
      for i in 1 downto 0 loop
        acc(7 downto 0) := build_ascii_byte(data, offset + i * 2);

        if i = 1 then
          acc := shift_left(acc, 8);
        end if;
      end loop;

      return acc;
    end function;

    procedure create_send_hex(addr : unsigned (15 downto 0); data : string; length : integer) is
      variable hex : string (1 to 45);
      variable beginning : string (1 to 9);
      variable ending : string (1 to 4);
    begin
      -- Hack because VHDL strings are stupid
      for i in hex'range loop
        hex(i) := NUL;
      end loop;

      beginning := ":" & to_hstring(to_unsigned(length / 2, 8)) & to_hstring(addr) & "00";
      ending := "CC  ";

      for i in beginning'range loop
        hex(i) := beginning(i);
      end loop;

      for i in 1 to length loop
        hex(i + 9) := data(i);
      end loop;

      for i in 1 to 4 loop
        hex(i + 9 + length) := ending(i);
      end loop;

      send_line(hex, length + 9 + 4);
    end procedure;

    procedure verify(addr : unsigned (15 downto 0); data : string; length_arg : integer := 0) is
      alias data_norm : string(data'length downto 1) is data;
      variable length : integer;

      variable combined_bytes : unsigned (15 downto 0);
      variable i : integer := 0;
    begin
      if length_arg = 0 then
        -- Length of 0 indicates it's a literal, so use the string length
        length := data'length;
      else
        length := length_arg;
      end if;

      while i < length loop
        address_b <= addr(14 downto 1) + i / 4;
        wait for 3 * period2;

        -- combined_bytes(7 downto 0) := ascii_to_hex(to_unsigned(character'pos(data(i / 4)), 8));
        -- combined_bytes(15 downto 8) := ascii_to_hex(to_unsigned(character'pos(data(i / 4)), 8));
        combined_bytes := build_ascii_two_byte_word(data, i);
        assert output_b = combined_bytes
        report "Mismatch out: 0x" & to_hstring(output_b) & " expected: 0x" & to_hstring(combined_bytes) & " chars " & data_norm(i / 2 + 1) & data_norm(i / 2 + 2);

        i := i + 4;
      end loop;
    end procedure;

    -- Reads a hex file. If send_or_verify is true, send the data over APF, otherwise read the data and verify it
    procedure read_file(send_or_verify : boolean) is
      file file_handler : text open read_mode is "castleboy.hex";
      variable line_in : line;
      variable line_str : string (1 to 41);

      variable length_str : string (1 to 2);
      variable length : integer;

      variable addr_string : string (1 to 4);
      variable address : unsigned (15 downto 0);

      variable data : string (1 to 32);
      variable data_count : integer;
      variable char : character;

      variable i : integer;
      variable needs_data : boolean;
    begin
      while not endFile(file_handler) loop
        readline(file_handler, line_in);
        needs_data := true;

        i := 0;
        data_count := 0;

        while needs_data loop
          read(line_in, char);

          if i > 0 and i < 3 then
            length_str(i) := char;

            if i = 2 then
              length := to_integer(build_ascii_byte(length_str, 0));
            end if;
          elsif i > 2 and i < 7 then
            addr_string(i - 2) := char;
            -- Skip two for data type
          elsif i > 8 then
            data(i - 8) := char;

            data_count := data_count + 1;

            if data_count >= length * 2 then
              needs_data := false;
            end if;
          end if;

          i := i + 1;
        end loop;

        address := build_ascii_two_byte_word(addr_string, 0);
        -- Address is opposite ordering of data
        address := address(7 downto 0) & address(15 downto 8);

        if send_or_verify then
          create_send_hex(address, data, length * 2);
        else
          if length /= 0 then
            -- If length is empty, nothing to verify
            verify(address, data, length * 2);
          end if;
        end if;

        -- report length_str & " " & addr_string & " " & data;

        -- length := to_integer(build_ascii_two_byte_word(line_str, 1)(7 downto 0));
        -- address := build_ascii_two_byte_word(line_str, 3);

        -- address := address(7 downto 0) & address(15 downto 8);

        -- report to_hstring(to_unsigned(length, 8)) & " 0x" & to_hstring(address);
      end loop;
    end procedure;
  begin
    -- send_line(":100000000C942E150C9456150C9456150C945615EC   ");
    bridge_addr <= 32b"0";

    wait for period;

    read_file(true);

    apf_finalize;

    read_file(false);

    -- send_verify(16x"0000", "0C942E150C9456150C9456150C945615");
    -- send_verify(16x"0010", "0C9456150C9456150C9456150C945615");
    -- send_verify(16x"0000", "00112233445566778899AABBCCDDEEFF");
    -- send_verify(16x"0010", "00112233445566778899AABBCCDDEEFF");
    -- send_verify(16x"0010", "00112233445566778899AABBCCDDEEFF");

    -- apf_finalize;

    stop;
  end process;
end architecture;