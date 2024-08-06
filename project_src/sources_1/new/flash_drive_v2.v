`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: zas
// Engineer: songyuxin
// 
// Create Date: 2023/08/06
// Design Name: PCG1
// Module Name: flash_drive
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module flash_drive_v2 #(
    parameter                           TCQ         = 0.1   ,
    parameter                           WR_LENGTH   = 512   ,
    parameter                           DATA_WIDTH  = 16    ,
    parameter                           ADDR_WIDTH  = 27    
)(
    // clk & rst
    input                               clk_i               ,  // 125MHz
    input                               rst_i               ,

    // flash control command
    input                               write_start_i       ,
    input                               write_burst_finish_i,
    input   [ADDR_WIDTH-1:0]            write_addr_i        ,
    output                              write_rd_en_o       ,
    input   [DATA_WIDTH-1:0]            write_data_i        ,

    input                               read_array_en_i     ,
    input                               erase_en_i          ,
    input   [ADDR_WIDTH-1:0]            erase_addr_i        ,
    input                               unlock_block_en_i   ,
    // input                               read_id_en_i        ,
    // input                               erase_suspend_en_i  ,
    // output  reg                         unlock_block_succ_o ,
    // output  reg                         unlock_block_fail_o ,

    input                               rd_status_en_i      ,
    output                              status_valid_o      ,
    output  [8-1:0]                     status_reg_o        ,

    input                               clr_status_reg_en_i ,

    input                               set_cfg_en_i        ,
    input   [DATA_WIDTH-1:0]            set_cfg_reg_i       ,

    input                               read_start_i        ,
    input   [ADDR_WIDTH-1:0]            read_addr_i         ,
    output                              read_valid_o        ,
    output  [DATA_WIDTH-1:0]            read_data_o         ,

    // flash status
    output                              flash_busy_o        ,

    // flash interface
    input   [DATA_WIDTH-1:0]            flash_data_i        ,
    output  [DATA_WIDTH-1:0]            flash_data_o        ,
    output  [ADDR_WIDTH-1:0]            flash_addr_o        ,
    output                              WE_B                ,  // write enable
    output                              ADV_B               ,
    output                              OE_B                ,  // read enable
    output                              CE_B                ,  // chip enable
    input                               WAIT                ,
    output                              CLK                    // 25MHz
);


//////////////////////////////////////////////////////////////////////////////////
// *********** Define Parameter Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
localparam                      ST_IDLE             = 4'd0;
localparam                      ST_LATENCY_CNT      = 4'd1;
localparam                      ST_WRITE            = 4'd2;
localparam                      ST_READ             = 4'd3;
localparam                      ST_ERASE            = 4'd4;
localparam                      ST_READ_STATUS      = 4'd5;
localparam                      ST_SET_RCR          = 4'd6;  // set read configuration register
localparam                      ST_CLR_STATUS       = 4'd7;
localparam                      ST_LOCK_ADDR        = 4'd8;
localparam                      ST_RD_STATUS_WAIT   = 4'd9;
localparam                      ST_END              = 4'd10;
localparam                      ST_BLOCK_UNLOCK     = 4'd11;  // 解除块锁定
localparam                      ST_ERASE_SUSPEND    = 4'd12;
localparam                      ST_READ_ARRAY       = 4'd13;
localparam                      ST_READ_END         = 4'd14;
localparam                      ST_WRITE_WAIT       = 4'd15;

localparam                      LATENCY_COUNT       = 'd4;
localparam                      WRITE_SYSCLE        = 'd150;
localparam                      CE_WAIT             = 'd20;
localparam                      CE_HOLD             = 'd130;
localparam                      WE_WAIT             = 'd60;
localparam                      WE_HOLD             = 'd90;

localparam  [DATA_WIDTH-1:0]    READ_ARRAY          = 'hFF;
localparam  [DATA_WIDTH-1:0]    BUFFERED_PROGRAM    = 'hE8;
localparam  [DATA_WIDTH-1:0]    WORD_PROGRAM        = 'h40;
localparam  [DATA_WIDTH-1:0]    BLOCK_ERASE         = 'h20;
localparam  [DATA_WIDTH-1:0]    BLOCK_UBLOCK        = 'h60;
localparam  [DATA_WIDTH-1:0]    ERASE_SUSPEDN       = 'hB0;
localparam  [DATA_WIDTH-1:0]    OPERATE_RESUME      = 'hD0;
localparam  [DATA_WIDTH-1:0]    READ_ID             = 'h90;
localparam  [DATA_WIDTH-1:0]    READ_STATUS         = 'h70;
localparam  [DATA_WIDTH-1:0]    SET_RCR_1           = 'h60;
localparam  [DATA_WIDTH-1:0]    SET_RCR_2           = 'h03;
localparam  [DATA_WIDTH-1:0]    CLR_STATUS          = 'h50;
localparam  [ADDR_WIDTH-1:0]    DNA_ADDR            = 'h0A00000;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Register Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
reg     [ 4-1:0]                state               = ST_IDLE;
reg     [ 4-1:0]                state_next          = ST_IDLE;

reg                             write_burst_finish_r= 'd0;
reg                             program_ready       = 'd0;
reg                             write_start_r       = 'd0;
reg     [ADDR_WIDTH-1:0]        write_addr_r        = 'd0;
reg     [DATA_WIDTH-1:0]        write_data_r        = 'd0;
reg     [ 8-1:0]                write_operate_cnt   = 'd0;
reg     [10-1:0]                write_cnt           = 'd0;

reg                             read_array_en_r     = 'd0;
reg                             erase_en_r          = 'd0;
reg     [ADDR_WIDTH-1:0]        erase_addr_r        = 'd0;
reg                             unlock_block_en_r   = 'd0;
reg     [ADDR_WIDTH-1:0]        unlock_block_addr_r = 'd0;
reg     [18-1:0]                write_wait_cnt      = 'd0;

reg                             set_cfg_en_r        = 'd0;
reg     [DATA_WIDTH-1:0]        set_cfg_reg_r       = 'd0;

reg                             read_start_r        = 'd0;
reg     [ADDR_WIDTH-1:0]        read_addr_r         = 'd0;
reg     [10-1:0]                read_data_cnt       = 'd0;
reg                             read_valid_r        = 'd0;
reg     [DATA_WIDTH-1:0]        read_data_r         = 'd0;
reg                             status_valid_r      = 'd0;
reg     [8-1:0]                 status_data_r       = 'd0;

reg                             rd_status_en_r      = 'd0;

reg     [DATA_WIDTH-1:0]        flash_data_r        = 'd0;
reg     [ADDR_WIDTH-1:0]        flash_addr_r        = 'd0;

reg                             ce_r                = 'd1;
reg                             we_r                = 'd1;
reg                             oe_r                = 'd1;
reg                             adv_r               = 'd1;
reg     [ 4-1:0]                latency_cnt         = 'd0;
reg     [ 2-1:0]                adv_cnt             = 'd0;
reg     [ 7-1:0]                rd_wait_cnt         = 'd0;
reg     [ 6-1:0]                end_wait_cnt        = 'd0;
reg     [ 2-1:0]                flash_clk_cnt       = 'd0;
reg                             flash_clk_r         = 'd0;
reg                             flash_clk_d0        = 'd0;
reg                             flash_clk_d1        = 'd0;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Wire Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
wire                            flash_clk_pose  ;
wire                            flash_clk_nege  ;



//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Instance Module
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>



//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Logic Design
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
always @(posedge clk_i) begin
    if(state==ST_IDLE && write_start_i)begin
        write_start_r   <= #TCQ 'd1;
        write_addr_r    <= #TCQ write_addr_i;
    end
    else if(state_next==ST_IDLE)begin
        write_start_r   <= #TCQ 'd0;
    end
end

always @(posedge clk_i) begin
    if(~write_burst_finish_r && write_burst_finish_i)
        write_burst_finish_r <= #TCQ 'd1;
    else if(state==ST_IDLE)
        write_burst_finish_r <= #TCQ 'd0;    
end

always @(posedge clk_i) begin
    if(state==ST_IDLE && erase_en_i)begin
        erase_en_r      <= #TCQ 'd1;
        erase_addr_r    <= #TCQ erase_addr_i;
    end
    else if(state_next==ST_IDLE)begin
        erase_en_r      <= #TCQ 'd0;
    end
end

always @(posedge clk_i) begin
    if(state==ST_IDLE && unlock_block_en_i)begin
        unlock_block_en_r   <= #TCQ 'd1;
        unlock_block_addr_r <= #TCQ erase_addr_i;
    end
    else if(state_next==ST_IDLE)begin
        unlock_block_en_r   <= #TCQ 'd0;
    end
end

always @(posedge clk_i) begin
    if(state==ST_IDLE && set_cfg_en_i)begin
        set_cfg_en_r    <= #TCQ 'd1;
        set_cfg_reg_r   <= #TCQ set_cfg_reg_i;
    end
    else if(state_next==ST_IDLE)begin
        set_cfg_en_r    <= #TCQ 'd0;
    end
end

always @(posedge clk_i) begin
    if(state==ST_IDLE && read_start_i)begin
        read_start_r    <= #TCQ 'd1;
        read_addr_r     <= #TCQ read_addr_i;
    end
    else if(state_next==ST_IDLE)begin
        read_start_r    <= #TCQ 'd0;
    end
end

always @(posedge clk_i) begin
    if(state==ST_IDLE && rd_status_en_i)
        rd_status_en_r <= #TCQ 'd1;
    else if(state_next==ST_IDLE)
        rd_status_en_r <= #TCQ 'd0;
end

always @(posedge clk_i) begin
    if(state==ST_IDLE && read_array_en_i)
        read_array_en_r <= #TCQ 'd1;
    else if(state_next==ST_IDLE)
        read_array_en_r <= #TCQ 'd0;
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
            if(write_start_i)
                state_next = ST_CLR_STATUS;
            else if(erase_en_i)
                state_next = ST_ERASE;
            else if(unlock_block_en_i)
                state_next = ST_BLOCK_UNLOCK;
            else if(set_cfg_en_i)
                state_next = ST_SET_RCR;
            else if(clr_status_reg_en_i)
                state_next = ST_CLR_STATUS;
            else if(rd_status_en_i)
                state_next = ST_READ_STATUS;
            else if(read_start_i)
                state_next = ST_LOCK_ADDR;
            else if(read_array_en_i)
                state_next = ST_CLR_STATUS;
        end

        ST_WRITE: begin
            if(write_operate_cnt==WRITE_SYSCLE && write_cnt==WR_LENGTH+2)
                state_next = ST_WRITE_WAIT;
        end

        ST_WRITE_WAIT: begin
            if(write_wait_cnt == 'd125_000)begin
                // if(write_burst_finish_r)
                //     state_next = ST_END; 
                // else
                    state_next = ST_READ_ARRAY; 
            end
        end

        ST_ERASE: begin
            if(write_operate_cnt==WRITE_SYSCLE && write_cnt=='d1)
                state_next = ST_END; 
        end
        
        ST_BLOCK_UNLOCK: begin
            if(write_operate_cnt==WRITE_SYSCLE && write_cnt=='d1)
                state_next = ST_END; 
        end

        ST_SET_RCR: begin
            if(write_operate_cnt==WRITE_SYSCLE && write_cnt=='d1)
                state_next = ST_END; 
        end

        ST_CLR_STATUS: begin
            if(read_array_en_r)begin
                if(write_operate_cnt==WRITE_SYSCLE && write_cnt=='d0)
                    state_next = ST_READ_END; 
            end
            else if(write_start_r)begin
                if(write_operate_cnt==WRITE_SYSCLE && write_cnt=='d0)
                    state_next = ST_READ_STATUS;
            end
            else begin
                if(write_operate_cnt==WRITE_SYSCLE && write_cnt=='d0)
                    state_next = ST_END; 
            end
        end
        
        ST_READ_STATUS: begin
            if(write_operate_cnt==WRITE_SYSCLE && write_cnt=='d0)
                state_next = ST_RD_STATUS_WAIT;
        end

        ST_RD_STATUS_WAIT: begin
            if(status_valid_r)
                state_next = ST_READ_END;
        end
        
        ST_LOCK_ADDR: begin
            if(adv_cnt=='d2 && flash_clk_nege)
                state_next = ST_LATENCY_CNT;
        end

        ST_LATENCY_CNT: begin
            if(latency_cnt == LATENCY_COUNT && flash_clk_pose)begin
                state_next = ST_READ;
            end
        end

        ST_READ: begin
            if(read_start_r && read_data_cnt==WR_LENGTH)
                state_next = ST_END;
        end

        ST_READ_END: begin
            if(&end_wait_cnt)begin
                if(write_start_r && program_ready)
                    state_next = ST_WRITE;
                else if(write_start_r && ~program_ready)
                    state_next = ST_CLR_STATUS;
                else 
                    state_next = ST_READ_ARRAY;
            end
        end

        ST_READ_ARRAY: begin
            if(write_operate_cnt==WRITE_SYSCLE && write_cnt=='d0)begin
                // if(write_start_r)
                //     state_next = ST_WRITE;
                // else
                    state_next = ST_END; 
            end
        end

        ST_END: begin
            if(&end_wait_cnt)
                state_next = ST_IDLE;
        end

        default: state_next = ST_IDLE;
    endcase
end

// generate flash clk, 4 frequency division
// always @(posedge clk_i) begin
//     // if(state==ST_LOCK_ADDR || state==ST_LATENCY_CNT || state==ST_READ || state==ST_RD_STATUS_WAIT)begin
//     if(state==ST_WRITE || state==ST_WRITE_WAIT || state==ST_READ_ARRAY || state==ST_RD_STATUS_WAIT || state==ST_LOCK_ADDR || state==ST_LATENCY_CNT || state==ST_READ)begin
//         flash_clk_cnt <= #TCQ flash_clk_cnt + 1;
//     end
//     else 
//         flash_clk_cnt <= #TCQ 'd0;
// end
always @(posedge clk_i) begin
    if(state==ST_IDLE || state==ST_END)
        flash_clk_cnt <= #TCQ 'd0;
    else 
        flash_clk_cnt <= #TCQ flash_clk_cnt + 1;
end

// always @(posedge clk_i) begin
//     // if(state==ST_LOCK_ADDR || state==ST_LATENCY_CNT || state==ST_READ || state==ST_RD_STATUS_WAIT)begin
//     if(state==ST_WRITE || state==ST_WRITE_WAIT || state==ST_READ_ARRAY || state==ST_RD_STATUS_WAIT || state==ST_LOCK_ADDR || state==ST_LATENCY_CNT || state==ST_READ)begin
//         flash_clk_r <= #TCQ (&flash_clk_cnt) ? ~flash_clk_r : flash_clk_r;
//     end
//     else begin
//         flash_clk_r <= #TCQ 'd0;
//     end
// end
always @(posedge clk_i) begin
    if(state==ST_IDLE || state==ST_END)
        flash_clk_r <= #TCQ 'd0;
    else 
        flash_clk_r <= #TCQ (&flash_clk_cnt) ? ~flash_clk_r : flash_clk_r;
end

always @(posedge clk_i) begin
    flash_clk_d0 <= #TCQ flash_clk_r;
    // flash_clk_d1 <= #TCQ flash_clk_d0;
end

assign flash_clk_pose = ~flash_clk_d0 && flash_clk_r;
assign flash_clk_nege = flash_clk_d0  && ~flash_clk_r;

always @(posedge clk_i) begin
    if(state==ST_END || state==ST_READ_END)
        end_wait_cnt <= #TCQ end_wait_cnt + 1;
    else 
        end_wait_cnt <= #TCQ 'd0;
end

always @(posedge clk_i) begin
    if(state==ST_IDLE || state==ST_END)
        ce_r <= #TCQ 'd1;
    else 
        ce_r <= #TCQ 'd0;
end

// read flash
//        ST_LOCK_ADDR       ST_LATENCY_CNT      ST_READ
//    ____      ____      ____      __≈____      ____      ____
// CLk    |____|    |____|    |____|  ≈    |____|    |____|
//    _____           ________________≈________________________
// ADV     |_________|                ≈
//    __________________________      ≈
// OE                           |_____≈________________________
always @(posedge clk_i) begin
    if((state==ST_LATENCY_CNT && latency_cnt>1) || state==ST_READ || state==ST_RD_STATUS_WAIT)
        oe_r <= #TCQ 'd0;
    else if(state==ST_END || state==ST_READ_END)
        oe_r <= #TCQ 'd1; 
    else if(state==ST_WRITE || state==ST_READ_ARRAY)begin
        if(write_operate_cnt<CE_WAIT && write_cnt=='d0)
            oe_r <= #TCQ 'd0;
        else 
            oe_r <= #TCQ 'd1;
    end

end

always @(posedge clk_i) begin
    if(state==ST_LOCK_ADDR)begin
        if(flash_clk_pose)
            adv_cnt <= #TCQ adv_cnt + 1;
    end
    else 
        adv_cnt <= #TCQ 'd0;
end

always @(posedge clk_i) begin
    if(state==ST_LOCK_ADDR)begin
        if(adv_cnt=='d0 && flash_clk_pose)
            adv_r <= #TCQ 'd0;
    end
    else if(state==ST_IDLE || state==ST_LATENCY_CNT || state==ST_READ || state==ST_SET_RCR || state==ST_END)
        adv_r <= #TCQ 'd1;
    // else if((state==ST_WRITE || state==ST_RD_STATUS_WAIT || state==ST_READ_END || state==ST_WRITE_WAIT || state==ST_ERASE || state==ST_BLOCK_UNLOCK || state==ST_READ_STATUS || state==ST_CLR_STATUS || state==ST_READ_ARRAY))begin
    else if(state==ST_WRITE || state==ST_WRITE_WAIT || state==ST_READ_ARRAY)begin
        if(write_operate_cnt>CE_WAIT && write_operate_cnt<WE_WAIT)
            adv_r <= #TCQ 'd0;
        else
            adv_r <= #TCQ 'd1;
    end
    else begin
        adv_r <= #TCQ 'd0;
    end
end

always @(posedge clk_i) begin
    if(state==ST_RD_STATUS_WAIT)
        rd_wait_cnt <= #TCQ &rd_wait_cnt ? rd_wait_cnt : rd_wait_cnt + 1;
    else 
        rd_wait_cnt <= #TCQ 'd0;
end

always @(posedge clk_i) begin
    if(state==ST_RD_STATUS_WAIT && (&rd_wait_cnt))begin
        status_valid_r <= #TCQ WAIT && flash_clk_pose;
        status_data_r  <= #TCQ flash_data_i[7:0];
    end
    else 
        status_valid_r <= #TCQ 'd0;
end

always @(posedge clk_i) begin
    if(state==ST_LATENCY_CNT)begin
        if(flash_clk_pose)
            latency_cnt <= #TCQ latency_cnt + 1;
    end
    else
        latency_cnt <= #TCQ 'd0;
end

always @(posedge clk_i) begin
    if(state==ST_READ)begin
        read_valid_r <= #TCQ WAIT && flash_clk_pose;
        read_data_r  <= #TCQ flash_data_i;
    end
    else 
        read_valid_r <= #TCQ 'd0;
end

always @(posedge clk_i) begin
    if(state==ST_READ)begin
        if(read_valid_r)
            read_data_cnt <= #TCQ read_data_cnt + 1;
    end
    else begin
        read_data_cnt <= #TCQ 'd0;
    end
end

// write cycle is 100ns
//    ______:<- 70ns ->:____    
// WE       |__________|    |___
//    __________________________
// OE 
//    ______
// CE       |___________________

always @(posedge clk_i) begin
    if(state==ST_WRITE_WAIT)
        write_wait_cnt <= #TCQ write_wait_cnt + 1;
    else 
        write_wait_cnt <= #TCQ 'd0;
end

always @(posedge clk_i) begin
    if(status_valid_r && status_data_r=='h80 && write_start_r)
        program_ready <= #TCQ 'd1;
    else if(state==ST_IDLE)
        program_ready <= #TCQ 'd0;
end

always @(posedge clk_i) begin
    if(state==ST_WRITE)begin
        if(write_operate_cnt >= WE_WAIT && flash_clk_pose && write_operate_cnt < WE_HOLD)
            we_r <= #TCQ 'd0;
        else if(write_operate_cnt > WE_HOLD)
            we_r <= #TCQ 'd1;
    end
    else if(state==ST_ERASE || state==ST_BLOCK_UNLOCK || state==ST_READ_STATUS || state==ST_SET_RCR || state==ST_CLR_STATUS || state==ST_READ_ARRAY)begin
        if(write_operate_cnt > WE_WAIT && write_operate_cnt < WE_HOLD)
            we_r <= #TCQ 'd0;
        else 
            we_r <= #TCQ 'd1;
    end
    else 
        we_r <= #TCQ 'd1;
end

always @(posedge clk_i) begin
    if(state==ST_WRITE || state==ST_ERASE || state==ST_BLOCK_UNLOCK || state==ST_READ_STATUS || state==ST_SET_RCR || state==ST_CLR_STATUS || state==ST_READ_ARRAY)begin
        if(write_operate_cnt == WRITE_SYSCLE)
            write_operate_cnt <= #TCQ 'd0;
        else 
            write_operate_cnt <= #TCQ write_operate_cnt + 1;
    end
end

// program flash control count: 0~514
// erase flash block control count: 0~1
// read status register count: 0
// set read configuration register count: 0~1
// clear status register count: 0
always @(posedge clk_i) begin
    if(state!=state_next)
        write_cnt <= #TCQ 'd0;
    else if(write_operate_cnt==WRITE_SYSCLE)
        write_cnt <= #TCQ write_cnt + 1;
end

always @(posedge clk_i) begin
    if(state==ST_WRITE && write_rd_en_o)begin
        write_data_r <= #TCQ write_data_i;
    end
end

always @(posedge clk_i) begin
    if(state==ST_WRITE)begin
        case (write_cnt)
            'd0: begin
                flash_addr_r <= #TCQ write_addr_r;
                flash_data_r <= #TCQ BUFFERED_PROGRAM;
            end
            'd1: begin
                flash_addr_r <= #TCQ write_addr_r;
                flash_data_r <= #TCQ WR_LENGTH-1;
            end
            WR_LENGTH+2 : begin
                flash_addr_r <= #TCQ flash_addr_r;
                flash_data_r <= #TCQ OPERATE_RESUME;
            end
            default: begin
                flash_addr_r <= #TCQ write_addr_r + write_cnt - 2;
                flash_data_r <= #TCQ write_data_r;
            end
        endcase
    end
    else if(state==ST_ERASE)begin
        case (write_cnt)
            'd0: begin
                flash_addr_r <= #TCQ erase_addr_r;
                flash_data_r <= #TCQ BLOCK_ERASE;
            end
            'd1: begin
                flash_addr_r <= #TCQ erase_addr_r;
                flash_data_r <= #TCQ OPERATE_RESUME;
            end
            default: /*default*/;
        endcase
    end
    else if(state==ST_BLOCK_UNLOCK)begin
        case (write_cnt)
            'd0: begin
                flash_addr_r <= #TCQ unlock_block_addr_r;
                flash_data_r <= #TCQ BLOCK_UBLOCK;
            end
            'd1: begin
                flash_addr_r <= #TCQ unlock_block_addr_r;
                flash_data_r <= #TCQ OPERATE_RESUME;
            end
            default: /*default*/;
        endcase
    end
    // else if(state==ST_READ_ID)begin
    //     case (write_cnt)
    //         'd0: begin
    //             flash_addr_r <= #TCQ DNA_ADDR;
    //             flash_data_r <= #TCQ READ_ID;
    //         end
    //         default: /*default*/;
    //     endcase
    // end
    else if(state==ST_READ_STATUS)begin
        case (write_cnt)
            'd0: begin
                flash_addr_r <= #TCQ DNA_ADDR;
                flash_data_r <= #TCQ READ_STATUS;
            end
            default: /*default*/;
        endcase
    end
    else if(state==ST_SET_RCR)begin
        case (write_cnt)
            'd0: begin
                flash_addr_r <= #TCQ set_cfg_reg_r;
                flash_data_r <= #TCQ SET_RCR_1;
            end
            'd1: begin
                flash_addr_r <= #TCQ set_cfg_reg_r;
                flash_data_r <= #TCQ SET_RCR_2;
            end
            default: /*default*/;
        endcase
    end
    else if(state==ST_CLR_STATUS)begin
        case (write_cnt)
            'd0: begin
                flash_addr_r <= #TCQ DNA_ADDR;
                flash_data_r <= #TCQ CLR_STATUS;
            end
            default: /*default*/;
        endcase
    end
    else if(state==ST_LOCK_ADDR)begin
        if(read_start_r)
            flash_addr_r <= #TCQ read_addr_r;
        else if(rd_status_en_r)
            flash_addr_r <= #TCQ DNA_ADDR;
        // else if(read_id_en_r)
        //     flash_addr_r <= #TCQ unlock_block_addr_r + 'h02;
    end
    else if(state==ST_READ_ARRAY)begin
        case (write_cnt)
            'd0: begin
                flash_addr_r <= #TCQ flash_addr_r;
                flash_data_r <= #TCQ READ_ARRAY;
            end
            default: /*default*/;
        endcase
    end
end

// read block lock status
// always @(posedge clk_i) begin
//     if(read_id_en_r && read_valid_r)begin
//         unlock_block_succ_o <= #TCQ (~read_data_r[0]);
//         unlock_block_fail_o <= #TCQ read_data_r[0];
//     end
//     else if(state==ST_IDLE)begin
//         unlock_block_succ_o <= #TCQ 'd0;
//         unlock_block_fail_o <= #TCQ 'd0;
//     end
// end

assign flash_addr_o     = flash_addr_r;  // processing in word(2bytes) whitin the module  
assign flash_data_o     = flash_data_r;
assign write_rd_en_o    = state==ST_WRITE && write_operate_cnt=='d0 && write_cnt>='d2;
assign read_valid_o     = read_valid_r;
assign read_data_o      = read_data_r;
assign status_valid_o   = status_valid_r;
assign status_reg_o     = status_data_r;
assign flash_busy_o     = state!=ST_IDLE;

assign WE_B             = we_r;
assign OE_B             = oe_r;
assign CE_B             = ce_r;
assign ADV_B            = adv_r;
assign CLK              = flash_clk_r;


// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> debug code
// reg [10-1:0] write_flash_cnt = 'd0;
// always @(posedge clk_i) begin
//     if(state==ST_IDLE)
//         write_flash_cnt <= #TCQ 'd0;
//     else if(write_rd_en_o)
//         write_flash_cnt <= #TCQ write_flash_cnt + 1;
// end




//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


endmodule
