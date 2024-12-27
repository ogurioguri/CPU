`include "const.v"
module register_file(
    input clk,
    input rst,
    input rdy,

    //rob to register
    input clear,

    input wire need_set_reg_value,
    input wire need_set_reg_dep,
    input wire [4:0] set_value_reg_id,
    input wire [31:0] set_val,
    input wire [`robsize -1 :0] set_reg_rob_id,
    input wire [4:0] set_dep_reg_id,
    input wire [`robsize -1:0] set_dep_rob_id,

//  use assign to get the value from rob
    output wire [`robsize -1 :0] need_rob_id1,
    output wire [`robsize -1 :0] need_rob_id2,
    input wire rob_value1_ready,
    input wire [31:0] rob_value1,
    input wire rob_value2_ready,
    input wire [31:0] rob_value2,


    

    //to decoder
    input wire [4:0] id1,
    output wire has_dep1,
    output wire [`robsize -1 :0] dep1,
    output wire [31:0] value1,

    input wire [4:0] id2,
    output wire has_dep2,
    output wire [`robsize -1 :0] dep2,
    output wire [31:0] value2


);
    reg [31:0] regs[0:31];
    reg [`robsize -1 :0] depend[0:31];
    reg has_dep[0:31];
    wire has_depend1 = has_dep[id1] || (need_set_reg_dep && set_dep_reg_id == id1);
    wire has_depend2 = has_dep[id2] || (need_set_reg_dep && set_dep_reg_id == id2);
    assign value1 = has_depend1 ? rob_value1 : regs[id1];
    assign value2 = has_depend2 ? rob_value2 : regs[id2];
    /* assign has_dep1 = has_depend1 && !rob_value1_ready; */
    assign has_dep1 = has_depend1 && !(rob_value1_ready);
    assign has_dep2 = has_depend2 && !(rob_value2_ready);
    //assign dep1 = dep[id1]; 
    //assign dep2 = dep[id2];
    assign dep1 = (need_set_reg_dep && set_dep_reg_id == id1) ? set_dep_rob_id : depend[id1];
    assign dep2 = (need_set_reg_dep && set_dep_reg_id == id2) ? set_dep_rob_id : depend[id2];
    assign need_rob_id1 = dep1;
    assign need_rob_id2 = dep2;

    integer i;
    always @(posedge clk) begin  
   
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 0;
                depend[i] <= 0;
                has_dep[i] <= 0;
            end
        end
        else if (!rdy) begin
            // do nothing
        end
        //clear the register rely
        else if (clear) begin
            for (i = 0; i < 32; i = i + 1) begin
                depend[i] <= 0;
                has_dep[i] <= 0;
            end
        end
        else begin
            if (need_set_reg_value) begin
                regs[set_value_reg_id] <= set_val;
                if ((!need_set_reg_dep || (need_set_reg_dep && set_dep_reg_id != set_value_reg_id)) && set_reg_rob_id == depend[set_value_reg_id]) begin
                    has_dep[set_value_reg_id] <= 0;
                    depend[set_value_reg_id] <= 0;
                end
            end
            if(need_set_reg_dep) begin
                depend[set_dep_reg_id] <= set_dep_rob_id;
                has_dep[set_dep_reg_id] <= 1;
            end
            regs[0] <= 0;
            has_dep[0] <= 0;
            depend[0] <= 0;
        end
    end

    /* wire [31:0] zero = regs[0];
    wire [31:0] ra = regs[1];
    wire [31:0] sp = regs[2];
    wire [31:0] gp = regs[3];
    wire [31:0] tp = regs[4];
    wire [31:0] t0 = regs[5];
    wire [31:0] t1 = regs[6];
    wire [31:0] t2 = regs[7];
    wire [31:0] s0 = regs[8];
    wire [31:0] s1 = regs[9];
    wire [31:0] a0 = regs[10];
    wire [31:0] a1 = regs[11];
    wire [31:0] a2 = regs[12];
    wire [31:0] a3 = regs[13];
    wire [31:0] a4 = regs[14];
    wire [31:0] a5 = regs[15];
    wire [31:0] a6 = regs[16];
    wire [31:0] a7 = regs[17];
    wire [31:0] s2 = regs[18];
    wire [31:0] s3 = regs[19];
    wire [31:0] s4 = regs[20];
    wire [31:0] s5 = regs[21];
    wire [31:0] s6 = regs[22];
    wire [31:0] s7 = regs[23];
    wire [31:0] s8 = regs[24];
    wire [31:0] s9 = regs[25];
    wire [31:0] s10 = regs[26];
    wire [31:0] s11 = regs[27];
    wire [31:0] t3 = regs[28];
    wire [31:0] t4 = regs[29];
    wire [31:0] t5 = regs[30];
    wire [31:0] t6 = regs[31];
    wire zero_has_dep = has_dep[0];
    wire ra_has_dep = has_dep[1];
    wire sp_has_dep = has_dep[2];
    wire gp_has_dep = has_dep[3];
    wire tp_has_dep = has_dep[4];
    wire t0_has_dep = has_dep[5];
    wire t1_has_dep = has_dep[6];
    wire t2_has_dep = has_dep[7];
    wire s0_has_dep = has_dep[8];
    wire s1_has_dep = has_dep[9];
    wire a0_has_dep = has_dep[10];
    wire a1_has_dep = has_dep[11];
    wire a2_has_dep = has_dep[12];
    wire a3_has_dep = has_dep[13];
    wire a4_has_dep = has_dep[14];
    wire a5_has_dep = has_dep[15];
    wire a6_has_dep = has_dep[16];
    wire a7_has_dep = has_dep[17];
    wire s2_has_dep = has_dep[18];
    wire s3_has_dep = has_dep[19];
    wire s4_has_dep = has_dep[20];
    wire s5_has_dep = has_dep[21];
    wire s6_has_dep = has_dep[22];
    wire s7_has_dep = has_dep[23];
    wire s8_has_dep = has_dep[24];
    wire s9_has_dep = has_dep[25];
    wire s10_has_dep = has_dep[26];
    wire s11_has_dep = has_dep[27];
    wire t3_has_dep = has_dep[28];
    wire t4_has_dep = has_dep[29];
    wire t5_has_dep = has_dep[30];
    wire t6_has_dep = has_dep[31];
    wire [`robsize -1 :0]zero_dep_rob_id = depend[0];
    wire [`robsize -1 :0]ra_dep_rob_id = depend[1];
    wire [`robsize -1 :0]sp_dep_rob_id = depend[2];
    wire[`robsize -1 :0] gp_dep_rob_id = depend[3];
    wire [`robsize -1 :0]tp_dep_rob_id = depend[4];
    wire [`robsize -1 :0]t0_dep_rob_id = depend[5];
    wire [`robsize -1 :0]t1_dep_rob_id = depend[6];
    wire[`robsize -1 :0] t2_dep_rob_id = depend[7];
    wire [`robsize -1 :0]s0_dep_rob_id = depend[8];
    wire[`robsize -1 :0] s1_dep_rob_id = depend[9];
    wire[`robsize -1 :0] a0_dep_rob_id = depend[10];
    wire [`robsize -1 :0]a1_dep_rob_id = depend[11];
    wire [`robsize -1 :0]a2_dep_rob_id =depend[12];
    wire [`robsize -1 :0]a3_dep_rob_id = depend[13];
    wire [`robsize -1 :0]a4_dep_rob_id = depend[14];
    wire[`robsize -1 :0] a5_dep_rob_id = depend[15];
    wire [`robsize -1 :0]a6_dep_rob_id = depend[16];
    wire [`robsize -1 :0]a7_dep_rob_id = depend[17];
    wire[`robsize -1 :0] s2_dep_rob_id =depend[18];
    wire[`robsize -1 :0] s3_dep_rob_id = depend[19];
    wire[`robsize -1 :0] s4_dep_rob_id = depend[20];
    wire[`robsize -1 :0] s5_dep_rob_id = depend[21];
    wire[`robsize -1 :0] s6_dep_rob_id = depend[22];
    wire[`robsize -1 :0] s7_dep_rob_id = depend[23];
    wire[`robsize -1 :0] s8_dep_rob_id = depend[24];
    wire[`robsize -1 :0] s9_dep_rob_id = depend[25];
    wire[`robsize -1 :0] s10_dep_rob_id = depend[26];
    wire[`robsize -1 :0] s11_dep_rob_id = depend[27];
    wire [`robsize -1 :0]t3_dep_rob_id = depend[28];
    wire[`robsize -1 :0] t4_dep_rob_id = depend[29];
    wire[`robsize -1 :0] t5_dep_rob_id = depend[30];
    wire[`robsize -1 :0] t6_dep_rob_id = depend[31]; */

endmodule