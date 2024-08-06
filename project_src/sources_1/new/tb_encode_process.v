//~ `New testbench
`timescale  1ns / 1ps

module tb_encode_process;

// encode_process Parameters
parameter PERIOD      = 10 ;
parameter TCQ         = 0.1;
parameter ENCODE_WID  = 32 ;
parameter FIRST_DELTA_WENCODE = 4 ;
parameter FIRST_DELTA_XENCODE = 512   ;

// encode_process Inputs
reg   clk_i                                = 0 ;
reg   rst_i                                = 0 ;
reg   encode_update_i                      = 0 ;
reg   [ENCODE_WID-1:0]  encode_w_i         = 2000 ;
reg   [ENCODE_WID-1:0]  encode_x_i         = 2000 ;
reg                     encode_update_i_125    = 0;
reg   [ENCODE_WID-1:0]  encode_w_i_125         = 0;
reg   [ENCODE_WID-1:0]  encode_x_i_125         = 0;
reg encode_update_d0 ;
reg encode_update_d1 ;
// encode_process Outputs
wire  wafer_zero_flag_o                    ;
wire  precise_encode_en_o                  ;
wire  [ENCODE_WID-1:0]  precise_encode_w_o ;
wire  [ENCODE_WID-1:0]  precise_encode_x_o ;

reg clk_125 = 0;
initial
begin
    forever #(PERIOD/2)  clk_i=~clk_i;
end
initial
begin
    forever #(4/2)  clk_125=~clk_125;
end

initial
begin
    rst_i  =  1;
    #(PERIOD*2);
    rst_i  =  0;
end

encode_process #(
    .FIRST_DELTA_WENCODE        ( 0                     ),
    .FIRST_DELTA_XENCODE        ( 0                     ),
    .EXTEND_WIDTH               ( 20                    ),
    .UNIT_INTER                 ( 2500                  ), // 125M/50k
    .DELTA_UPDATE_DOT           ( 4                     ),
    .DELTA_UPDATE_GAP           ( 5                     ), // 125/5*4 = 100M
    .ENCODE_MASK_WID            ( 18                    ),
    .ENCODE_WID                 ( 32                    )
    )
 u_encode_process (
    .clk_i                   ( clk_125                                ),
    .rst_i                   ( rst_i                                ),
    .encode_update_i         ( encode_update_i                      ),
    .encode_w_i              ( encode_w_i          [ENCODE_WID-1:0] ),
    .encode_x_i              ( encode_x_i          [ENCODE_WID-1:0] ),

    .wafer_zero_flag_o       ( wafer_zero_flag_o                    ),
    .precise_encode_en_o     ( precise_encode_en_o                  ),
    .precise_encode_w_o      ( precise_encode_w_o  [ENCODE_WID-1:0] ),
    .precise_encode_x_o      ( precise_encode_x_o  [ENCODE_WID-1:0] )
);


reg [16-1:0] count = 'd0;
always @(posedge clk_125) begin
    if(count == 2500-1)
        count <= 'd0;
    else 
        count <= count + 1; 
end

always @(posedge clk_125) begin
    if(count == 1000)begin
        encode_update_i <= 'd1;
        encode_w_i      <= encode_w_i + FIRST_DELTA_WENCODE;
        encode_x_i      <= encode_x_i + FIRST_DELTA_XENCODE;
    end
    else begin
        encode_update_i <= 'd0;
    end
end


always @(posedge clk_125) begin
    encode_update_d0 <= encode_update_i;
    encode_update_d1 <= encode_update_d0;
    encode_w_i_125 <= encode_w_i;
    encode_x_i_125 <= encode_x_i;
end

initial
begin

    $finish;
end

endmodule