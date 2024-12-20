`include "const.v"
/* `include"/home/oguricap/CPU2024-main/src/const.v" */

module loadstore_buffer (
    input wire clk,
    input wire rst,
    input wire rdy,

    output wire ready_out,
    output wire [31:0] value_out,
    output wire [`robsize -1:0] rob_id_out,

    // to decoder 
    input wire decoder_ready,
    input wire [31:0] r1,
    input wire [31:0] r2,
    input wire [`robsize -1:0] dep1,
    input wire [`robsize -1:0] dep2,
    input wire has_dep1,
    input wire has_dep2,
    input wire [11:0] offset,
    input wire [`robsize -1:0] rob_id,
    input wire [`lsb_type_size -1:0] inst_type,
    output reg full,

    // to cache
    output wire need_cache,
    output reg [2:0] cache_size,
    output reg [31:0] cache_addr,
    //1 is store, 0 is load
    output reg cache_way,
    output reg [31:0] cache_value,

    input wire cache_ready,
    input wire [31:0] cache_result,

    // to reorder buffer
    input wire rob_full,
    input wire rob_empty,
    input wire [`robsize -1 : 0] head_id,

    //to reservation station : 
    //the result of load should be culculated in reservation station
    input wire rs_ready,
    input wire [`robsize -1 : 0] rs_rob_id,
    input wire [31:0] rs_value

);
//circular queue
localparam lsb_size = 1 << `lsb_size_bit;

reg busy [0:lsb_size -1];
reg commit[0:lsb_size -1];
reg [`robsize -1 : 0] lsb_rob_id [0:lsb_size -1];
reg [`lsb_type_size -1: 0] work_type[0:lsb_size -1] ;
reg [31:0] rs1_value[0:lsb_size -1];
reg [31:0] rs2_value[0:lsb_size -1 ];
reg rs1_has_depend[0:lsb_size -1];
reg rs2_has_depend[0:lsb_size -1];
reg [`robsize -1 : 0] rs1_depend[0:lsb_size -1];
reg [`robsize -1 : 0] rs2_depend[0:lsb_size -1];
reg [11:0] lsb_offset[0:lsb_size -1];

reg [`lsb_size_bit -1:0] head;
reg [`lsb_size_bit -1:0] tail;
reg [`lsb_size_bit : 0] size;


wire ready_pop;
assign ready_pop = cache_ready;

wire [`lsb_size_bit : 0]next_size = (decoder_ready && !ready_pop) ? size + 1 : (!decoder_ready && ready_pop) ? size - 1 : size;
// leave a space
wire next_full = next_size == lsb_size || (next_size + 1) == lsb_size ;
reg working;
//store need confirm
wire [`lsb_size_bit -1 : 0] next_inst_number = working ? head + 1 : head;
wire risk = work_type[next_inst_number][0];
wire shot_able = busy[next_inst_number] && !rs1_has_depend[next_inst_number] && !rs2_has_depend[next_inst_number] && (!risk || (!rob_empty && lsb_rob_id[next_inst_number] == head_id));
wire could_shot = shot_able && (!working || cache_ready); 
//sign extend
wire [31:0] address = rs1_value[next_inst_number] + {{20{lsb_offset[next_inst_number][11]}}, lsb_offset[next_inst_number]};

assign ready_out = cache_ready;
assign value_out = cache_result;
assign rob_id_out = lsb_rob_id[head];

assign need_cache = working;


integer i;
always @(posedge clk or posedge rst)begin
    if (rst)  begin
        full <= 0;
        working <= 0;
        for(i=0 ;i<lsb_size;i=i+1) begin
            busy[i] <= 0;
            lsb_rob_id[i] <= 0;
            work_type[i] <= 0;
            rs1_value[i] <= 0;
            rs2_value[i] <= 0;
            rs1_has_depend[i] <= 0;
            rs2_has_depend[i] <= 0;
            rs1_depend[i] <= 0;
            rs2_depend[i] <= 0;
            lsb_offset[i] <= 0;
            commit[i] <= 0;
        end
        head <= 0;
        tail <= 0;
        size <= 0;
    end
    else if(rdy)begin
        size <= next_size;
        full <= next_full;
        if(could_shot)begin
            working <= 1;
            cache_size <= work_type[next_inst_number][3:1];
            cache_way <= work_type[next_inst_number][0];
            cache_addr <= address;
            if(work_type[next_inst_number] == `robtype_s)begin
                cache_value <= rs2_value[next_inst_number];
            end
            else begin 
                cache_value <= 0;
            end
        end
        else if(working && cache_ready)begin
            working <= 0;
            commit[head] <= 0;
        end

        if(ready_pop)begin
            head <= head + 1;
            busy[head] <= 0;
        end

        if(decoder_ready && !full)begin
            tail <= (tail + 1) % lsb_size;
            busy[tail] <= 1;
            lsb_rob_id[tail] <= rob_id;
            work_type[tail] <= inst_type;
            rs1_value[tail] <= r1;
            rs2_value[tail] <= r2;
            rs1_has_depend[tail] <= has_dep1;
            rs2_has_depend[tail] <= has_dep2;
            rs1_depend[tail] <= dep1;
            rs2_depend[tail] <= dep2;
            lsb_offset[tail] <= offset;
            commit[tail] <= 1;
        end

        for(i = 0 ; i < lsb_size ; i = i + 1)begin
            if(busy[i])begin
                if((rs_ready && rs1_has_depend[i] && rs_rob_id == rs1_depend[i]))begin
                    rs1_value[i] <= rs_value;
                    rs1_has_depend[i] <= 0;
                end
                if(rs_ready && rs2_has_depend[i] && rs_rob_id == rs2_depend[i])begin
                    rs2_value[i] <= rs_value;
                    rs2_has_depend[i] <= 0;
                end
                if(ready_out && rs1_has_depend[i] && rob_id_out == rs1_depend[i])begin
                    rs1_value[i] <= value_out;
                    rs1_has_depend[i] <= 0;
                end
                if(ready_out && rs2_has_depend[i] && rob_id_out == rs2_depend[i])begin
                    rs2_value[i] <= value_out;
                    rs2_has_depend[i] <= 0;
                end
            end
        end 
    end
end
    





















    

    

    



endmodule

