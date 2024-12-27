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
    input wire is_riscv,

    /* //to decoder_c
    output wire [15:0] inst_c,
    output wire to_c_ready,
    input wire c_need_inst, */

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


localparam AddSub = 3'b000;
localparam Sll =  3'b001;
localparam Slt =  3'b010;
localparam Sltu = 3'b011;
localparam Xor =  3'b100;
localparam Or =   3'b110;
localparam And =  3'b111;
localparam Srl =  3'b101;
localparam Sra =  3'b101;

localparam Beq =  3'b000;
localparam Bne =  3'b001;
localparam Blt =  3'b100;
localparam Bge =  3'b101;
localparam Bltu = 3'b110;
localparam Bgeu = 3'b111;

localparam Lb =   3'b000;
localparam Lh =   3'b001;
localparam Lw =   3'b010;
localparam Lbu =  3'b100;
localparam Lhu =  3'b101;
localparam Sb =  3'b000;
localparam Sh =  3'b001;
localparam Sw =  3'b010;

localparam [6:0] opcode_j = 7'b1101111;
localparam [6:0] opcode_r = 7'b0110011;
localparam [6:0] opcode_i = 7'b0010011;
localparam [6:0] opcode_l = 7'b0000011;
localparam [6:0] opcode_jalr = 7'b1100111;
localparam [6:0] opcode_b = 7'b1100011;
localparam [6:0] opcode_s = 7'b0100011;
localparam [6:0] opcode_lui = 7'b0110111;
localparam [6:0] opcode_auipc = 7'b0010111;







wire [4:0] rs1 = is_riscv ? inst_in[19:15] : get_rs1(inst_in);
wire [4:0] rs2 = is_riscv ? inst_in[24:20] : get_rs2(inst_in);
wire [4:0] rd  = is_riscv ? inst_in[11:7] : get_rd(inst_in);

wire [4:0] shamt = inst_in[24:20];
wire [31:12] immU = inst_in[31:12];
wire [20:1] immJ = {inst_in[31], inst_in[19:12], inst_in[20], inst_in[30:21]};
wire [11:0] immI = inst_in[31:20];
wire [12:1] immB = {inst_in[31], inst_in[7], inst_in[30:25], inst_in[11:8]};
wire [11:0] immS = {inst_in[31:25], inst_in[11:7]};

wire [6:0] opcode = is_riscv ? inst_in[6:0] : get_opcode(inst_in);
wire [2:0] function3 = is_riscv ? inst_in[14:12] : get_function3(inst_in);
wire [7:0] function7 = inst_in[31:25] ;
wire [31:0] c_imm  = get_imm(inst_in);
wire op = is_riscv ? inst_in[30] : get_add(inst_in);  

reg [31:0] rs1_value; // ask the register file to get this
reg [31:0] rs2_value;

reg [31:0] last_inst_addr;
wire need_rs;
wire need_lsb;
wire need_rs1;
wire need_rs2;
wire rs1_need_ready;


assign need_rs = (opcode == opcode_b) || (opcode == opcode_r) || (opcode == opcode_i);
assign need_lsb = (opcode == opcode_l) || (opcode == opcode_s);

assign need_rs1 = opcode == opcode_jalr || opcode == opcode_r || opcode == opcode_i || opcode == opcode_s || opcode == opcode_b || opcode == opcode_l;
assign need_rs2 = opcode == opcode_r || opcode == opcode_s || opcode == opcode_b;
assign rs1_need_ready = opcode == opcode_jalr;
reg is_dep1;
reg is_dep2;
reg [`reg_size:0] dep1;
reg [`reg_size:0] dep2;

wire need_begin = last_inst_addr != PC && !rob_full && (!rs_full || !need_rs) && (!lsb_full || !need_lsb) && !(rs1_need_ready && has_dep1)  && instcache_ready_out;
assign need_inst = !(((last_inst_addr != PC) && instcache_ready_out) && ((need_rs && rs_full) || (need_lsb && lsb_full) || rob_full || (rs1_need_ready && has_dep1)));
wire [31:0] next_rs2_val = opcode == opcode_i ? (is_riscv ? ((function3 == 3'b001 || function3 == 3'b101) ? shamt : {{20{immI[11]}}, immI}) : c_imm) : rs2_reg_value;
wire predict= 1'b1;

always @(posedge clk) begin
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
    else  begin
        to_rob_ready <= 1;
        to_lsb_ready <= need_lsb;
        to_rs_ready <= need_rs;

        last_inst_addr <= PC;

        rob_type <= inst_in == 32'hff9ff06f ? `robtype_exit : (opcode == opcode_b ? `robtype_b : (opcode == opcode_s ? `robtype_s : `robtype_r));
        lsb_type <= {function3,!(opcode == opcode_l)};
        rs_type <= {function3,(opcode == opcode_r && op),(opcode == opcode_b)};

        rs1_value <= rs1_reg_value;
        rs2_value <= next_rs2_val;
        is_dep1 <=(need_rs1 && has_dep1);
        is_dep2 <=(need_rs2 && has_dep2);
        dep1 <= input_dep1;
        dep2 <= input_dep2;
        rob_rd <= rd;   

        lsb_offset <= is_riscv ? ((opcode == opcode_l) ? immI : immS) : c_imm;
        rob_address <= PC;
        rob_jump_address <= is_riscv ? PC + 4 : PC + 2 ;
        inst_ready <= opcode == opcode_lui || opcode == opcode_auipc || opcode == opcode_j || opcode == opcode_jalr;
    

        case(opcode)
            opcode_auipc:begin
                rob_imm <= is_riscv ?  PC + {immU, 12'b0} : PC + c_imm;
            end
            opcode_jalr:begin
                rob_imm <= is_riscv ? PC + 4 : PC + 2 ;
                clear_inst <= 1;
                if_addr <= is_riscv ? ((rs1_reg_value + {{20{immI[11]}}, immI}) & ~32'b1) : ((rs1_reg_value + c_imm) & ~32'b1);
            end
            opcode_b:begin
                clear_inst <= 1;
                if_addr <= PC +  (is_riscv ? {{19{immB[11]}}, immB, 1'b0} : c_imm);
            end
            opcode_j:begin
                rob_imm <= is_riscv ? PC + 4 : PC + 2 ;
                clear_inst <= 1;
                if_addr <= PC + (is_riscv ? {{19{immJ[11]}}, immJ, 1'b0} : c_imm); 
            end
            opcode_lui:begin
                rob_imm <= is_riscv ? {immU, 12'b0} : c_imm;
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
/* always @(*) begin
    $display("pc = 0x%h", PC);
end */
/* assign need_inst = !need_begin; */
assign rs1_reg_id = need_rs1 ? rs1:0;
assign rs2_reg_id = need_rs2 ? rs2:0;

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


function [4:0] get_rs1;
        input [31:0] inst;
        case (inst[1:0])
            2'b00: get_rs1 = (inst[15:13] == 3'b000) ? 2 : 8 + inst[9:7];
            2'b01: begin
                case (inst[15:13])
                    3'b000: get_rs1 = inst[11:7];
                    3'b001,3'b010,3'b101: get_rs1 = 0;
                    3'b011: get_rs1 = (inst[11:7] == 2) ? 2 : 0;
                    3'b100,3'b110,3'b111:get_rs1 = 8 + inst[9:7];
                endcase
            end
            2'b10:begin
                case (inst[15:13])
                    3'b000: get_rs1 = inst[11:7];
                    3'b010 , 3'b110 : get_rs1 = 2;
                    3'b100 :case (inst[12])
                        1'b0: get_rs1 = (inst[6:2] == 5'b00000) ? inst[11:7] : 0;
                        1'b1: get_rs1 = inst[11:7];
                    endcase
                endcase
            end
        endcase
    endfunction

    function [4:0] get_rs2;
        input [31:0] inst;
        case(inst[1:0])
            2'b00 : get_rs2 = (inst[15:13] == 3'b110) ? 8 + inst[4:2]: 0;  
            2'b01 : get_rs2 = (inst[15:13] == 3'b100 && inst[11:10] == 2'b11) ? 8 + inst[4:2] : 0;
            2'b10 : get_rs2 = (inst[15:13] == 3'b100 || inst[15:13] == 3'b110) ? inst[6:2] : 0;
        endcase
    endfunction

    function [6:0] get_opcode;
        input [31:0] inst;
        case (inst[1:0])
            2'b00: case (inst[15:13])
                3'b000: get_opcode = opcode_i;
                3'b010: get_opcode = opcode_l;
                3'b110: get_opcode = opcode_s;
            endcase
            2'b01: begin
                case (inst[15:13])
                    3'b000: get_opcode = opcode_i;
                    3'b001: get_opcode = opcode_j;
                    3'b010: get_opcode = opcode_i;
                    3'b011: get_opcode = (inst[11:7] == 2) ? opcode_i : opcode_lui;
                    3'b100: get_opcode = (inst[11:10] == 2'b11) ? opcode_r :opcode_i; 
                    3'b101: get_opcode = opcode_j;
                    3'b110: get_opcode = opcode_b;
                    3'b111: get_opcode = opcode_b;
                endcase
            end
            2'b10: begin
                case (inst[15:13])
                    3'b000: get_opcode  = opcode_i;
                    3'b010: get_opcode  = opcode_l;
                    3'b100: get_opcode  = (inst[6:2] == 5'b00000) ? opcode_jalr : opcode_r;
                    3'b110: get_opcode  = opcode_s;
                endcase
            end
        endcase
    endfunction

    function [4:0] get_rd;
        input [31:0] inst;
        case (inst[1:0])
            2'b00: get_rd = (inst[15:13] == 3'b110) ? 0 : 8 + inst[4:2];
            2'b01: begin
                case (inst[15:13])
                    3'b000: get_rd = inst[11:7];
                    3'b001: get_rd = 1;
                    3'b010: get_rd = inst[11:7];
                    3'b011: get_rd = inst[11:7];
                    3'b100: get_rd = 8 + inst[9:7];
                    3'b101: get_rd = 0;
                    3'b110: get_rd = 0;
                    3'b111: get_rd = 0;
                endcase
            end
            2'b10:begin
                case (inst[15:13])
                    3'b000: get_rd = inst[11:7];
                    3'b010: get_rd = inst[11:7];
                    3'b100 :case (inst[12])
                        1'b0: get_rd = (inst[6:2] == 5'b00000) ? 0  : inst[11:7];
                        1'b1: get_rd = (inst[6:2] == 5'b00000) ? 1 : inst[11:7];
                    endcase
                    3'b110:get_rd = 0;
                endcase
            end
        endcase
    endfunction


    function [2:0]get_function3;
        input [31:0] inst;
        case (inst[1:0])
            2'b00: case (inst[15:13])
            //add sub judge specially
                3'b000: get_function3 = AddSub;
                3'b010: get_function3 = Lw;
                3'b110: get_function3 = Or;
                3'b111: get_function3 = Sw;
            endcase
            2'b01: begin
                case (inst[15:13])
                    3'b000: get_function3 = AddSub;
                    3'b001: get_function3 = 0;
                    3'b010: get_function3 = AddSub;
                    3'b011: get_function3 = (inst[11:7] == 2) ? AddSub :0;
                    3'b100: case (inst[11:10])
                        2'b00: get_function3 = Srl;
                        2'b01: get_function3 = Sra;
                        2'b10: get_function3 = And;
                        2'b11: begin
                            case (inst[6:5])
                                2'b00: get_function3 = AddSub;
                                2'b01: get_function3 = Xor;
                                2'b10: get_function3 = Or;
                                2'b11: get_function3 = And;
                            endcase
                        end
                    endcase
                    3'b101: get_function3 = 0;
                    3'b110: get_function3 = Beq;
                    3'b111: get_function3 = Bne;
                endcase
            end
            2'b10:begin
                case (inst[15:13])
                    3'b000: get_function3 = Sll;
                    3'b010: get_function3 = Lw;
                    3'b100 : get_function3 = (inst[6:2] == 5'b00000) ? 0 : AddSub;
                    3'b110: get_function3= Sw;
                endcase
            end
        endcase
    endfunction
    
    function [31:0]get_imm;
        input [31:0] inst;
        case (inst[1:0])
            2'b00: case (inst[15:13])
                3'b000: get_imm = {22'b0,inst[10:7],inst[12:11],inst[5],inst[6],2'b0};
                default: get_imm =  {25'b0,inst[5],inst[12:10],inst[6],2'b0};
            endcase
           2'b01: begin
                case (inst[15:13])
                    3'b000: get_imm = {{27{inst[12]}},inst[6:2]};
                    3'b010: get_imm = {{27{inst[12]}},inst[6:2]};
                    3'b001: get_imm = {{21{inst[12]}},inst[8],inst[10:9],inst[6],inst[7],inst[2],inst[11],inst[5:3],1'b0};
                    3'b101: get_imm = {{21{inst[12]}},inst[8],inst[10:9],inst[6],inst[7],inst[2],inst[11],inst[5:3],1'b0};
                    3'b011: get_imm = (inst[11:7] == 2) ? {{23{inst[12]}},inst[4:3],inst[5],inst[2],inst[6],4'b0} : {{15{inst[12]}},inst[6:2],12'b0};
                    3'b100: case (inst[11:10])
                        2'b00:get_imm = {26'b0,inst[12],inst[6:2]};
                        2'b01:get_imm = {26'b0,inst[12],inst[6:2]};
                        2'b10:get_imm = {{27{inst[12]}},inst[6:2]};
                        2'b11:get_imm = 0;
                    endcase
                    3'b110,3'b111: get_imm = {{24{inst[12]}},inst[6:5],inst[2],inst[11:10],inst[4:3],1'b0};
                endcase
            end
            2'b10: begin
                case (inst[15:13])
                    3'b000: get_imm = {26'b0,inst[12],inst[6:2]};
                    3'b010: get_imm= {24'b0,inst[3:2],inst[12],inst[6:4],2'b0};
                    3'b100: get_imm = 0;
                    3'b110: get_imm= {24'b0,inst[8:7],inst[12:9],2'b0};
                endcase
            end
        endcase
    endfunction

    function get_add;
        input [31:0] inst;
        case (inst[1:0])
            2'b00,2'b10: get_add = 0;
            2'b01: begin
                case (inst[15:13])
                    3'b100: case (inst[11:10])
                        2'b01:get_add = 1; //sra
                        2'b11:get_add = (inst[6:5] == 2'b00) ? 1 : 0; //sub
                        default:get_add = 0;
                    endcase
                    default: get_add = 0;
                endcase
            end
        endcase
    endfunction    

endmodule