module bos_init #(
  parameter F_CLK = 16000000,
  parameter DELAY_MS = 1
)(
  input n_rst,
  input clk,
  
  input sdatao,
  output sdatai,
  output sck,
  output [9:0] sl,
  
  output init_done
);

localparam CNT_LIMIT = /*F_CLK * DELAY_MS / 1000 - 1*/99; // change to 99 for cozy debugging

wire n_cs;
reg [31:0] cnt_warm_up;
reg [3:0] cnt_bos;
wire [23:0] data;
wire busy;
reg [1:0] state;
reg ena;

localparam WARM_UP = 2'd0;
localparam INIT    = 2'd1;
localparam DONE    = 2'd2;
assign data[23] = 1'b0;                 // w/r
assign data[22:16] = 7'd3;              // address of reg
assign data[15:14] = 2'd0;              // rfu
assign data[13:0] = 14'b00111100000000; // data to reg
assign sl = (n_cs << cnt_bos - 1'b1) ~^ (1'b1 << cnt_bos - 1'b1); // demux with unselected outputs set to "1"
assign init_done = (state == DONE);

always @ (posedge clk or negedge n_rst)
  if (!n_rst)
    begin
    state <= WARM_UP;
    cnt_warm_up <= 0;
    cnt_bos <= 0;
    ena <= 0;
    end
  else
    case (state)
    WARM_UP:
      if (cnt_warm_up == CNT_LIMIT)
        begin
        cnt_warm_up <= 0;
        state <= INIT;
        end
      else
        cnt_warm_up <= cnt_warm_up + 1'b1;
    INIT:
      begin
      ena <= !busy & !ena & (cnt_bos < 10);
      if (!busy & !ena)
        begin
        if (cnt_bos < 10)
          cnt_bos <= cnt_bos + 1'b1;
        else
          begin
          cnt_bos <= 0;
          state <= DONE;
          end
        end
      end
    endcase


spi_master_reg #(
  .CPOL (1),
  .CPHA (1),
  .WIDTH (24),
  .PAUSE (6),  // if in_ena is continuing, pause will be + 1; if (in_ena <= !busy), pause will be + 2
  .BIDIR (0)
  //.SWAP_DIR_BIT_NUM (7)
)
spi_bos (
  .n_rst (n_rst),
  .sys_clk (clk),
  
  .sclk (sck),
  .miso (sdatao),
  .mosi (sdatai),
  .n_cs (n_cs),
  
  .in_data (data),
  .in_ena (ena),
  .busy (busy)
);



endmodule