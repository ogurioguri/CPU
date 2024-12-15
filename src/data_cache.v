module data_cache(
    input wire clk,
    input wire rst,
    input wire rdy,

    input clear,


    input wire inst_valid,
    input wire [31:0] inst_addr,
    output wire inst_ready,
    output wire [31:0] inst_res,

    //to lsb
    input wire data_valid,
    input wire data_wr,
    input wire [2:0]data_type,
    input wire [31:0] data_addr,
    input wire [31:0] data_value,
    output wire data_ready,
    output wire [31:0] data_res,
    

    //to memory
    input  wire [ 7 : 0] mem_din,   // data input bus
    output wire [ 7 : 0] mem_dout,  // data output bus
    output wire [31 : 0] mem_a,     // address bus (only 17 : 0 is used)
    output wire          mem_wr,    // write/read signal (1 for write)
    input wire io_buffer_full

);

    reg work;
    reg work_wr; // 0 is instruction, 1 is data
    reg memory_use;
    reg [31:0] memory_addr;
    reg [2:0] memory_type;
    reg [31:0] memory_data;
    wire memory_ready;
    wire [31:0] memory_res;
    wire memory_wr;
    wire mc_rst;

    wire inst_hit;
    wire [31:0] cache_res;
    wire inst_write_ready;

    instruction_cache inst_cache(
        .clk(clk),
        .rst(rst),
        .rdy(rdy),
        .valid(inst_valid),
        .wr(inst_write_ready),
        .addr(inst_addr),
        .data(memory_res),
        .ready(inst_ready),
        .final_result(cache_res),
        .hit(inst_hit)
    );
    assign mc_rst = rst | clear;

    memory_controller mem_ctrl(
        .clk(clk),
        .rst(mc_rst),
        .rdy(rdy),
        .mem_din(mem_din),
        .mem_dout(mem_dout),
        .mem_a(mem_a),
        .mem_wr(mem_wr),
        .io_buffer_full(io_buffer_full),
        .valid(memory_use),
        .wr(memory_wr),
        .addr(memory_addr),
        .len(memory_type),
        .data(memory_data),
        .ready(memory_ready),
        .res(memory_res)
    );

    always @(posedge clk) begin
        if (clear | rst) begin
            work <= 0;
            work_wr <= 0;
            memory_use <= 0;
            memory_addr <= 0;
            memory_type <= 0;
            memory_data <= 0;
            
        end
        else if (!rdy) begin
        end
        else if (!work) begin
            //do the data first
            if (data_valid) begin
                work <= 1;
                work_wr <= 1;
                memory_use <= 1;
                memory_addr <= data_addr;
                memory_type <= data_type;
                memory_data <= data_value;
            end
            else if (inst_valid && !inst_hit) begin
                work <= 1;
                work_wr <= 0;
                memory_use <= 1;
                memory_addr <= inst_addr;
                memory_type <= 3'b010 ; // 4 bytes
                memory_data <= 0;
            end
        end
        else if(memory_ready) begin
            work <= 0;
            memory_use <= 0;
        end
    end

    
    assign data_ready = memory_ready && work && (work_wr == 1);
    assign inst_ready = inst_hit;
    assign data_res = memory_res;
    assign inst_res = cache_res;
    assign inst_write_ready = work && (memory_ready && work_wr == 0);



endmodule

    
