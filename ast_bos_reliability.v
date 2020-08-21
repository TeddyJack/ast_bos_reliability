// in case of release change CNT_LIMIT values


module ast_bos_reliability (
  input clk_in, // 4 MHz
  input rst,
  
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
    
  output stby,
  output reg clk,
  output reg shp,
  output reg shd,
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
  output n_ldac  // same as output_update
);

assign rm_green[10:1] = 10'b0;
//assign rm_red[10:1] = increment[15:6];  // straight order
genvar i;
generate for (i = 1; i <= 10; i = i + 1)
  begin: bit_reverse
  assign rm_red[i] = increment[16 - i];
  end
endgenerate

assign n_ldac = 1'b1; // autoupdate is used
assign n_reset = 1'b1;
assign hd = 1'b0;
assign vd = 1'b0;
assign clpdm = 1'b1;
assign clpob = 1'b1;
assign pblk = 1'b1;
assign stby = 1'b0;
assign sckv = 1'b0;
assign slv = 1'b0;


localparam F_CLK = 4000000;  // the same value must be in PLL and in .sdc
localparam F_LED_x_2 = 1;
// change CNT_LIMIT to 99 for cozy debugging
localparam CNT_LIMIT = F_CLK / F_LED_x_2 - 1/*99*/; // (F_LED_x_2) because we should change data twice per period

wire sys_clk = clk_in;
reg [31:0] counter;
wire trigger = (counter == CNT_LIMIT);
reg spi_ena;
reg [15:0] dac_value;
reg [15:0] increment;
wire [23:0] spi_data;
wire init_done;
wire n_rst_fpga = rst;
wire [15:0] black_level = 16'd32767;


assign spi_data[23:20] = 4'b0011;
assign spi_data[19:4] = dac_value;
assign spi_data[3:0] = 4'b0;




always @ (posedge sys_clk or negedge n_rst_fpga)
  if (!n_rst_fpga)
    begin
    counter <= 0;
    increment <= 16'd0;
    end
  else if (init_done)
    begin
    if (trigger)
      begin
      counter <= 0;
      increment <= increment + 16'd4096;

      end
    else
      counter <= counter + 1'b1;
    end


reg [7:0] cnt;
localparam [7:0] DAC_CNT_LIMIT = 64;

always @ (posedge sys_clk or negedge n_rst_fpga)
  if (!n_rst_fpga)
    begin
    cnt <= 0;
    shp <= 1;
    shd <= 1;
    clk <= 0;
    spi_ena <= 0;
    end
  else if (init_done)
    begin
    if (cnt == DAC_CNT_LIMIT - 1'b1)
      cnt <= 0;
    else
      cnt <= cnt + 1'b1;
    
    if ((cnt == 0) | (cnt == DAC_CNT_LIMIT / 2)) clk <= ~clk;
    
    if ((cnt == DAC_CNT_LIMIT * 2 / 8) | (cnt == DAC_CNT_LIMIT * 3 / 8)) shp <= ~shp;

    if ((cnt == DAC_CNT_LIMIT * 6 / 8) | (cnt == DAC_CNT_LIMIT * 7 / 8)) shd <= ~shd;
    
    if (cnt == DAC_CNT_LIMIT * 0 / 8)
      dac_value <= increment;
    else if (cnt == DAC_CNT_LIMIT * 4 / 8)
      dac_value <= black_level;
    
    if ((cnt == DAC_CNT_LIMIT * 4 / 8) | (cnt == DAC_CNT_LIMIT * 0 / 8))
      spi_ena <= 1;
    else
      spi_ena <= 0;
      
    end


spi_master_reg #(
  .CPOL (1),
  .CPHA (1),
  .WIDTH (24),
  .PAUSE (3),  // if in_ena is continuing, pause will be + 1; if (in_ena <= !busy), pause will be + 2
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


endmodule