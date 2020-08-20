module spi_master_reg #(
  parameter [0:0] CPOL = 1,
  parameter [0:0] CPHA = 0,
  parameter [7:0] WIDTH = 24,
  parameter [2:0] PAUSE = 3,  // if in_ena is continuing, pause will be + 1; if (in_ena <= !busy), pause will be + 2
  parameter [0:0] BIDIR = 1,
  parameter [7:0] SWAP_DIR_BIT_NUM = 7,   // after which bit (count from 0) high_z sets to "1"
  parameter [0:0] SCLK_CONST = 0
)(
  input                  n_rst,
       
  input                  sys_clk,
  output                 sclk,
  input                  miso,
  output                 mosi,
  output                 n_cs,
  inout                  sdio,
  output                 io_update,
  
  input      [WIDTH-1:0] in_data,
  input                  in_ena,
  output reg             busy,
  
  output reg [WIDTH-1:0] miso_reg,
  output reg             miso_reg_ena
);



reg [WIDTH-1:0] mosi_reg;
reg [7:0] bit_cnt;
reg [2:0] pause_cnt;
reg n_cs_neg; // n_cs, clocked always on negedge
reg n_cs_pha; // n_cs, clocked on edge depending (CPOL == CPHA)
wire miso_int;
wire mosi_int = mosi_reg[WIDTH-1];
wire load_cond = !busy & in_ena;
wire eoframe_cond = (bit_cnt == WIDTH - 1'b1);
assign n_cs = n_cs_neg & n_cs_pha;
reg io_update_reg;
assign io_update = io_update_reg;

generate
  if(SCLK_CONST)
    assign sclk = CPOL ? !sys_clk : sys_clk;
  else
    assign sclk = n_cs_neg ? CPOL : (CPOL ? !sys_clk : sys_clk);
endgenerate



always @ (negedge sys_clk or negedge n_rst)
  if (!n_rst)
    n_cs_neg <= 1;
  else
    begin
    if (n_cs_neg)
      n_cs_neg <= !load_cond;
    else
      n_cs_neg <= eoframe_cond;
    end



generate
  if (CPOL == CPHA)
    begin
    always@(negedge sys_clk or negedge n_rst)
      if(!n_rst)
        begin
        bit_cnt <= 0;
        n_cs_pha <= 1;
        mosi_reg <= 0;
        pause_cnt <= 0;
        busy <= 0;
        io_update_reg <= 0;
        end
      else
        begin
        if(!busy)
          busy <= in_ena;
        else
          busy <= !n_cs_pha | (pause_cnt != PAUSE - 1'b1);
        
        if(n_cs_pha)
          begin
          n_cs_pha <= !load_cond;
          bit_cnt <= 0;
          io_update_reg <= (pause_cnt == PAUSE - 2'd2);
          end
        else
          begin
          n_cs_pha <= eoframe_cond;
          bit_cnt <= bit_cnt + 1'b1;
          end
        
        if(load_cond)
          mosi_reg <= in_data;
        else
          mosi_reg <= mosi_reg << 1;
          
        if(eoframe_cond)
          pause_cnt <= 0;
        else if(pause_cnt != PAUSE - 1'b1)
          pause_cnt <= pause_cnt + 1'b1;
        end
    
    always@(posedge sys_clk or negedge n_rst)
      if(!n_rst)
        begin
        miso_reg <= 0;
        miso_reg_ena <= 0;
        end
      else
        begin
        if(!n_cs_pha)
          begin
          miso_reg[0] <= miso_int;
          miso_reg[WIDTH-1:1] <= miso_reg[WIDTH-2:0];
          end
        
        miso_reg_ena <= eoframe_cond;
        end
    end
  else  // posedge
    begin
    always@(posedge sys_clk or negedge n_rst)
      if(!n_rst)
        begin
        bit_cnt <= 0;
        n_cs_pha <= 1;
        mosi_reg <= 0;
        pause_cnt <= 0;
        busy <= 0;
        io_update_reg <= 0;
        end
      else
        begin
        if(!busy)
          busy <= in_ena;
        else
          busy <= !n_cs_pha | (pause_cnt != PAUSE - 1'b1);
        
        if(n_cs_pha)
          begin
          n_cs_pha <= !load_cond;
          bit_cnt <= 0;
          io_update_reg <= (pause_cnt == PAUSE - 2'd2);
          end
        else
          begin
          n_cs_pha <= eoframe_cond;
          bit_cnt <= bit_cnt + 1'b1;
          end
        
        if(load_cond)
          mosi_reg <= in_data;
        else
          mosi_reg <= mosi_reg << 1;
          
        if(eoframe_cond)
          pause_cnt <= 0;
        else if(pause_cnt != PAUSE - 1'b1)
          pause_cnt <= pause_cnt + 1'b1;
        end
    
    always@(negedge sys_clk or negedge n_rst)
      if(!n_rst)
        begin
        miso_reg <= 0;
        miso_reg_ena <= 0;
        end
      else
        begin
        if(!n_cs_pha)
          begin
          miso_reg[0] <= miso_int;
          miso_reg[WIDTH-1:1] <= miso_reg[WIDTH-2:0];
          end
        
        miso_reg_ena <= eoframe_cond;
        end
    end
endgenerate




generate
  if (BIDIR)
    begin
    reg read;
    reg [7:0] z_cnt;
    //reg io_update_reg;
    //wire high_z = read & (z_cnt > SWAP_DIR_BIT_NUM);
    reg high_z;
   
    assign sdio = high_z ? 1'bz : mosi_int;
    assign miso_int = sdio;
    assign mosi = 0;
    //assign io_update = io_update_reg;

    if (CPOL == CPHA)
      always @ (negedge sys_clk or negedge n_rst)
        if (!n_rst)
          begin
          z_cnt <= 0;
          read <= 0;
          //io_update_reg <= 0;
          high_z <= 0;
          end
        else
          if (n_cs_pha)
            begin
            z_cnt <= 0;
            read <= 0;
            //io_update_reg <= 0;
            high_z <= 0;
            end
          else
            begin
            z_cnt <= z_cnt + 1'b1;
            //io_update_reg <= eoframe_cond & !read;
            if (z_cnt == 1'b0)
              read <= mosi_int;
            if ((z_cnt == SWAP_DIR_BIT_NUM) & read)
              high_z <= 1;
            end
    else
      always @ (posedge sys_clk or negedge n_rst)
        if (!n_rst)
          begin
          z_cnt <= 0;
          read <= 0;
          //io_update_reg <= 0;
          high_z <= 0;
          end
        else
          if (n_cs_pha)
            begin
            z_cnt <= 0;
            read <= 0;
            //io_update_reg <= 0;
            high_z <= 0;
            end
          else
            begin
            z_cnt <= z_cnt + 1'b1;
            //io_update_reg <= eoframe_cond & !read;
            if (z_cnt == 1'b0)
              read <= mosi_int;
            if ((z_cnt == SWAP_DIR_BIT_NUM) & read)
              high_z <= 1;
            end
    end
  else
    begin
    assign mosi = mosi_int;
    assign miso_int = miso;
    //assign io_update = 0;
    end
endgenerate


endmodule