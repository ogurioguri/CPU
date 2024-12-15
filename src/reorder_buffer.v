/* `include"/home/oguricap/CPU2024-main/src/const.v" */
`include"const.v"
module reorder_buffer(
    input wire clk,
    input wire rst,
    input wire rdy,
   
   // from decoder
    input wire decoder_ready,
    input wire [`rob_type_bit - 1: 0] inst_type,
    input wire [4:0] inst_rd,
    input wire [31:0] inst_imm,
    input wire [31:0] inst_pc,
    input wire [31:0] inst_jump_addr,

    output wire full,
    output wire empty,
    output wire [`robsize -1 : 0] outrob_id_head,
    output wire [`robsize -1 : 0] outrob_id_tail,

    output reg clear,
    output reg [31:0] next_pc,

    // to LoadStoreBuffer
    input wire lsb_ready,
    input wire [`robsize -1 : 0] lsb_rob_id,
    input wire [31:0] lsb_value,

    //to rs
    input wire [`robsize -1 : 0] rs_rob_id,
    input wire [31:0] rs_value,
    input wire rs_ready,

    // to register
    output wire need_set_reg_value,
    output wire need_set_reg_dep,
    output wire [4:0] set_reg_id,
    output wire [31:0] set_reg_val,
    output wire [`robsize -1 : 0] set_reg_rob_id,
    output wire [4:0] set_dep_reg,
    output wire [`robsize -1: 0] set_dep_rob_id,

    input wire [4:0] need_rob_id1,
    input wire [4:0] need_rob_id2,
    output wire rob_value1_ready,
    output wire [31:0] rob_value1,
    output wire rob_value2_ready,
    output wire [31:0] rob_value2

);

    localparam rob_size_number = 1 << `robsize;

    reg busy [0: rob_size_number -1];
    reg ready_issue [0: rob_size_number -1 ];
    reg [`rob_type_bit -1 : 0] rob_type [0: rob_size_number -1 ];
    reg [4:0] rob_rd [0: rob_size_number -1 ];
    reg [31:0] rob_value [0: rob_size_number -1];
    reg [31:0] rob_pc [0: rob_size_number -1 ];
    reg [31:0] rob_jump_addr [0: rob_size_number -1];

    reg [`robsize -1 : 0] rob_id_head;
    reg [`robsize -1 : 0] rob_id_tail;


    integer i;
    always @(posedge clk or posedge rst) begin
        if(rst || (clear && rdy)) begin
            clear <= 0;
            for(i = 0; i < rob_size_number; i = i + 1) begin
                busy[i] <= 0;
                ready_issue[i] <= 0;
                rob_type[i] <= 0;
                rob_rd[i] <= 0;
                rob_value[i] <= 0;
                rob_pc[i] <= 0;
                rob_jump_addr[i] <= 0;
            end
            rob_id_head <= 0;
            rob_id_tail <= 0;
        end
        else if(rdy) begin
            if(rs_ready) begin
                rob_value[rs_rob_id] <= rs_value;
                ready_issue[rs_rob_id] <= 1;
            end
            if(lsb_ready) begin
                rob_value[lsb_rob_id] <= lsb_value;
                ready_issue[lsb_rob_id] <= 1;
            end 
            if(decoder_ready) begin
                rob_id_tail <= (rob_id_tail + 1) % rob_size_number;
                busy[rob_id_tail] <= 1;
                ready_issue[rob_id_tail] <= 1;
                rob_type[rob_id_tail] <= inst_type;
                rob_rd[rob_id_tail] <= inst_rd;
                rob_value[rob_id_tail] <= inst_imm;
                rob_pc[rob_id_tail] <= inst_pc;
                rob_jump_addr[rob_id_tail] <= inst_jump_addr;
            end
            if(busy[rob_id_head] && ready_issue[rob_id_head]) begin
                busy[rob_id_head] <= 0;
                ready_issue[rob_id_head] <= 0;
                if(!rob_value[rob_id_head][0] && rob_type[rob_id_head] == `robtype_b) begin
                    clear <= 1;
                    next_pc <= rob_jump_addr[rob_id_head];
                end
            end
            
        end
    end

    assign outrob_id_head = rob_id_head;
    assign outrob_id_tail = rob_id_tail;


    assign full =(rob_id_tail == rob_id_head || (rob_id_tail + 1) % rob_size_number == rob_id_head) && busy[rob_id_head];
    assign empty = rob_id_head == rob_id_tail && !busy[rob_id_head];

    wire need_set_reg = (rdy && busy[rob_id_head] && ready_issue[rob_id_head] && rob_type[rob_id_head] == `robtype_r);

    assign need_set_reg_value = need_set_reg;
    assign set_reg_id = rob_rd[rob_id_head];
    assign set_reg_val = rob_value[rob_id_head];
    assign set_reg_rob_id = rob_id_head;

    wire need_set_dep = rdy && decoder_ready && inst_type == `robtype_r;
    assign need_set_reg_dep = need_set_dep;
    assign set_dep_reg = inst_rd;
    assign set_dep_rob_id = rob_id_tail;

    assign rob_value1_ready = ready_issue[need_rob_id1] || (rs_ready && rs_rob_id == need_rob_id1) || (lsb_ready && lsb_rob_id == need_rob_id1) ;
    assign rob_value1 = ready_issue[need_rob_id1] ? rob_value[need_rob_id1] : (rs_ready && rs_rob_id == need_rob_id1) ? rs_value : (lsb_ready && lsb_rob_id == need_rob_id1) ? lsb_value : 0;
    assign rob_value2_ready = ready_issue[need_rob_id2] || (rs_ready && rs_rob_id == need_rob_id2) || (lsb_ready && lsb_rob_id == need_rob_id2) ;
    assign rob_value2 = ready_issue[need_rob_id2] ? rob_value[need_rob_id2] : (rs_ready && rs_rob_id == need_rob_id2) ? rs_value : (lsb_ready && lsb_rob_id == need_rob_id2) ? lsb_value : 0;




endmodule