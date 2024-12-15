// RISCV32 CPU top module
// port modification allowed for debugging purposes
`include "const.v"
module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

wire df_need_inst;
wire [31:0] df_pc;
wire [31:0] df_inst_in;
wire df_instcache_ready_out;

wire drob_to_rob_ready;
wire [4:0] drob_rob_rd;
wire [`rob_type_bit -1 :0] drob_rob_type;
wire [31:0] drob_rob_imm;
wire [31:0] drob_rob_address;
wire [31:0] drob_rob_jump_address;
 /* wire drob_rob_jump;
wire drob_rob_pc;
 */

wire dlsb_to_lsb_ready;
wire [31:0] dlsb_lsb_r1;
wire [31:0] dlsb_lsb_r2;
wire [11:0] dlsb_lsb_offset;
wire [`reg_size -1: 0] dlsb_lsb_rd;
wire [`robsize -1: 0] dlsb_lsb_dep1;
wire [`robsize -1: 0] dlsb_lsb_dep2;
wire dlsb_lsb_has_dep1;
wire dlsb_lsb_has_dep2;
wire [`robsize -1: 0] dlsb_lsb_rob_id;
wire [`lsb_type_size -1: 0] dlsb_lsb_type;

wire drs_to_rs_ready;
wire [4:0] drs_rs_rd;
wire [31:0] drs_rs_r1;
wire [31:0] drs_rs_r2;
wire [`reg_size -1: 0] drs_rs_dep1;
wire [`reg_size -1: 0] drs_rs_dep2;
wire drs_rs_has_dep1;
wire drs_rs_has_dep2;
wire [`robsize -1: 0] drs_rs_rob_id;
wire [`rs_type_size -1: 0] drs_rs_type;

wire [31:0] dreg_rs1_reg_value;
wire [31:0] dreg_rs2_reg_value;
wire dreg_has_dep1;
wire dreg_has_dep2;
wire [`robsize -1: 0] dreg_input_dep1;
wire [`robsize -1: 0] dreg_input_dep2;
wire [4:0] dreg_rs1_reg_id;
wire [4:0] dreg_rs2_reg_id;

wire dc_clear;
wire [31:0] if_addr;


//rob
wire rob_full;
wire rob_empty;
wire [`robsize -1 :0]rob_head;
wire [`robsize -1 :0]rob_tail;

//lsb
wire lsb_full;
wire lsb_ready_out;
wire [31:0] lsb_value_out;
wire [4:0] lsb_rob_id_out;

//rs
wire rs_full;
wire rs_ready;
wire [`robsize -1 : 0]rs_rob_id;
wire [31 : 0]rs_value;
wire decoder_rst;
assign decoder_rst = rst_in | rob_clear;

decoder dc(
  .rdy(rdy_in),
  .clk(clk_in),
  .rst(decoder_rst),

  .need_inst(df_need_inst),
  .PC(df_pc),
  .inst_in(df_inst_in),
  .instcache_ready_out(df_instcache_ready_out),

  .to_rob_ready(drob_to_rob_ready),
  .rob_rd(drob_rob_rd),
  .rob_type(drob_rob_type),
  .rob_imm(drob_rob_imm),
  .rob_address(drob_rob_address),
  .rob_jump_address(drob_rob_jump_address),
  .rob_full(rob_full),
  .next_position(rob_tail),

  .lsb_full(lsb_full),


  .to_lsb_ready(dlsb_to_lsb_ready),
  .lsb_r1(dlsb_lsb_r1),
  .lsb_r2(dlsb_lsb_r2),
  .lsb_offset(dlsb_lsb_offset),
  .lsb_rd(dlsb_lsb_rd),
  .lsb_dep1(dlsb_lsb_dep1),
  .lsb_dep2(dlsb_lsb_dep2),
  .lsb_has_dep1(dlsb_lsb_has_dep1),
  .lsb_has_dep2(dlsb_lsb_has_dep2),
  .lsb_rob_id(dlsb_lsb_rob_id),
  .lsb_type(dlsb_lsb_type),

  .rs_full(rs_ready),
  .to_rs_ready(drs_to_rs_ready),
  .rs_rd(drs_rs_rd),
  .rs_r1(drs_rs_r1),
  .rs_r2(drs_rs_r2),
  .rs_dep1(drs_rs_dep1),
  .rs_dep2(drs_rs_dep2),
  .rs_has_dep1(drs_rs_has_dep1),
  .rs_has_dep2(drs_rs_has_dep2),
  .rs_rob_id(drs_rs_rob_id),
  .rs_type(drs_rs_type),

  .rs1_reg_value(dreg_rs1_reg_value),
  .rs2_reg_value(dreg_rs2_reg_value),
  .has_dep1(dreg_has_dep1),
  .has_dep2(dreg_has_dep2),
  .input_dep1(dreg_input_dep1),
  .input_dep2(dreg_input_dep2),
  .rs1_reg_id(dreg_rs1_reg_id),
  .rs2_reg_id(dreg_rs2_reg_id),

  .clear_inst(dc_clear),
  .if_addr(if_addr)

);

wire rob_clear;
wire [31:0] rob_new_pc;

wire fc_fetch_ready_in;
wire [31:0] fc_inst_in;
wire fc_instcache_ready_out;
wire [31:0] fc_output_next_PC;

fetch fc(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

  .clear(rob_clear),
  .new_pc(rob_new_pc),

  .need_inst(df_need_inst),
  .new_pc_decoder(if_addr),
  .clear_decoder(dc_clear),
  .inst_ready_out(df_instcache_ready_out),
  .inst_addr(df_pc),
  .inst(df_inst_in),

  .fetch_ready_in(fc_fetch_ready_in),
  .inst_in(fc_inst_in),
  .instcache_ready_out(fc_instcache_ready_out),
  .output_next_PC(fc_output_next_PC)
);

//wire rs_rob_id;
//wire rs_value;
//wire rs_ready_out;

//wire lsb_rob_id;
//wire lsb_value;
//wire lsb_ready;

wire robreg_need_set_reg_value;
wire robreg_need_set_reg_dep;
wire [4 :0] robreg_set_reg_id;
wire [31:0] robreg_set_reg_val;
wire [`robsize -1:0] robreg_set_reg_rob_id;
wire [4:0] robreg_set_dep_reg;
wire [`robsize -1:0] robreg_set_dep_rob_id;

wire [4 :0] robreg_need_rob_id1;
wire [4 :0] robreg_need_rob_id2;
wire robreg_rob_value1_ready;
wire [31:0] robreg_rob_value1;
wire robreg_rob_value2_ready;
wire [31:0] robreg_rob_value2;

reorder_buffer rob(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

  .decoder_ready(drob_to_rob_ready),
  .inst_type(drob_rob_type),
  .inst_rd(drob_rob_rd),
  .inst_imm(drob_rob_imm),
  .inst_pc(drob_rob_address),
  .inst_jump_addr(drob_rob_jump_address),

  .full(rob_full),
  .empty(rob_empty),
  .outrob_id_head(rob_head),
  .outrob_id_tail(rob_tail),

  .clear(rob_clear),
  .next_pc(rob_new_pc),

  .lsb_ready(lsb_ready_out),
  .lsb_rob_id(lsb_rob_id_out ),
  .lsb_value(lsb_value_out),

  .rs_rob_id(rs_rob_id),
  .rs_value(rs_value),
  .rs_ready(rs_ready),

  .need_set_reg_value(robreg_need_set_reg_value),
  .need_set_reg_dep(robreg_need_set_reg_dep),
  .set_reg_id(robreg_set_reg_id),
  .set_reg_val(robreg_set_reg_val),
  .set_reg_rob_id(robreg_set_reg_rob_id),
  .set_dep_reg(robreg_set_dep_reg),
  .set_dep_rob_id(robreg_set_dep_rob_id),

  .need_rob_id1(robreg_need_rob_id1),
  .need_rob_id2(robreg_need_rob_id2),
  .rob_value1_ready(robreg_rob_value1_ready),
  .rob_value1(robreg_rob_value1),
  .rob_value2_ready(robreg_rob_value2_ready),
  .rob_value2(robreg_rob_value2)
);


//lsb_ready
//lsb_rob_id
//lsb_value

wire rsalu_rs_shot;
wire [31:0] rsalu_r1;
wire [31:0] rsalu_r2;
wire [`robsize -1:0] rsalu_rob_id;
wire [`rs_type_size-1:0] rsalu_work_type;
wire rsalu_ready;
wire [31:0] rsalu_value;
wire [`robsize -1 :0] rsalu_inputalu_rob_id;

reservation_station rs(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

  .rs_full(rs_full),

  .decoder_ready(drs_to_rs_ready),
  .inst_rd(drs_rs_rd),
  .inst_r1(drs_rs_r1),
  .inst_r2(drs_rs_r2),
  .inst_dep1(drs_rs_dep1),
  .inst_dep2(drs_rs_dep2),
  .inst_has_dep1(drs_rs_has_dep1),
  .inst_has_dep2(drs_rs_has_dep2),
  .inst_rob_id(drs_rs_rob_id),
  .inst_type(drs_rs_type),

  .lsb_ready(lsb_ready_out),
  .lsb_rob_id(lsb_rob_id_out),
  .lsb_value(lsb_value_out),

  .rs_ready(rs_ready),
  .rs_rob_id(rs_rob_id),
  .rs_value(rs_value),

  .rs_shot(rsalu_rs_shot),
  .alu_r1(rsalu_r1),
  .alu_r2(rsalu_r2),
  .alu_rob_id(rsalu_rob_id),
  .alu_work_type(rsalu_work_type),
  .alu_ready(rsalu_ready),
  .inputalu_rob_id(rsalu_inputalu_rob_id),
  .alu_value(rsalu_value)
);


wire lsbcache_need_cache;
wire [31:0] lsbcache_cache_addr;
wire [2:0] lsbcache_cache_size;
wire lsbcache_cache_way;
wire [31:0] lsbcache_cache_value;

wire lsbcache_cache_ready;
wire [31:0] lsbcache_cache_result;

loadstore_buffer lsb(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

  .ready_out(lsb_ready_out),
  .value_out(lsb_value_out),
  .rob_id_out(lsb_rob_id_out),

  .decoder_ready(dlsb_to_lsb_ready),
  .r1(dlsb_lsb_r1),
  .r2(dlsb_lsb_r2),
  .dep1(dlsb_lsb_dep1),
  .dep2(dlsb_lsb_dep2),
  .has_dep1(dlsb_lsb_has_dep1),
  .has_dep2(dlsb_lsb_has_dep2),
  .offset(dlsb_lsb_offset),
  .rob_id(dlsb_lsb_rob_id),
  .inst_type(dlsb_lsb_type),
  .full(lsb_full),
 
  .need_cache(lsbcache_need_cache),
  .cache_addr(lsbcache_cache_addr),
  .cache_size(lsbcache_cache_size),
  .cache_way(lsbcache_cache_way),
  .cache_value(lsbcache_cache_value),
  .cache_ready(lsbcache_cache_ready),
  .cache_result(lsbcache_cache_result),


  .rob_full(rob_full),
  .rob_empty(rob_empty),
  .head_id(rob_head),

  .rs_ready(rs_ready),
  .rs_rob_id(rs_rob_id),
  .rs_value(rs_value)
);

alu alu(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

  .valid(rsalu_rs_shot),
  .work_type(rsalu_work_type),
  .r1(rsalu_r1),
  .r2(rsalu_r2),
  .inst_rob_id(rsalu_rob_id),
  .ready(rsalu_ready),
  .rob_id(rsalu_inputalu_rob_id),
  .value(rsalu_value)
);

data_cache cache(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

  .clear(rob_clear),

  .inst_valid(fc_fetch_ready_in),
  .inst_addr(fc_output_next_PC),
  .inst_ready(fc_instcache_ready_out),
  .inst_res(fc_inst_in),

  .data_valid(lsbcache_need_cache),
  .data_wr(lsbcache_cache_way),
  .data_type(lsbcache_cache_size),
  .data_addr(lsbcache_cache_addr),
  .data_value(lsbcache_cache_value),
  .data_ready(lsbcache_cache_ready),
  .data_res(lsbcache_cache_result),

  .mem_din(mem_din),
  .mem_dout(mem_dout),
  .mem_a(mem_a),
  .mem_wr(mem_wr),
  .io_buffer_full(io_buffer_full)
);

register_file register(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

  .clear(rob_clear),

  .id1(dreg_rs1_reg_id),
  .id2(dreg_rs2_reg_id),
  .has_dep1(dreg_has_dep1),
  .has_dep2(dreg_has_dep2),
  .dep1(dreg_input_dep1),
  .dep2(dreg_input_dep2),
  .value1(dreg_rs1_reg_value),
  .value2(dreg_rs2_reg_value),

  .need_set_reg_value(robreg_need_set_reg_value),
  .need_set_reg_dep(robreg_need_set_reg_dep),
  .set_value_reg_id(robreg_set_reg_id),
  .set_val(robreg_set_reg_val),
  .set_reg_rob_id(robreg_set_reg_rob_id),
  .set_dep_reg_id(robreg_set_dep_reg),
  .set_dep_rob_id(robreg_set_dep_rob_id),

  .need_rob_id1(robreg_need_rob_id1),
  .need_rob_id2(robreg_need_rob_id2),
  .rob_value1_ready(robreg_rob_value1_ready),
  .rob_value1(robreg_rob_value1),
  .rob_value2_ready(robreg_rob_value2_ready),
  .rob_value2(robreg_rob_value2)
);


















endmodule