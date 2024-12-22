`include "const.v"
module decoder(

    
    input wire clk,
    input wire rst,
    input wire rdy,
    // to fetch
    output wire need_inst,
    input wire [31:0] PC,
    input wire [31:0] inst_in,
    input wire instcache_ready_out,

    // to reorder buffer
    output reg to_rob_ready,
    /* output reg [4:0] rob_rs1;
    output reg [4:0] rob_rs2; */
    output reg [4:0] rob_rd,
    /* output wire rob_rs1_valid;
    output wire rob_rs2_valid;  */
    output reg [`rob_type_bit -1 :0] rob_type,
    output reg [31:0] rob_imm,
    output reg [31 : 0] rob_address,
    output reg [31 : 0]rob_jump_address,
    output reg inst_ready,
    input wire rob_full,
    input wire [`robsize -1 : 0] next_position,



    //to lsb
    input wire lsb_full,

    
    output reg to_lsb_ready,
    output wire [31 : 0] lsb_r1,
    output wire [31 : 0] lsb_r2,
    output reg [11 : 0] lsb_offset,
    output wire [`reg_size -1 : 0] lsb_rd,
    output wire [`robsize -1 : 0] lsb_dep1,
    output wire [`robsize -1 : 0] lsb_dep2,
    output wire lsb_has_dep1,
    output wire lsb_has_dep2,
    output wire [`robsize -1 : 0] lsb_rob_id,
    output reg [`lsb_type_size -1 : 0] lsb_type,

    //to reservation station
    input wire rs_full,
    output reg to_rs_ready,
    output wire [4 : 0] rs_rd,
    output wire [31 : 0] rs_r1,
    output wire [31 : 0] rs_r2,
    output wire [`robsize -1: 0] rs_dep1,
    output wire [`robsize -1 : 0] rs_dep2,
    output wire rs_has_dep1,
    output wire rs_has_dep2,
    output wire [`robsize -1 : 0] rs_rob_id,
    output reg [`rs_type_size -1 : 0] rs_type,   

    // to register 
    input wire [31 : 0] rs1_reg_value,
    input wire [31 : 0] rs2_reg_value,
    input wire has_dep1,
    input wire has_dep2,
    input wire [`robsize -1 : 0] input_dep1,
    input wire [`robsize -1 : 0] input_dep2,
    output wire [4:0] rs1_reg_id,
    output wire [4:0] rs2_reg_id,


    // clear the inst
    output reg clear_inst,
    output reg [31:0] if_addr



);

localparam [6:0] opcode_j = 7'b1101111;
localparam [6:0] opcode_r = 7'b0110011;
localparam [6:0] opcode_i = 7'b0010011;
localparam [6:0] opcode_l = 7'b0000011;
localparam [6:0] opcode_jalr = 7'b1100111;
localparam [6:0] opcode_b = 7'b1100011;
localparam [6:0] opcode_s = 7'b0100011;
localparam [6:0] opcode_lui = 7'b0110111;
localparam [6:0] opcode_auipc = 7'b0010111;

wire [4:0] rs1 = inst_in[19:15];
wire [4:0] rs2 = inst_in[24:20];
wire [4:0] rd  =  inst_in[11:7];
wire [4:0] shamt = inst_in[24:20];
wire [31:12] immU = inst_in[31:12];
wire [20:1] immJ = {inst_in[31], inst_in[19:12], inst_in[20], inst_in[30:21]};
wire [11:0] immI = inst_in[31:20];
wire [12:1] immB = {inst_in[31], inst_in[7], inst_in[30:25], inst_in[11:8]};
wire [11:0] immS = {inst_in[31:25], inst_in[11:7]};

wire [6:0] opcode = inst_in[6:0];
wire [2:0] function3 = inst_in[14:12];
wire [7:0] function7 = inst_in[31:25];
reg [31:0] rs1_value; // ask the register file to get this
reg [31:0] rs2_value;

reg [31:0] last_inst_addr;
wire need_rs;
wire need_lsb;
wire need_rs1;
wire need_rs2;


assign need_rs = (opcode == opcode_b) || (opcode == opcode_r) || (opcode == opcode_i);
assign need_lsb = (opcode == opcode_l) || (opcode == opcode_s);

assign need_rs1 = opcode == opcode_jalr || opcode == opcode_r || opcode == opcode_i || opcode == opcode_s || opcode == opcode_b || opcode == opcode_l;
assign need_rs2 = opcode == opcode_r || opcode == opcode_s || opcode == opcode_b;
reg is_dep1;
reg is_dep2;
reg [`reg_size:0] dep1;
reg [`reg_size:0] dep2;

wire need_begin = last_inst_addr != PC && !rob_full && (!rs_full || !need_rs) && (!lsb_full || !need_lsb)  && instcache_ready_out;
wire [31:0] next_rs2_val = opcode == opcode_i ? ((function3 == 3'b001 || function3 == 3'b101) ? shamt : {{20{immI[11]}}, immI}) : rs2_reg_value;
wire predict= 1'b1;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        rs1_value <= 0;
        rs2_value <= 0;
        // can not be 0
        last_inst_addr <= 32'habcdefff;

        to_rob_ready <= 0;
        rob_rd <= 0;
        rob_type <= 0;
        rob_imm <= 0;
        rob_address <= 0;
        rob_jump_address<= 0;
        inst_ready <= 0;

        to_lsb_ready <= 0;
        lsb_type <= 0;
        lsb_offset <= 0; 

        to_rs_ready <= 0;
        rs_type <= 0;

        clear_inst <= 0;
        if_addr <= 0;  

    end
    else if(!rdy)begin
    end
    else if (!(need_begin))begin
        to_rob_ready <= 0;
        to_lsb_ready <= 0;
        to_rs_ready <= 0;
        clear_inst <= 0;
    end
    else if(need_begin) begin
        to_rob_ready <= 1;
        to_lsb_ready <= need_lsb;
        to_rs_ready <= need_rs;

        last_inst_addr <= PC;

        rob_type <= inst_in == 32'hff9ff06f ? `robtype_exit : (opcode == opcode_b ? `robtype_b : (opcode == opcode_s ? `robtype_s : `robtype_r));
        lsb_type <= {function3,!(opcode == opcode_l)};
        rs_type <= {function3,(opcode == opcode_r && inst_in[30]),(opcode == opcode_b)};

        rs1_value <= rs1_reg_value;
        rs2_value <= next_rs2_val;
        is_dep1 <=(need_rs1 && has_dep1);
        is_dep2 <=(need_rs2 && has_dep2);
        dep1 <= input_dep1;
        dep2 <= input_dep2;
        rob_rd <= rd;   

        lsb_offset <= (opcode == opcode_l) ? immI : immS;
        rob_address <= PC;
        rob_jump_address <= PC + 4;
        inst_ready <= opcode == opcode_lui || opcode == opcode_auipc || opcode == opcode_j || opcode == opcode_jalr;
    

        case(opcode)
            opcode_auipc:begin
                rob_imm <= PC + {immU, 12'b0};
            end
            opcode_jalr:begin
                rob_imm <= PC + 4;
                clear_inst <= 1;
                if_addr <= (rs1_reg_value + {{20{immI[11]}}, immI}) & ~32'b1;
            end
            opcode_b:begin
                clear_inst <= 1;
                if_addr <= PC + {{19{immB[11]}}, immB, 1'b0};
            end
            opcode_j:begin
                rob_imm <= PC + 4;
                clear_inst <= 1;
                if_addr <= PC + {{19{immJ[11]}}, immJ, 1'b0}; 
            end
            opcode_lui:begin
                rob_imm <=  {immU, 12'b0};
            end
            opcode_s:begin
            end 
            opcode_l:begin
            end
            opcode_i:begin
            end 
        endcase
    end

end
assign need_inst = !need_begin;
assign rs1_reg_id = rs1;
assign rs2_reg_id = rs2;

assign rs_r1 = rs1_value;
assign rs_r2 = rs2_value;
assign rs_rd = rd;
assign rs_dep1 = dep1;  
assign rs_dep2 = dep2;
assign rs_has_dep1 = is_dep1;
assign rs_has_dep2 = is_dep2;
assign rs_rob_id = next_position;


assign lsb_r1 = rs1_value;
assign lsb_r2 = rs2_value;
assign lsb_dep1 = dep1;
assign lsb_dep2 = dep2;
assign lsb_has_dep1 = is_dep1;
assign lsb_has_dep2 = is_dep2;
assign lsb_rob_id = next_position;
assign lsb_rd = rd;

endmodule