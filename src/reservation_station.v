/* `include"/home/oguricap/CPU2024-main/src/const.v" */
`include"const.v"
module reservation_station (
    input wire clk,
    input wire rst,
    input wire rdy,

    output reg rs_full,

    // to decoder
    input wire decoder_ready,
    input [4 : 0] inst_rd,
    input [31 : 0] inst_r1,
    input [31 : 0] inst_r2,
    input [`reg_size -1: 0] inst_dep1,
    input [`reg_size -1 : 0] inst_dep2,
    input inst_has_dep1,
    input inst_has_dep2,
    input [`robsize -1 : 0] inst_rob_id,
    input [`rs_type_size - 1 : 0] inst_type,   

    // to lsb
    input wire lsb_ready,
    input [`robsize -1  : 0] lsb_rob_id,
    input [31 : 0] lsb_value,
    
  
    output wire rs_ready,
    output [`robsize -1 : 0] rs_rob_id,
    output [31 : 0] rs_value,

    //to alu
    output wire rs_shot,
    output wire[31 : 0] alu_r1,
    output wire[31 : 0] alu_r2,
    output wire[`robsize - 1 : 0] alu_rob_id,
    output wire[`rs_type_size - 1 : 0] alu_work_type,
    input wire alu_ready,
    input wire[`robsize - 1 : 0] inputalu_rob_id,
    input wire[31 : 0] alu_value
);

    localparam rs_size = 1 << `rs_size_bit;

    reg busy [0: rs_size - 1];
    reg [`robsize-1 : 0] rob_id [0: rs_size - 1];
    reg [`rs_type_size -1 : 0] work_type [0: rs_size - 1];
    reg [31 : 0] r1 [0: rs_size - 1];
    reg [31 : 0] r2 [0: rs_size - 1];
    reg has_dep1 [0: rs_size - 1];
    reg has_dep2 [0: rs_size - 1];
    reg [`robsize-1 : 0] dep1 [0: rs_size - 1];
    reg [`robsize-1 : 0] dep2 [0: rs_size - 1];

    wire ready [0:rs_size - 1];
    wire next_full;
    reg [`rs_size_bit - 1 : 0] size;
    wire [`rs_size_bit - 1 : 0] next_size;

    wire ready_shot;
    wire [`rs_size_bit -1 : 0] shot_pos;
    wire [`rs_size_bit -1 : 0] space_pos;    

    


   
    generate
        genvar i;
        for (i = 0; i < rs_size; i = i + 1) begin : gen
            assign ready[i] = busy[i] && !has_dep1[i] && !has_dep2[i];
        end
        //线段树寻找空闲
        wire spare [1:2*rs_size - 1];
        wire execute[1:2*rs_size - 1];
        wire [`rs_size_bit - 1 : 0] execute_pos[1:2*rs_size - 1];
        wire [`rs_size_bit - 1 : 0] spare_pos[1:2*rs_size - 1];
        for(i = 0 ; i < rs_size; i = i + 1) begin
            assign spare[i + rs_size - 1] = ~busy[i];
            assign execute[i + rs_size - 1] = ready[i];
            assign execute_pos[i + rs_size - 1] = i;
            assign spare_pos[i + rs_size - 1] = i;
        end
        for(i = 1; i < rs_size; i = i + 1) begin
            assign spare[i] = spare[i<<1] | spare[i<<1|1];
            assign execute[i] = execute[i<<1] | execute[i<<1|1];
            assign execute_pos[i] = execute[i<<1] ? execute_pos[i<<1] : execute_pos[i<<1|1];
            assign spare_pos[i] = spare[i<<1] ? spare_pos[i<<1] : spare_pos[i<<1|1];
        end
        assign ready_shot = execute[1];
        assign shot_pos = execute_pos[1];
        assign space_pos = spare_pos[1];
    endgenerate

    assign next_size = (decoder_ready && rdy) ? ready_shot? size : size + 1 : ready_shot ? size - 1 : size;  
    assign next_full = next_size == rs_size;

    assign alu_r1 = r1[shot_pos];
    assign alu_r2 = r2[shot_pos];
    assign alu_rob_id = rob_id[shot_pos];
    assign alu_work_type = work_type[shot_pos];
    assign rs_ready = alu_ready;
    assign rs_value = alu_value;
    assign rs_rob_id = inputalu_rob_id;   

    integer j;
    always @(posedge clk) begin 
        if(rst) begin
            for(j = 0; j < rs_size; j = j + 1) begin
                busy[j] <= 0;
                rob_id[j] <= 0;
                work_type[j] <= 0;
                r1[j] <= 0;
                r2[j] <= 0;
                has_dep1[j] <= 0;
                has_dep2[j] <= 0;
                dep1[j] <= 0;
                dep2[j] <= 0;
            end
        end
        else if(rdy) begin
            size <= next_size;
            rs_full <= next_full;
            if(decoder_ready) begin
                busy[space_pos] <= 1;
                rob_id[space_pos] <= inst_rob_id;
                work_type[space_pos] <= inst_type;
                r1[space_pos] <= inst_has_dep1 ? (rs_ready && rs_rob_id == inst_dep1) ? rs_value : (lsb_ready && lsb_rob_id == inst_dep1 ? lsb_value : 32'b0 ) : inst_r1;
                r2[space_pos] <= inst_has_dep2 ? (rs_ready && rs_rob_id == inst_dep2) ? rs_value : (lsb_ready && lsb_rob_id == inst_dep2 ? lsb_value : 32'b0 ) : inst_r2;
                has_dep1[space_pos] <= inst_has_dep1 && !(rs_ready && rs_rob_id == inst_dep1) && !(lsb_ready && lsb_rob_id == inst_dep1);
                has_dep2[space_pos] <= inst_has_dep2 && !(rs_ready && rs_rob_id == inst_dep2) && !(lsb_ready && lsb_rob_id == inst_dep2);
                dep1[space_pos] <= inst_dep1;
                dep2[space_pos] <= inst_dep2;
            end

            for(j = 0; j < rs_size; j = j + 1) begin
                if(busy[j])begin
                    if(alu_ready && has_dep1[j] && rs_rob_id == dep1[j])begin
                        r1[j] <= rs_value;
                        has_dep1[j] <= 0;
                    end
                    if(alu_ready && has_dep2[j] && rs_rob_id == dep2[j])begin
                        r2[j] <= rs_value;
                        has_dep2[j] <= 0;
                    end
                    if(lsb_ready && has_dep1[j] && lsb_rob_id == dep1[j])begin
                        r1[j] <= lsb_value;
                        has_dep1[j] <= 0;
                    end
                    if(lsb_ready && has_dep2[j] && lsb_rob_id == dep2[j])begin
                        r2[j] <= lsb_value;
                        has_dep2[j] <= 0;
                    end
                end
            end
            if( ready_shot)begin
                busy[shot_pos] <= 0;
            end 
        end
    end
    
endmodule