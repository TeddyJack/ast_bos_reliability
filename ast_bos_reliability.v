// in case of release change CNT_LIMIT values


module ast_bos_reliability (
  input clk_in, // 4 MHz
  
  output [10:1] rm_green, // if video spi data is okay, light leds green
  output [10:1] rm_red,
  
  // video_spi
  inout [10:1] sdatav,
  output [10:1] sckv,
  output [10:1] slv,
  
  // control spi
  input sdatao,
  output sdatai,
  output sck,
  output [10:1] sl,
  
  output rst,
  output stby,
  output clk,
  output shp,
  output shd,
  output hd,
  output vd,
  output clpdm,
  output clpob,
  output pblk,
  
  // goes to nanoDAC
  output sdi,
  output sclk,
  output n_sync,
  output n_reset,
  output n_ldac,  // same as output_update
  
  output my_sys_clk,
  output my_init_done
);

assign n_ldac = 1'b1; // autoupdate is used
assign clk = clk_in;
assign hd = 1'b0;
assign vd = 1'b0;
assign clpdm = 1'b1;
assign clpob = 1'b1;
assign pblk = 1'b1;


localparam F_CLK = 16000000;  // the same value must be in PLL and in .sdc
localparam F_LED_x_2 = 25;
// change CNT_LIMIT to 99 for cozy debugging
localparam CNT_LIMIT = /*F_CLK / F_LED_x_2 - 1*/99; // (F_LED_x_2) because we should change data twice per period

wire sys_clk;
reg [31:0] counter;
wire trigger = (counter == CNT_LIMIT);
reg spi_ena;
reg [15:0] dac_value;
wire [23:0] spi_data;
wire init_done;
wire n_rst_fpga;

assign spi_data[23:20] = 4'b0011;
assign spi_data[19:4] = dac_value;
assign spi_data[3:0] = 4'b0;




always @ (posedge sys_clk or negedge n_rst_fpga)
  if (!n_rst_fpga)
    counter <= 0;
  else if (init_done)
    begin
    if (trigger)
      counter <= 0;
    else
      counter <= counter + 1'b1;
    end


always @ (posedge sys_clk or negedge n_rst_fpga)
  if (!n_rst_fpga)
    begin
    spi_ena <= 0;
    dac_value <= 0;
    end
  else if (init_done)
    begin
    if (trigger)
      begin
      spi_ena <= 1;
      dac_value <= dac_value + 1'b1;
      end
    else
      spi_ena <= 0;
    end

// delay OUTPUT_UPDATE signal till the end of pause!!!!
spi_master_reg #(
  .CPOL (1),
  .CPHA (1),
  .WIDTH (24),
  .PAUSE (6),  // if in_ena is continuing, pause will be + 1; if (in_ena <= !busy), pause will be + 2
  .BIDIR (0)
)
spi_dac (
  .n_rst (n_rst_fpga),
  .sys_clk (sys_clk),
  
  .sclk (sclk),
  .mosi (sdi),
  .n_cs (n_sync),
  
  .in_data (spi_data),
  .in_ena (spi_ena),
  .busy ()
);



pll_main pll_main (
  .inclk0 (clk_in), // also BOS clk
  .c0 (sys_clk),    // also SPI clk
  .c1 (shp),
  .c2 (shd),
  .locked (n_rst_fpga)
);

bos_init #(
  .F_CLK (F_CLK),
  .DELAY_MS (1) // don't forget to uncomment inside
)
bos_init (
  .n_rst (n_rst_fpga),
  .clk (sys_clk),
  .sdatao (sdatao),
  .sdatai (sdatai),
  .sck (sck),
  .sl (sl),
  .init_done (init_done)
);

assign my_sys_clk = sys_clk;
assign my_init_done = init_done;

endmodule