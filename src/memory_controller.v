`include "const.v"
module memory_controller(
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire valid,
    input wire wr, // 0: read, 1: write
    input wire [31:0] addr,
    input wire [2:0] type, // 00: byte, 01: halfword, 10: word
    input wire [31:0] data,
    output wire ready,
    output wire [31:0] final_result,


    input  wire [ 7 : 0] mem_din,   // data input bus
    output wire [ 7 : 0] mem_dout,  // data output bus
    output wire [31 : 0] mem_a,     // address bus (only 17 : 0 is used)
    output wire          mem_wr,    // write/read signal (1 for write)
    input wire io_buffer_full
);

    reg work;
    reg [31:0] work_origin_address;
    reg [31:0] work_current_address;
    reg work_wr;
    reg [2:0] work_type;
    reg [2:0] work_cycle;
    reg [7:0] current_data;
    reg [31:0] result;

    wire is_io = addr[17:16] == 2'b11;
    wire ready_write = !is_io || (is_io && (!wr || !io_buffer_full));
    wire need_work = valid && ready_write && !ready;



    always @(posedge clk) begin
        if (rst) begin
            work <= 0;
            work_origin_address <= 0;
            work_current_address <= 0;
            work_wr <= 0;
            work_type <= 0;
            work_cycle <= 0;
            ready <= 0;
            current_data <= 0;
            result <= 0;


        end 
        else if(rdy) begin
            if(ready)begin
                ready <= 0;
            end
            else begin
                case(work_cycle)
                    3`b000: begin
                        if(need_work) begin
                            result <= data;
                            work <= 1;
                            work_origin_address <= addr;
                            work_wr <= wr;
                            work_type <= type;
                            if(work_type[1:0] == 2`b00) begin
                                work_cycle <= 3`b000;
                                current_data <= 0;
                                work_wr <= 0;
                                work_current_address <= addr;
                                ready <= 1;
                            end
                            else begin
                                work_cycle <= 3`b001;
                                current_data <= data[15:8];
                                work_wr <= wr;
                                work_current_address <= addr + 1;
                                ready <= 0;
                            end
                        end
                    end
                    3`b001: begin
                        result[7:0] <= mem_din;
                        if(work_type[1:0] == 2`b01) begin
                            work_cycle <= 3`b000;
                            current_data <= 0;
                            work_wr <= 0;
                            ready <= 1;
                        end
                        else begin
                            work_cycle <= 3`b010;
                            current_data <= data[23:16];
                            work_wr <= wr;
                            work_current_address <= work_origin_address + 2;
                            ready <= 0;
                        end
                        
                    end
                    // 4 bytes
                    3`b010: begin
                        result[15:8] <= mem_din;
                        current_addr <= work_current_address + 3;
                        current_data <= data[31:24];
                        work_wr <= wr;
                        work_cycle <= 3`b011;
                        ready <= 0;
                    end
                    3`b011: begin
                        result[23:16] <= mem_din;
                        current_data <= 0;
                        work_wr <= 0;
                        work_cycle <= 3`b000;
                        ready <= 1;
                    end
                endcase
            end
        end
    end

    assign working = work_cycle == 3`b000 && need_work;
    assign mem_wr = working ? wr : work_wr;
    assign mem_a = working ? addr : current_addr;
    assign mem_dout = working ? data[7:0] : current_data;

endmodule



    

