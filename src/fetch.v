module fetch(
    input wire clk,
    input wire rst,
    input wire rdy,

    // to rob
    input wire clear,
    input wire [31:0] new_pc,

    // to decoder
    input wire need_inst,
    input wire [31:0] new_pc_decoder,
    input wire clear_decoder,
    output reg inst_ready_out,
    output reg [31:0] inst_addr,
    output reg [31:0] inst,
    output reg is_riscv,
    
    //to cache
    output wire fetch_ready_in,
    input wire [31:0] inst_in,
    input wire instcache_ready_out,
    //for cache to find the instruction
    output reg [31:0] output_next_PC
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

    wire [6:0] opcode_origin = inst_in[6:0];
    wire is_riscv_ = inst_in[1:0] == 2'b11;

    
    reg ready_work;
    wire [31:0] next_PC;
    assign fetch_ready_in = ready_work;
    assign next_PC = clear ? new_pc : clear_decoder ? new_pc_decoder : (is_riscv_ ?  output_next_PC + 4 : output_next_PC + 2);
    wire [6:0] opcode = is_riscv_ ? inst_in[6:0] : get_opcode(inst_in);
    always @(posedge clk) begin
        if (rst) begin
            inst_ready_out <= 0;
            inst_addr <= 0;
            inst <= 0;
            ready_work <= 1;
            // begin from 0
            output_next_PC <= 0;
            is_riscv <= 0;
        end
        else if (!rdy) begin
        end
        else if (clear || (!ready_work && clear_decoder)) begin
            inst_ready_out <= 0;
            inst_addr <= 0;
            inst <= 0;
            ready_work <= 1;
            output_next_PC <= next_PC;
            is_riscv <= 0;
        end
        else if (instcache_ready_out && ready_work && need_inst && !inst_in ==0) begin
            output_next_PC <= next_PC;
            inst_ready_out <= 1;
            inst_addr <= output_next_PC;
            inst <= inst_in;
            is_riscv <= is_riscv_;

            case (opcode)
                7'b1101111, 7'b1100111, 7'b1100011: begin
                    ready_work <= 0;
                end
            endcase
        end
    end

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


  
endmodule