`include "const.v"
module register_file(
    input clk;
    input rst;
    input rdy;

    //rob to register
    input clear;

    input wire need_set_reg_value;
    input wire need_set_reg_dep;
    input wire [4:0] set_value_reg_id;
    input wire [31:0] set_val;
    input wire [`robsize:0] set_reg_rob_id;
    input wire[4:0] set_dep_reg_id;
    input wire [`robsize:0] set_dep_rob_id;

//  use assign to get the value from rob
    output wire [4:0] need_rob_id1;
    output wire [4:0] need_rob_id2;
    input wire rob_value1_ready;
    input wire [31:0] rob_value1;
    input wire rob_value2_ready;
    input wire [31:0] rob_value2;

    

    //to decoder
    input wire [4:0] id1;
    output wire has_dep1;
    output wire [`robsize:0] dep1;
    output wire [31:0] value1;

    input wire [4:0] id2;
    output wire has_dep2;
    output wire [`robsize:0] dep2;
    output wire [31:0] value2;


);
    reg [31:0] regs[0:31];
    reg [`robsize:0] depend[0:31];
    reg has_dep[0:31];
    wire has_depend1 = has_dep[id1] || (need_set_reg_dep && set_dep_reg_id == id1);
    wire has_depend2 = has_dep[id2] || (need_set_reg_dep && set_dep_reg_id == id2);
    assign value1 = has_depend1 ? rob_value1 : regs[id1];
    assign value2 = has_depend2 ? rob_value2 : regs[id2];
    assign has_dep1 = has_depend1 && !rob_value1_ready;
    assign has_dep2 = has_depend2 && !rob_value2_ready;
    //assign dep1 = dep[id1];
    //assign dep2 = dep[id2];
    assign dep1 = set_dep_reg_id == id1 ? set_dep_rob_id : dep[id1];
    assign dep2 = set_dep_reg_id == id2 ? set_dep_rob_id : dep[id2];
    assign need_rob_id1 = dep1;
    assign need_rob_id2 = dep2;

    integer i;
    always @(posedge clk) begin : 
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 0;
                dep[i] <= 0;
                has_dep[i] <= 0;
            end
        end
        else if (!rdy) begin
            // do nothing
        end
        //clear the register rely
        else if (clear) begin
            for (i = 0; i < 32; i = i + 1) begin
                dep[i] <= 0;
                has_dep[i] <= 0;
            end
        end
        else begin
            if (need_set_reg_value) begin
                regs[set_value_reg_id] <= set_val;
                dep[set_value_reg_id] <= set_reg_rob_id;
                has_dep[set_value_reg_id] <= 0;
            end
            if(need_set_reg_dep) begin
                dep[set_dep_reg_id] <= set_dep_rob_id;
                has_dep[set_dep_reg_id] <= 1;
            end
        end
    end

endmodule