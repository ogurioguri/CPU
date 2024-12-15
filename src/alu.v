`include "const.v"
module alu(
    input wire clk,
    input wire rst,
    input wire rdy,

    
    input wire valid,
    input wire [4:0] work_type,// the thrid bit is used to indicate whether the signed
    input wire [31:0] r1,
    input wire [31:0] r2,
    input wire [`robsize -1:0] inst_rob_id,
    output reg ready,
    output reg [`robsize -1:0] rob_id,
    output reg [31:0] value
);
    // the input work_type is 3 bits wide
    localparam AddSub = 3'b000;
    localparam Sll = 3'b001;
    localparam Slt = 3'b010;
    localparam Sltu = 3'b011;
    localparam Xor = 3'b100;
    localparam SrlSra = 3'b101;
    localparam Or = 3'b110;
    localparam And = 3'b111;


    localparam beq = 3'b000;
    localparam bne = 3'b001;
    localparam blt = 3'b100;
    localparam bge = 3'b101;
    localparam bltu = 3'b110;
    localparam bgeu = 3'b111;


    always @(posedge clk) begin
        if (rst) begin
            ready  <= 0;
            rob_id <= 0;
            value  <= 0;
        end
        else if (!rdy) begin
            // do nothing
        end
        else if (!valid) begin
            ready <= 0;
        end
        else begin
            ready  <= 1'b1;
            rob_id <= inst_rob_id;

            if (work_type[4]) begin
                case (work_type[2:0])
                    beq: value <= r1 == r2;
                    bne: value <= r1 != r2;
                    blt: value <= $signed(r1) < $signed(r2);
                    bge: value <= $signed(r1) >= $signed(r2);
                    bltu: value <= $unsigned(r1) < $unsigned(r2);
                    bgeu: value <= $unsigned(r1) >= $unsigned(r2);
                    
                endcase
            end
            else begin
                case (work_type[2:0])
                    AddSub: value <= work_type[3] ? r1 - r2 : r1 + r2;
                    Sll: value <= r1 << r2[4:0];
                    Slt: value <= $signed(r1) < $signed(r2);
                    Sltu: value <= $unsigned(r1) < $unsigned(r2);
                    Xor: value <= r1 ^ r2;
                    SrlSra: value <= work_type[3] ? $signed(r1) >>> r2[4:0] : r1 >> r2[4:0];
                    Or: value <= r1 | r2;
                    And: value <= r1 & r2;
                endcase
            end
        end
    end
endmodule