`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: zas
// Engineer: songyuxin
// 
// Create Date: 2023/08/06
// Design Name: PCG1
// Module Name: startup_ctrl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// 初始化配置 read configuration register
// 写入前擦除flash对应位置，禁止擦除golden部分
// 每擦除一个block读取一次状态寄存器，异常或结束上报，输出register
// 输入multiboot program数据  以512*16为package
// 返回写入falsh 完成或者pack cnt错误
// 读取flash接口，只支持完整读取golden 和 multiboot 内容
//
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module startup_ctrl #(
    parameter                           TCQ         = 0.1   ,
    parameter                           DATA_WIDTH  = 16    ,
    parameter                           ADDR_WIDTH  = 27    
)(
    // clk & rst
    input                               clk_i               ,  // 125MHz
    input                               rst_i               ,

    // startup
    input                               startup_rst_i       ,
    input                               startup_finish_i    ,
    input                               startup_i           ,
    input   [16-1:0]                    startup_pack_i      ,
    input                               startup_vld_i       ,
    input   [DATA_WIDTH*2-1:0]          startup_data_i      ,
    output  [2-1:0]                     startup_ack_o       ,
    output  [16-1:0]                    startup_last_pack_o ,

    // erase flash
    input                               erase_multiboot_i   ,
    output                              erase_ack_o         ,
    output  [8-1:0]                     erase_status_reg_o  ,

    // read flash
    input                               flash_rd_start_i    ,
    output                              flash_rd_valid_o    ,
    output  [DATA_WIDTH-1:0]            flash_rd_data_o     ,

    // flash interface
    input   [DATA_WIDTH-1:0]            flash_data_i        ,
    output  [DATA_WIDTH-1:0]            flash_data_o        ,
    output  [ADDR_WIDTH-1:0]            flash_addr_o        ,
    output                              WE_B                ,  // write enable
    output                              ADV_B               ,
    output                              OE_B                ,  // read enable
    output                              CE_B                ,  // chip enable
    input                               WAIT                ,
    output                              CLK                    // 31.25MHz
);


//////////////////////////////////////////////////////////////////////////////////
// *********** Define Parameter Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
localparam                      ST_IDLE             = 4'd0;
localparam                      ST_ERASE            = 4'd1;
localparam                      ST_ERASE_WAIT       = 4'd2;
localparam                      ST_READ_STATUS      = 4'd3;
localparam                      ST_CLR_STATUS       = 4'd4;
localparam                      ST_ERASE_END        = 4'd5;
localparam                      ST_BLOCK_UNLOCK     = 4'd13;
localparam                      ST_CHECK_STATUS     = 4'd14;
// localparam                      ST_READ_ID          = 4'd15;

localparam                      ST_STARTUP          = 4'd6;
localparam                      ST_PROGRAM          = 4'd7;
localparam                      ST_STARTUP_WAIT     = 4'd8;
localparam                      ST_STARTUP_ERR      = 4'd9;

localparam                      ST_READ             = 4'd10;
localparam                      ST_READ_WAIT        = 4'd11;
localparam                      ST_READ_END         = 4'd12;

// localparam                      READ_CFG_REG        = 16'b1111_0010_1001_1110;
localparam                      READ_CFG_REG        = 16'b0011_1001_0100_1111;
localparam                      BLOCK_LENG          = 'h1_0000;     // 64k Word
localparam  [ADDR_WIDTH-1:0]    MULTIBOOT_ADDR      = 'h30_0000;    // 3M Word
localparam                      WRITE_PACK_LENG     = 'h200;        // 512 burst

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Register Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
reg     [ 4-1:0]                state               = ST_IDLE;
reg     [ 4-1:0]                state_next          = ST_IDLE;

reg                             init_set_rcr        = 'd0;
reg     [16-1:0]                init_wait_cnt       = 'd0;
reg                             init_set_rcr_d      = 'd0;
reg                             set_cfg_en          = 'd0;

reg     [ADDR_WIDTH-1:0]        erase_addr          = 'd0;
reg     [12-1:0]                erase_wait_cnt      = 'd0;
reg                             unit_ms_tick        = 'd0;
reg     [17-1:0]                unit_ms_cnt         = 'd0;
reg     [8-1:0]                 status_reg          = 'd0;
reg                             erase_ack           = 'd0;
reg     [8-1:0]                 erase_status_reg    = 'd0;

reg     [16-1:0]                startup_pack_cnt    = 'd0;
reg     [10-1:0]                program_cnt         = 'd0;
reg     [ADDR_WIDTH-1:0]        write_addr          = 'd0;
reg     [2-1:0]                 startup_ack         = 'd0;
reg     [16-1:0]                startup_last_pack   = 'd0;
reg                             startup_rst_r       = 'd0;

reg                             startup_rd_ready    = 'd0;
reg                             startup_rd_cnt      = 'd0;
reg                             program_finish      = 'd1;
reg     [DATA_WIDTH*2-1:0]      startup_rd_data_r   = 'd0;

reg     [10-1:0]                read_cnt            = 'd0;
reg     [ADDR_WIDTH-1:0]        read_addr           = 'd0;
reg     [16-1:0]                read_wait_cnt       = 'd0;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Wire Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
wire                            status_valid        ;
wire    [8-1:0]                 status_data         ;

wire                            erase_en            ;
wire                            unlock_block_en     ;
wire                            rd_status_en        ;
wire                            clr_status_reg_en   ;
wire                            read_start          ;
wire                            read_array_en       ;

wire                            write_burst_finish  ;
wire                            write_start         ;
wire    [DATA_WIDTH-1:0]        startup_rd_data     ;
wire                            startup_rd_en_temp  ;
wire    [DATA_WIDTH*2-1:0]      startup_rd_data_temp ;
wire                            startup_fifo_rst    ;
wire                            start_fifo_full     ;
wire                            start_fifo_prog_empty;
wire                            start_fifo_empty    ;
wire                            start_fifo_sbiterr  ;
wire                            start_fifo_dbiterr  ;

wire                            startup_rd_en       ;
wire                            flash_busy          ;

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Instance Module
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
flash_drive #(
    .TCQ                    ( TCQ                       ),
    .WR_LENGTH              ( WRITE_PACK_LENG           ),
    .DATA_WIDTH             ( DATA_WIDTH                ),
    .ADDR_WIDTH             ( ADDR_WIDTH                ))
flash_drive_inst (
    // clk & rst
    .clk_i                  ( clk_i                     ),
    .rst_i                  ( rst_i                     ),

    // flash control command
    .write_burst_finish_i   ( write_burst_finish        ),
    .write_start_i          ( write_start               ),
    .write_addr_i           ( write_addr                ),
    .write_rd_en_o          ( startup_rd_en             ),
    .write_data_i           ( startup_rd_data           ),

    .read_array_en_i        ( read_array_en             ),
    .erase_en_i             ( erase_en                  ),
    .erase_addr_i           ( erase_addr                ),
    .unlock_block_en_i      ( unlock_block_en           ),
    // .read_id_en_i           ( read_id_en                ),
    // .unlock_block_succ_o    ( unlock_block_succ         ),
    // .unlock_block_fail_o    ( unlock_block_fail         ),
    
    .rd_status_en_i         ( rd_status_en              ),
    .status_valid_o         ( status_valid              ),
    .status_reg_o           ( status_data               ),

    .clr_status_reg_en_i    ( clr_status_reg_en         ),

    .set_cfg_en_i           ( set_cfg_en                ),
    .set_cfg_reg_i          ( READ_CFG_REG              ),

    .read_start_i           ( read_start                ),
    .read_addr_i            ( read_addr                 ),
    .read_valid_o           ( flash_rd_valid_o          ),
    .read_data_o            ( flash_rd_data_o           ),

    // flash status
    .flash_busy_o           ( flash_busy                ),

    // flash interface
    .flash_data_i           ( flash_data_i              ),
    .flash_data_o           ( flash_data_o              ),
    .flash_addr_o           ( flash_addr_o              ),
    .WE_B                   ( WE_B                      ),
    .ADV_B                  ( ADV_B                     ),
    .OE_B                   ( OE_B                      ),
    .CE_B                   ( CE_B                      ),
    .WAIT                   ( WAIT                      ),
    .CLK                    ( CLK                       )
);

startup_fifo startup_fifo_wr_inst(
    .clk                    ( clk_i                     ),
    .srst                   ( rst_i || startup_fifo_rst ),
    .din                    ( startup_data_i            ),
    .wr_en                  ( startup_vld_i             ),
    .rd_en                  ( startup_rd_en_temp        ),
    .dout                   ( startup_rd_data_temp      ),
    .prog_empty             ( start_fifo_prog_empty     ),
    .full                   ( start_fifo_full           ),
    .empty                  ( start_fifo_empty          ),
    .sbiterr                ( start_fifo_sbiterr        ),
    .dbiterr                ( start_fifo_dbiterr        )
);

// 包装一个预读出控制
always @(posedge clk_i) begin
    if(rst_i || startup_fifo_rst)
        startup_rd_ready <= 'd0;
    else 
        startup_rd_ready <= ~start_fifo_empty;
end

always @(posedge clk_i) begin
    if(rst_i || startup_fifo_rst)
        program_finish <= 'd1;
    else if(program_finish && startup_rd_en_temp)
        program_finish <= 'd0;
    else if(~program_finish && startup_rd_en && (startup_rd_cnt==1))
        program_finish <= 'd1;
end

assign startup_rd_en_temp = startup_rd_ready && program_finish;

always @(posedge clk_i) begin
    if(program_finish)
        startup_rd_cnt <= 'd0;
    else if(startup_rd_en)
        startup_rd_cnt <= startup_rd_cnt + 1;
end

always @(posedge clk_i) begin
    if(startup_rd_en_temp)
        startup_rd_data_r <= {startup_rd_data_temp[23:16],startup_rd_data_temp[31:24],startup_rd_data_temp[7:0],startup_rd_data_temp[15:8]};
        // startup_rd_data_r <= startup_rd_data_temp;
    else if(startup_rd_en)
        startup_rd_data_r <= {startup_rd_data_r[DATA_WIDTH-1:0],{DATA_WIDTH{1'b0}}};
end

assign startup_rd_data = startup_rd_data_r[DATA_WIDTH*2-1:DATA_WIDTH];

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Logic Design
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
always @(posedge clk_i) begin
    if(rst_i)begin
        init_set_rcr <= #TCQ 'd0;
    end
    `ifdef SIMULATE
    else if(init_wait_cnt == 'd6)begin // wait 60us
    `else
    else if(init_wait_cnt == 'd60000)begin // wait 60us
    `endif // SIMULATE
        init_set_rcr  <= #TCQ 'd1;
        init_wait_cnt <= #TCQ init_wait_cnt; 
    end
    else begin
        init_set_rcr  <= #TCQ 'd0;
        init_wait_cnt <= #TCQ init_wait_cnt + 1;
    end 
end

always @(posedge clk_i) begin
    init_set_rcr_d  <= #TCQ init_set_rcr;
    set_cfg_en      <= #TCQ ~init_set_rcr_d && init_set_rcr;
end

always @(posedge clk_i) begin
    if(rst_i)
        state <= #TCQ ST_IDLE;
    else 
        state <= #TCQ state_next;
end

always @(*) begin
    state_next = state;
    case (state)
        ST_IDLE: begin
            if(init_set_rcr && erase_multiboot_i)
                state_next = ST_ERASE;
            else if(init_set_rcr && startup_i && startup_pack_i=='d0)
                state_next = ST_STARTUP;
            else if(init_set_rcr && flash_rd_start_i)
                state_next = ST_READ;
        end 

        // >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> erase
        ST_ERASE: begin
            if(erase_addr >= {MULTIBOOT_ADDR,1'b0})
                state_next = ST_ERASE_END;
            else if(~flash_busy)
                state_next = ST_CLR_STATUS;
        end

        ST_CLR_STATUS: begin
            if(~flash_busy)
                state_next = ST_ERASE_WAIT;
        end

        ST_ERASE_WAIT: begin
            if(~flash_busy && erase_wait_cnt=='d100)
                state_next = ST_READ_STATUS;
        end

        ST_READ_STATUS: begin
            if(~flash_busy)
                state_next = ST_CHECK_STATUS;
        end

        ST_CHECK_STATUS: begin
            if(~status_reg[7])
                state_next = ST_ERASE_WAIT;
            else if(status_reg=='h80)
                state_next = ST_ERASE;
            else if(status_reg[1])
                state_next = ST_BLOCK_UNLOCK;
            else if(|status_reg[5:4])
                state_next = ST_ERASE_END;
        end


        ST_BLOCK_UNLOCK: begin
            if(~flash_busy)
                state_next = ST_ERASE;
        end
        
        // ST_READ_ID: begin
        //     if(unlock_block_succ)
        //         state_next = ST_ERASE;
        //     else if(unlock_block_fail)
        //         state_next = ST_ERASE_END;
        // end

        ST_ERASE_END: begin
            if(~flash_busy)
                state_next = ST_IDLE;
        end

        // >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> startup
        ST_STARTUP: begin
            if(startup_pack_cnt != startup_pack_i)
                state_next = ST_STARTUP_ERR;
            else if(~flash_busy && ~start_fifo_prog_empty)
                state_next = ST_PROGRAM;
        end

        ST_PROGRAM: begin
            if(program_cnt[9])  // 512
                state_next = ST_STARTUP_WAIT;
        end

        ST_STARTUP_WAIT: begin
            if(startup_rst_r)
                state_next = ST_IDLE;
            else if(startup_finish_i && startup_pack_i==(startup_pack_cnt-1))
                state_next = ST_IDLE;
            else if(startup_finish_i && startup_pack_i!=(startup_pack_cnt-1))
                state_next = ST_STARTUP_ERR;
            else if(startup_i)
                state_next = ST_STARTUP;
        end

        ST_STARTUP_ERR: begin
            state_next = ST_IDLE;
        end

        // >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> read
        ST_READ: begin
            if(~flash_busy)
                state_next = ST_READ_WAIT;
        end

        ST_READ_WAIT: begin
            if(read_cnt==WRITE_PACK_LENG)
                state_next = ST_READ_END;
        end

        ST_READ_END: begin
            if(read_addr>={MULTIBOOT_ADDR,1'b0})
                state_next = ST_IDLE;
            else if(read_wait_cnt>='d25000)
                state_next = ST_READ;
        end
        default: ;
    endcase
end

// unit time = 1ms
always @(posedge clk_i) begin
    if(state==ST_ERASE_WAIT)begin
        if(unit_ms_cnt == 'd124_999)begin
            unit_ms_cnt  <= #TCQ 'd0;
            unit_ms_tick <= #TCQ 'd1;
        end
        else begin
            unit_ms_cnt  <= #TCQ unit_ms_cnt + 1; 
            unit_ms_tick <= #TCQ 'd0;
        end
    end
    else begin
        unit_ms_cnt  <= #TCQ 'd0;
        unit_ms_tick <= #TCQ 'd0;
    end
end

// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> erase
always @(posedge clk_i) begin
    if(state==ST_ERASE_WAIT)begin
        if(unit_ms_tick)
            erase_wait_cnt <= #TCQ erase_wait_cnt + 1;
    end
    else 
        erase_wait_cnt <= #TCQ 'd0;
end

always @(posedge clk_i) begin
    if(state==ST_IDLE && state_next==ST_ERASE)begin
        erase_addr  <= MULTIBOOT_ADDR;
    end
    else if(state==ST_CHECK_STATUS && state_next==ST_ERASE)begin
        erase_addr  <= erase_addr + BLOCK_LENG;
    end
end

always @(posedge clk_i) begin
    if(state == ST_READ_STATUS && status_valid)
        status_reg <= #TCQ status_data;
end

always @(posedge clk_i) begin
    if(state==ST_ERASE_END && ~flash_busy)begin
        erase_ack        <= #TCQ 'd1;
        erase_status_reg <= #TCQ status_reg;
    end
    else begin
        erase_ack        <= #TCQ 'd0;
    end
end

assign erase_en             = state==ST_CLR_STATUS    && state_next==ST_ERASE_WAIT;
assign unlock_block_en      = state==ST_CHECK_STATUS  && state_next==ST_BLOCK_UNLOCK;
assign rd_status_en         = state==ST_ERASE_WAIT    && state_next==ST_READ_STATUS;
assign clr_status_reg_en    = state==ST_ERASE         && state_next==ST_CLR_STATUS;
assign read_array_en        = (state==ST_ERASE        && state_next==ST_ERASE_END) || (state==ST_STARTUP_WAIT && state_next==ST_IDLE);
assign erase_ack_o          = erase_ack       ;
assign erase_status_reg_o   = erase_status_reg;

// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> program
always @(posedge clk_i) begin
    if(state==ST_PROGRAM)begin
        if(startup_rd_en)
            program_cnt <= #TCQ program_cnt + 1;
    end
    else begin
        program_cnt <= #TCQ 'd0;
    end
end

always @(posedge clk_i) begin
    if(state==ST_IDLE)
        startup_pack_cnt <= #TCQ 'd0;
    else if(state==ST_PROGRAM && state_next==ST_STARTUP_WAIT)
        startup_pack_cnt <= #TCQ startup_pack_cnt + 1;
end

always @(posedge clk_i) begin
    if(state==ST_IDLE)
        write_addr <= #TCQ MULTIBOOT_ADDR;
    else if(state==ST_PROGRAM && state_next==ST_STARTUP_WAIT)
        write_addr <= #TCQ write_addr + WRITE_PACK_LENG;
end

always @(posedge clk_i) begin
    if(state==ST_IDLE)
        startup_rst_r <= #TCQ 'd0;
    else if(startup_rst_i)
        startup_rst_r <= #TCQ 'd1; 
end

always @(posedge clk_i) begin
    if(state==ST_PROGRAM && state_next==ST_STARTUP_WAIT)begin
        startup_ack[0]      <= #TCQ 'd1;
        startup_last_pack   <= #TCQ startup_pack_cnt;
    end
    else begin
        startup_ack[0]      <= #TCQ 'd0;
    end
end

always @(posedge clk_i) begin
    if(state==ST_STARTUP_ERR)
        startup_ack[1] <= #TCQ 'd1;
    else
        startup_ack[1] <= #TCQ 'd0;
end

assign startup_fifo_rst     = state==ST_STARTUP_WAIT && startup_rst_r || state==ST_STARTUP_ERR;
assign write_burst_finish   = state==ST_PROGRAM && state_next==ST_STARTUP_WAIT;
assign write_start          = state==ST_STARTUP && state_next==ST_PROGRAM;
assign startup_ack_o        = startup_ack      ;
assign startup_last_pack_o  = startup_last_pack;
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> read
always @(posedge clk_i) begin
    if(state==ST_READ_WAIT)begin
        if(flash_rd_valid_o)
            read_cnt <= #TCQ read_cnt + 1;
    end
    else begin
        read_cnt <= #TCQ 'd0;
    end
end

always @(posedge clk_i) begin
    if(state==ST_IDLE && state_next==ST_READ)
        read_addr <= #TCQ 'h0;
    else if(state==ST_READ_END && state_next==ST_READ)
        read_addr <= #TCQ read_addr + WRITE_PACK_LENG;
end

always @(posedge clk_i) begin
    if(state==ST_READ_END)
        read_wait_cnt <= #TCQ read_wait_cnt + 1;
    else 
        read_wait_cnt <= #TCQ 'd0;
end

assign read_start = state==ST_READ && state_next==ST_READ_WAIT;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


endmodule
