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
    
    //to cache
    output wire fetch_ready_in,
    input wire [31:0] inst_in,
    input wire instcache_ready_out,
    //for cache to find the instruction
    output reg [31:0] output_next_PC
);


    
    reg ready_work;
    wire [31:0] next_PC;
    assign fetch_ready_in = ready_work;
    assign next_PC = clear ? new_pc : clear_decoder ? new_pc_decoder : output_next_PC + 4;
    always @(posedge clk) begin
        if (rst) begin
            inst_ready_out <= 0;
            inst_addr <= 0;
            inst <= 0;
            ready_work <= 1;
            // begin from 0
            output_next_PC <= 0;
        end
        else if (!rdy) begin
        end
        else if (clear || (!ready_work && clear_decoder)) begin
            inst_ready_out <= 0;
            inst_addr <= 0;
            inst <= 0;
            ready_work <= 1;
        end
        else if (fetch_ready_in && ready_work && need_inst) begin
            output_next_PC <= next_PC;
            inst_ready_out <= 1;
            inst_addr <= next_PC;
            inst <= inst_in;

            case (inst_in[6:0])
                7'b1101111, 7'b1100111, 7'b1100011: begin
                    ready_work <= 1;
                end
            endcase
        end
    end


  
endmodule