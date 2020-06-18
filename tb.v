`timescale 1 ns / 1 ns  // timescale units / timescale precision
`define TUPS 1000000000 // timescale units per second. if 1 ns then TUPS = 10^9
`define CLK_IN 4  // in MHz
`define SYS_CLK 16 // in MHz

module tb();

reg clk_in;
reg n_rst;
reg sdatao;

wire sdatai;
wire sck;
wire [10:1] sl;

wire sdi;
wire sclk;
wire n_sync;
wire n_reset;
wire n_ldac;

wire clk;
wire shd;
wire shp;

wire my_sys_clk;
wire my_init_done;


ast_bos_reliability i1 (
  .clk_in (clk_in),
  //.n_rst_fpga (n_rst),
  .sdatao (sdatao),
  .sdatai (sdatai),
  .sck (sck),
  .sl (sl),
  .sdi (sdi),
  .sclk (sclk),
  .n_sync (n_sync),
  .n_reset (n_reset),
  .n_ldac (n_ldac),
  .clk (clk),
  .shd (shd),
  .shp (shp),
  .my_sys_clk (my_sys_clk),
  .my_init_done (my_init_done)
);


integer CLK_IN_HALF = `TUPS / (`CLK_IN * 1000000) / 2;
integer SYS_CLK_T = `TUPS / (`SYS_CLK * 1000000);

always #CLK_IN_HALF clk_in = !clk_in;




initial                                                
  begin
  clk_in = 1;
  //n_rst = 0;
  sdatao = 0;
  
  #(SYS_CLK_T/4)  // initial offset to 1/4 of period for easier clocking
 
  #(10*SYS_CLK_T)
  
  //n_rst = 1;
  
  #(2000*SYS_CLK_T);
  
  $display("Testbench end");
  $stop();
  end




endmodule