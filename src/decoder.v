'include "reorder_buffer.v"
'include "const.v"

module decoder(){

    
    input wire clk,
    input wire rst,
    input wire rdy,
    // to fetch
    output wire need_inst,
    input wire [31:0] PC,
    input wire [31:0] inst_in,
    input wire instcache_ready_out,
    output wire [31:0] next_PC,

    // to reorder buffer
    output wire to_rob_ready,
    /* output reg [4:0] rob_rs1;
    output reg [4:0] rob_rs2; */
    output reg [4:0] rob_rd,
    /* output wire rob_rs1_valid;
    output wire rob_rs2_valid;  */
    output wire [1:0] rob_type,
    output wire [31:0] rob_imm,
    output wire [31 : 0] rob_address,
    output wire rob_jump,
    output wire rob_pc,

    input wire next_position,


    //to lsb
    input wire lsb_full,
    output wire to_lsb_ready,
    output wire [31 : 0] lsb_r1,
    output wire [31 : 0] lsb_r2,
    output wire [11 : 0] lsb_offset,
    output wire [`reg_size : 0] lsb_rd,
    output wire [`robsize : 0] lsb_dep1,
    output wire [`robsize : 0] lsb_dep2,
    output wire lsb_has_dep1,
    output wire lsb_has_dep2,
    output wire [`rob_size : 0] lsb_rob_id,
    output wire [`lsb_type_size : 0] lsb_type,

    //to reservation station
    input wire rs_full,
    output wire to_rs_ready,
    output [4 : 0] rs_rd,
    output [31 : 0] rs_r1,
    output [31 : 0] rs_r2,
    output [`reg_size: 0] rs_dep1,
    output [`reg_size : 0] rs_dep2,
    output rs_has_dep1,
    output rs_has_dep2,
    output [`robsize : 0] rs_rob_id,
    output [`rs_type_size : 0] rs_type,   

    // to register 
    input wire [31 : 0] rs1_reg_value,
    input wire [31 : 0] rs2_reg_value,
    input wire has_dep1,
    input wire has_dep2,
    input wire [`robsize : 0] input_dep1,
    input wire [`robsize : 0] input_dep2,


    // clear the inst
    output wire clear_inst

};

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

reg [31:0] last_instrution_address;


assign wire need_rs = (opcode == opcode_b) || (opcode == opcode_r) || (opcode == opcode_i);
assign wire need_lsb = (opcode == opcode_l) || (opcode == opcode_s);


wire need_rs1 = opcode == opcode_jalr || opcode == opcode_r || opcode == opcode_i || opcode == opcode_s || opcode == opcode_b || opcode == opcode_l;
wire need_rs2 = opcode == opcode_r || opcode == opcode_s || opcode == opcode_b;
reg is_dep1;
reg is_dep2;
reg [reg_size:0] dep1;
reg [reg_size:0] dep2;

assign wire need_begin = last_inst_addr != PC && !rob_full && (!rs_full || !need_rs) && (!lsb_full || !need_lsb)  && instcache_ready_out;
wire [31:0] next_rs2_val = opcode == CodeArithI ? ((func == 3'b001 || func == 3'b101) ? shamt : {{20{immI[11]}}, immI}) : rs2_val_in;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        next_PC <= 0;
        rs1_value <= 0;
        rs2_value <= 0;
        last_instrution_address <= 32'hffffffff;
        to_rob_ready <= 0;
        rob_valid <= 0;
        lsb_valid <= 0;
        rs_valid <= 0;
        clear_inst <= 0;
    end
    else if(!rst){
        // 
    }
    else if (!(need_begin))begin
        to_rob_ready <= 0;
        to_lsb_ready <= 0;
        to_rs_ready <= 0;
        need_inst <= 0;
        clear_inst <= 0;
    end
    else if(need_begin) begin
        to_rob_ready <= 1;
        to_lsb_ready <= need_lsb;
        to_rs_ready <= need_rs;

        last_inst_addr <= PC;
        need_inst <= 1;

        rob_type <= inst == 32'hff9ff06f ? `robtype_exit : (opcode == opcode_b ? `robtype_b : (opcode == opcode_s ? `robtype_s : `robtype_r));
        lsb_type <= {func,!(opcode == opcode_l)};
        rs_type <= {func,(opcode == opcode_b)};

        rob_rd <= rd;

        rs1_value <= rs1_reg_value;
        rs2_value <= next_rs2_val;
        is_dep1 <=(need_rs1 && has_dep1);
        is_dep2 <=(need_rs2 && has_dep2);
        dep1 <= input_dep1;
        dep2 <= input_dep2;

        lsb_offset <= (opcode == opcode_l) ? immI : immS;
        rob_address <= inst_addr;
        rob_jump <= opcode == opcode_lui || opcode == opcode_auipc || opcode == opcode_jalr || opcode == opcode_j;

        case(opcode)
            opcode_auipc:begin
                 rob_imm <= inst_addr + {immU, 12'b0};
            end
            opcode_jalr:begin
                rob_imm <= inst_addr + 4;
                clear_inst <= 1;
                
            end
            opcode_b:begin
                clear_inst <= 1;
            end
            opcode_j:begin
                rob_imm <= inst_addr + 4;
                clear_inst <= 1;
            end
            opcode_lui:begin
                rob_imm <= immU;
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
assign rob_rd = rd;

assign rs_r1 = rs1_value;
assign rs_r2 = rs2_value;
assign rs_rd = rd;
assign rs_dep1 = dep1;  
assign rs_dep2 = dep2;
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