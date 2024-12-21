`include "const.v"
//direct-mapped cache
module instruction_cache(
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire valid,
    input wire wr, // 0: read, 1: write
    input wire [31:0] addr,
    input wire [31:0] data,
    output wire ready,
    output wire [31:0] final_result,    
    output wire hit 

);
    localparam cache_size = 1 << `cache_size_bit;
    localparam tag_bit = 32 - `cache_size_bit;

    reg [31:0] data_array [0:cache_size-1];
    reg [tag_bit - 1 :0] addr_array [0:cache_size-1];
    reg busy [0:cache_size-1];

   //choose the tag and index(foolish)
   //the tag shoule be big
    wire [tag_bit - 1 :0] tag = addr[ `cache_size_bit + tag_bit -1 : `cache_size_bit];
    wire [ `cache_size_bit - 1 : 0] index = addr[`cache_size_bit -1 : 0];

    assign hit = busy[index] && addr_array[index] == tag;
    assign final_result = data_array[index];

    always @(posedge clk) begin
        if (rst) begin: resert
            integer i;
            for (i = 0; i < cache_size; i = i + 1) begin
                data_array[i] <= 0;
                addr_array[i] <= 0;
                busy[i] <= 0;
            end
        end
        else if (rdy && wr) begin
            busy[index] <= 1;
            data_array[index] <= data;
            addr_array[index] <= tag;
        end
    end
endmodule