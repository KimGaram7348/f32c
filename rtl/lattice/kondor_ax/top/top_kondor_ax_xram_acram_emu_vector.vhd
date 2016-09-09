-- (c)EMARD
-- License=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--library LatticeECP3;
--use LatticeECP3.components.all;

use work.f32c_pack.all;

entity kondor_ax is
  generic (
    -- ISA: either ARCH_MI32 or ARCH_RV32
    C_arch: integer := ARCH_MI32;
    C_debug: boolean := false;

    -- Main clock: 41, 81, 100 MHz
    C_clk_freq: integer := 100;

    -- SoC configuration options
    C_bram_size: integer := 2;
    C_acram: boolean := true;
    C_icache_size: integer := 2;
    C_dcache_size: integer := 2;
    C_sram8: boolean := false;
    C_branch_prediction: boolean := false;
    C_sio: integer := 2;
    C_spi: integer := 2;
    C_simple_io: boolean := true;
    C_gpio: integer := 32;
    C_gpio_pullup: boolean := false;
    C_gpio_adc: integer := 0; -- number of analog ports for ADC (on A0-A5 pins)

    C_vector: boolean := false; -- vector processor unit
    C_vector_axi: boolean := false; -- true: use AXI I/O, false use f32c RAM port I/O
    C_vector_registers: integer := 8; -- number of internal vector registers min 2, each takes 8K
    C_vector_vaddr_bits: integer := 11;
    C_vector_vdata_bits: integer := 32;
    C_vector_float_addsub: boolean := true; -- false will not have float addsub (+,-)
    C_vector_float_multiply: boolean := true; -- false will not have float multiply (*)
    C_vector_float_divide: boolean := true; -- false will not have float divide (/) will save much LUTs and DSPs

    -- video parameters common for vgahdmi and vgatext
    C_dvid_ddr: boolean := false; -- generate HDMI with DDR
    C_video_mode: integer := -1; -- 0:640x360, 1:640x480, 2:800x480, 3:800x600, 5:1024x768

    C_vgahdmi: boolean := false;
    C_vgahdmi_cache_size: integer := 8;
    -- normally this should be  actual bits per pixel
    C_vgahdmi_fifo_data_width: integer range 8 to 32 := 8;

    -- VGA textmode and graphics, full featured
    C_vgatext: boolean := false;    -- Xark's feature-rich bitmap+textmode VGA
    C_vgatext_label: string := "FleaFPGA-Uno f32c: 50MHz MIPS-compatible soft-core, 512KB SRAM";
    C_vgatext_bits: integer := 4;   -- 4096 possible colors
    C_vgatext_bram_mem: integer := 8;   -- 8KB text+font  memory
    C_vgatext_external_mem: integer := 0; -- 0KB external SRAM/SDRAM
    C_vgatext_reset: boolean := true;   -- reset registers to default with async reset
    C_vgatext_palette: boolean := true;  -- no color palette
    C_vgatext_text: boolean := true;    -- enable optional text generation
    C_vgatext_font_bram8: boolean := true;    -- font in separate bram8 file (for Lattice XP2 BRAM or non power-of-two BRAM sizes)
    C_vgatext_char_height: integer := 16;   -- character cell height
    C_vgatext_font_height: integer := 16;    -- font height
    C_vgatext_font_depth: integer := 8;     -- font char depth, 7=128 characters or 8=256 characters
    C_vgatext_font_linedouble: boolean := true;   -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)
    C_vgatext_font_widthdouble: boolean := false;   -- double font width by doubling each pixel (e.g., so 8 wide font is 16 wide cell)
    C_vgatext_monochrome: boolean := false;    -- true for 2-color text for whole screen, else additional color attribute byte per character
    C_vgatext_finescroll: boolean := true;   -- true for pixel level character scrolling and line length modulo
    C_vgatext_cursor: boolean := true;    -- true for optional text cursor
    C_vgatext_cursor_blink: boolean := true;    -- true for optional blinking text cursor
    C_vgatext_bus_read: boolean := true; -- true: allow reading vgatext BRAM from CPU bus (may affect fmax). false: write only
    C_vgatext_reg_read: boolean := false; -- true: allow reading vgatext BRAM from CPU bus (may affect fmax). false: write only
    C_vgatext_text_fifo: boolean := true;  -- disable text memory FIFO
      C_vgatext_text_fifo_step: integer := (82*2)/4; -- step for the FIFO refill and rewind
      C_vgatext_text_fifo_width: integer := 6;  -- width of FIFO address space (default=4) length = 2^width * 4 bytes
    C_vgatext_bitmap: boolean := true;     -- true for optional bitmap generation
    C_vgatext_bitmap_depth: integer := 8;   -- 8-bpp 16-color bitmap
    C_vgatext_bitmap_fifo: boolean := true;  -- disable bitmap FIFO
    -- step=horizontal width in pixels
    C_vgatext_bitmap_fifo_step: integer := 640;
    -- height=vertical height in pixels
    C_vgatext_bitmap_fifo_height: integer := 480;
    -- output data width 8bpp
    C_vgatext_bitmap_fifo_data_width: integer := 8; -- should be equal to bitmap depth
    -- bitmap width of FIFO address space length = 2^width * 4 byte
    C_vgatext_bitmap_fifo_addr_width: integer := 11
  );
  port (
  clk_100_p, clk_100_n: in std_logic;  -- main clock input from 100MHz clock source
  cy_clkout: in std_logic;  -- cypress CPU clock, firmware configurable 12/24/48MHz clock source

  -- UART0 (USB slave serial)
  tx: out   std_logic;
  rx: in    std_logic;

  --LVDS_Red    : out   std_logic;
  --LVDS_Green  : out   std_logic;
  --LVDS_Blue   : out   std_logic;
  --LVDS_ck     : out   std_logic;

  led: out std_logic_vector(7 downto 0)
  --btn, dip: in std_logic_vector(3 downto 0);

  -- SD card
  --sd_dat3_csn, sd_cmd_di, sd_dat0_do, sd_dat1_irq, sd_dat2: inout std_logic;
  --sd_clk, sd_pwrn: out std_logic;
  --sd_cdn, sd_wp: in std_logic;

  -- SPI1 to Flash ROM
  --flash_miso   : in      std_logic;
  --flash_mosi   : out     std_logic;
  --flash_clk    : out     std_logic;
  --flash_csn    : out     std_logic
  );
end;

architecture Behavioral of kondor_ax is
  component ILVDS
    port (A, AN: in std_logic; Z: out  std_logic);
  end component;

  signal clk, rs232_break, rs232_break2: std_logic;
  signal clk_100: std_logic;
  signal clk_dvi, clk_dvin, clk_pixel: std_logic;
  signal ram_en             : std_logic;
  signal ram_byte_we        : std_logic_vector(3 downto 0) := (others => '0');
  signal ram_address        : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_write     : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_read      : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_ready          : std_logic;
  signal dvid_red, dvid_green, dvid_blue, dvid_clock: std_logic_vector(1 downto 0);
  signal R_blinky: std_logic_vector(26 downto 0);
  
  -- dummy signals for spi and buttons
  signal btn, dip: std_logic_vector(3 downto 0);

  -- SD card
  signal sd_dat3_csn, sd_cmd_di, sd_dat0_do, sd_dat1_irq, sd_dat2: std_logic;
  signal sd_clk, sd_pwrn: std_logic;
  signal sd_cdn, sd_wp: std_logic;

  -- SPI1 to Flash ROM
  signal flash_miso: std_logic;
  signal flash_mosi: std_logic;
  signal flash_clk: std_logic;
  signal flash_csn: std_logic;
begin
  -- convert external differential clock input to internal single ended clock
  clock_diff2se:
  ILVDS port map(A=>clk_100_p, AN=>clk_100_n, Z=>clk_100);

  video_mode_none: if C_clk_freq=100 and C_video_mode=-1 generate
    clk <= clk_100;
  end generate;

  -- full featured XRAM glue
  glue_xram: entity work.glue_xram
  generic map (
    C_arch => C_arch,
    C_clk_freq => C_clk_freq,
    C_bram_size => C_bram_size,
    C_acram => C_acram,
    C_icache_size => C_icache_size,
    C_dcache_size => C_dcache_size,
    C_sram8 => C_sram8,
    C_debug => C_debug,
    C_sio => C_sio,
    C_spi => C_spi,
    C_gpio => C_gpio,
    C_gpio_pullup => C_gpio_pullup,
    C_gpio_adc => C_gpio_adc,
    C_branch_prediction => C_branch_prediction,

    C_vector => C_vector,
    C_vector_axi => C_vector_axi,
    C_vector_registers => C_vector_registers,
    C_vector_vaddr_bits => C_vector_vaddr_bits,
    C_vector_vdata_bits => C_vector_vdata_bits,
    C_vector_float_addsub => C_vector_float_addsub,
    C_vector_float_multiply => C_vector_float_multiply,
    C_vector_float_divide => C_vector_float_divide,

    C_dvid_ddr => C_dvid_ddr,
    -- vga simple compositing bitmap only graphics
    C_vgahdmi => C_vgahdmi,
      C_vgahdmi_mode => C_video_mode,
      C_vgahdmi_cache_size => C_vgahdmi_cache_size,
      C_vgahdmi_fifo_data_width => C_vgahdmi_fifo_data_width,
    -- vga textmode + bitmap full feature graphics
    C_vgatext => C_vgatext,
        C_vgatext_label => C_vgatext_label,
        C_vgatext_mode => C_video_mode,
        C_vgatext_bits => C_vgatext_bits,
        C_vgatext_bram_mem => C_vgatext_bram_mem,
        C_vgatext_external_mem => C_vgatext_external_mem,
        C_vgatext_reset => C_vgatext_reset,
        C_vgatext_palette => C_vgatext_palette,
        C_vgatext_bus_read => C_vgatext_bus_read,
        C_vgatext_reg_read => C_vgatext_reg_read,
        C_vgatext_text => C_vgatext_text,
        C_vgatext_font_bram8 => C_vgatext_font_bram8,
        C_vgatext_text_fifo => C_vgatext_text_fifo,
        C_vgatext_text_fifo_step => C_vgatext_text_fifo_step,
        C_vgatext_text_fifo_width => C_vgatext_text_fifo_width,
        C_vgatext_char_height => C_vgatext_char_height,
        C_vgatext_font_height => C_vgatext_font_height,
        C_vgatext_font_depth => C_vgatext_font_depth,
        C_vgatext_font_linedouble => C_vgatext_font_linedouble,
        C_vgatext_font_widthdouble => C_vgatext_font_widthdouble,
        C_vgatext_monochrome => C_vgatext_monochrome,
        C_vgatext_finescroll => C_vgatext_finescroll,
        C_vgatext_cursor => C_vgatext_cursor,
        C_vgatext_cursor_blink => C_vgatext_cursor_blink,
        C_vgatext_bitmap => C_vgatext_bitmap,
        C_vgatext_bitmap_depth => C_vgatext_bitmap_depth,
        C_vgatext_bitmap_fifo => C_vgatext_bitmap_fifo,
        C_vgatext_bitmap_fifo_step => C_vgatext_bitmap_fifo_step,
        C_vgatext_bitmap_fifo_addr_width => C_vgatext_bitmap_fifo_addr_width,
        C_vgatext_bitmap_fifo_data_width => C_vgatext_bitmap_fifo_data_width
  )
  port map (
    clk => clk,
    clk_pixel => clk_pixel,
    clk_pixel_shift => clk_dvi,
    sio_rxd(0) => rx,
    --sio_rxd(1) => open,
    sio_txd(0) => tx,
    --sio_txd(1) => open,
    sio_break(0) => rs232_break,
    sio_break(1) => rs232_break2,

    spi_sck(0)  => flash_clk,  spi_sck(1)  => sd_clk,
    spi_ss(0)   => flash_csn,  spi_ss(1)   => sd_dat3_csn,
    spi_mosi(0) => flash_mosi, spi_mosi(1) => sd_cmd_di,
    spi_miso(0) => flash_miso, spi_miso(1) => sd_dat0_do,

    gpio(127 downto 0) => open,

    simple_out(7 downto 0) => led(7 downto 0),
    simple_out(31 downto 8) => open,
    simple_in(3 downto 0) => btn,
    simple_in(19 downto 16) => dip,

    acram_addr(16 downto 2) => ram_address(16 downto 2),
    acram_data_wr => ram_data_write,
    acram_data_rd => ram_data_read,
    acram_byte_we => ram_byte_we,
    acram_ready => ram_ready,
    acram_en => ram_en,

    dvid_red   => dvid_red,
    dvid_green => dvid_green,
    dvid_blue  => dvid_blue,
    dvid_clock => dvid_clock
  );

  acram_emulation: entity work.acram_emu
  generic map
  (
      C_addr_width => 15
  )
  port map
  (
      clk => clk,
      acram_a => ram_address(16 downto 2),
      acram_d_wr => ram_data_write,
      acram_d_rd => ram_data_read,
      acram_byte_we => ram_byte_we,
      acram_ready => ram_ready,
      acram_en => ram_en
  );

  -- vendor specific modules to
  -- convert single ended DDR to phyisical output signals
  --G_vgatext_ddrout: entity work.ddr_dvid_out_se
  --port map (
  --  clk       => clk_dvi,
  --  clk_n     => clk_dvin,
  --  in_red    => dvid_red,
  --  in_green  => dvid_green,
  --  in_blue   => dvid_blue,
  --  in_clock  => dvid_clock,
  --  out_red   => LVDS_Red,
  --  out_green => LVDS_Green,
  --  out_blue  => LVDS_Blue,
  --  out_clock => LVDS_ck
  --);
  
  -- clock alive blinky
  process(clk)
  begin
      if rising_edge(clk) then
        R_blinky <= R_blinky+1;
      end if;
  end process;
  -- led(7) <= R_blinky(R_blinky'high);
  
end Behavioral;
