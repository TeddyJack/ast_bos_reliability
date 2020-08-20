// in case of release change CNT_LIMIT values


module ast_bos_reliability (
  input clk_in, // 4 MHz
  input reset_button,
  
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

assign rm_green[10:1] = /*dac_value[9:0]*/10'b0;
assign rm_red[10:1] = /*dac_value[9:0]*/10'b0;

assign n_ldac = 1'b1; // autoupdate is used
assign n_reset = 1'b1;
assign clk = clk_in;
assign hd = 1'b0;
assign vd = 1'b0;
assign clpdm = 1'b1;
assign clpob = 1'b1;
assign pblk = 1'b1;
assign rst = 1'b1;
assign stby = 1'b0;


localparam F_CLK = 4000000;  // the same value must be in PLL and in .sdc
localparam F_LED_x_2 = 2000;
// change CNT_LIMIT to 99 for cozy debugging
localparam CNT_LIMIT = F_CLK / F_LED_x_2 - 1/*99*/; // (F_LED_x_2) because we should change data twice per period

wire sys_clk = clk_in;
reg [31:0] counter;
wire trigger = (counter == CNT_LIMIT);
reg spi_ena;
reg [15:0] dac_value;
//reg right_shift;
wire [23:0] spi_data;
wire init_done;
wire n_rst_fpga = reset_button;
//wire [15:0] black_level = 16'd32767;


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
    dac_value <= /*11'd1*/1'b0;
    //right_shift <= 0;
    end
  else if (init_done)
    begin
    if (trigger)
      begin
      spi_ena <= 1;
      dac_value <= dac_value + 1'b1;
      //if (right_shift)
      //  begin
      //  if (dac_value[0]) right_shift <= 0;
      //  else dac_value <= dac_value >> 1;
      //  end
      //else
      //  begin
      //  if (dac_value[11]) right_shift <= 1;
      //  else dac_value <= dac_value << 1;
      //  end
      end
    else
      spi_ena <= 0;
    end

// delay OUTPUT_UPDATE signal till the end of pause!!!!
spi_master_reg #(
  .CPOL (1),    // according to waveforms, CPOL = 1, CPHA = 1
  .CPHA (1),
  .WIDTH (24),
  .PAUSE (5),  // if in_ena is continuing, pause will be + 1; if (in_ena <= !busy), pause will be + 2
  .BIDIR (0),
  .SCLK_CONST (0)
)
spi_dac (
  .n_rst (n_rst_fpga),
  .sys_clk (sys_clk),
  
  .sclk (sclk),
  .mosi (sdi),
  .n_cs (n_sync),
  
  .in_data (spi_data),
  .in_ena (spi_ena)
);



pll_main pll_main (
  .inclk0 (clk_in), // also BOS clk
  .c0 (/*sys_clk*/),    // also SPI clk
  .c1 (shp),
  .c2 (shd),
  .locked (/*n_rst_fpga*/)
);

bos_init #(
  .F_CLK (F_CLK),
  .DELAY_MS (50) // don't forget to uncomment inside
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