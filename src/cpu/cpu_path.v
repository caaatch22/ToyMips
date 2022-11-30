`include "defines.v"
`include "./cpu/Registers/pc_reg.v"
`include "./cpu/Latch/if_id.v"
`include "./cpu/FunctionalUnit/id.v"
`include "./cpu/Registers/regfile.v"
`include "./cpu/Latch/id_ex.v"
`include "./cpu/FunctionalUnit/ex.v"
`include "./cpu/Latch/ex_mem.v"
`include "./cpu/FunctionalUnit/mem.v"
`include "./cpu/Latch/mem_wb.v"
`include "./cpu/Registers/hilo_reg.v"
`include "./cpu/FunctionalUnit/ctrl.v"
`include "./cpu/FunctionalUnit/div.v"
`include "./cpu/Registers/LLbit_reg.v"
`include "./cpu/Registers/cp0_reg.v"

module cpu_path(

	input clk,
	input rst,
	
	input  [5:0]      interrupt_i,

	input  [`RegBus]  rom_data_i,
	output [`RegBus]  rom_addr_o,
	output wire       rom_ce_o,

   //connect with data_ram
	input  [`RegBus]  ram_data_i,
	output [`RegBus]  ram_addr_o,
	output [`RegBus]  ram_data_o,
	output            ram_we_o,
	output [3:0]      ram_sel_o,
	output            ram_ce_o,

	output wire       timer_int_o
	
);

	wire[`InstAddrBus] pc;
	wire[`InstAddrBus] id_pc_i;
	wire[`InstBus]     id_inst_i;
	
	//连接译码阶段ID模块的输出与ID/EX模块的输入
	wire[`AluOpBus]    id_aluop_o;
	wire[`AluSelBus]   id_alusel_o;
	wire[`RegBus]      id_reg1_o;
	wire[`RegBus]      id_reg2_o;
	wire               id_wreg_o;
	wire[`RegAddrBus]  id_wd_o;
	wire               id_is_in_delayslot_o;
	wire[`RegBus]      id_link_addr_o;	
	wire[`RegBus]      id_inst_o;
	
	//连接ID/EX模块的输出与执行阶段EX模块的输入
	wire[`AluOpBus]    ex_aluop_i;
	wire[`AluSelBus]   ex_alusel_i;
	wire[`RegBus]      ex_reg1_i;
	wire[`RegBus]      ex_reg2_i;
	wire               ex_wreg_i;
	wire[`RegAddrBus]  ex_wd_i;
	wire               ex_is_in_delayslot_i;	
    wire[`RegBus]      ex_link_addr_i;	
    wire[`RegBus]      ex_inst_i;
	
	//连接执行阶段EX模块的输出与EX/MEM模块的输入
	wire               ex_wreg_o;
	wire[`RegAddrBus]  ex_wd_o;
	wire[`RegBus]      ex_wdata_o;
	wire[`RegBus]      ex_hi_o;
	wire[`RegBus]      ex_lo_o;
	wire               ex_whilo_o;
	wire[`AluOpBus]    ex_aluop_o;
	wire[`RegBus]      ex_mem_addr_o;
	wire[`RegBus]      ex_reg1_o;
	wire[`RegBus]      ex_reg2_o;

	wire               ex_cp0_reg_we_o;
	wire[4:0]          ex_cp0_reg_waddr_o;
	wire[`RegBus]      ex_cp0_reg_data_o; 

	//连接EX/MEM模块的输出与访存阶段MEM模块的输入
	wire               mem_wreg_i;
	wire[`RegAddrBus]  mem_wd_i;
	wire[`RegBus]      mem_wdata_i;
	wire[`RegBus]      mem_hi_i;
	wire[`RegBus]      mem_lo_i;
	wire               mem_whilo_i;		

	wire[`AluOpBus]    mem_aluop_i;
	wire[`RegBus]      mem_mem_addr_i;
	wire[`RegBus]      mem_reg1_i;
	wire[`RegBus]      mem_reg2_i;

	wire               mem_cp0_reg_we_i;
	wire[4:0]          mem_cp0_reg_waddr_i;
	wire[`RegBus]      mem_cp0_reg_data_i;

	//连接访存阶段MEM模块的输出与MEM/WB模块的输入
	wire               mem_wreg_o;
	wire[`RegAddrBus]  mem_wd_o;
	wire[`RegBus]      mem_wdata_o;
	wire[`RegBus]      mem_hi_o;
	wire[`RegBus]      mem_lo_o;
	wire               mem_whilo_o;

	wire               mem_cp0_reg_we_o;
	wire[4:0]          mem_cp0_reg_waddr_o;
	wire[`RegBus]      mem_cp0_reg_data_o;
	
	//连接MEM/WB模块的输出与回写阶段的输入	
	wire               wb_wreg_i;
	wire[`RegAddrBus]  wb_wd_i;
	wire[`RegBus]      wb_wdata_i;
	wire[`RegBus]      wb_hi_i;
	wire[`RegBus]      wb_lo_i;
	wire               wb_whilo_i;

	wire               wb_cp0_reg_we_i;
	wire[4:0]          wb_cp0_reg_waddr_i;
	wire[`RegBus]      wb_cp0_reg_data_i;
	
	//连接译码阶段ID模块与通用寄存器Regfile模块
	wire               reg1_read;
	wire               reg2_read;
	wire[`RegBus]      reg1_data;
	wire[`RegBus]      reg2_data;
	wire[`RegAddrBus]  reg1_addr;
	wire[`RegAddrBus]  reg2_addr;

	//连接执行阶段与hilo模块的输出，读取HI、LO寄存器
	wire[`RegBus] 	   hi;
	wire[`RegBus]      lo;
	
	wire[`DoubleRegBus] div_result;
	wire                div_ready;
	wire[`RegBus]       div_opdata1;
	wire[`RegBus]       div_opdata2;
	wire                div_start;
	wire                div_annul;
	wire                signed_div;

	wire               is_in_delayslot_i;
	wire               is_in_delayslot_o;
	wire               next_inst_in_delayslot_o;
	wire               id_branch_flag_o;
	wire[`RegBus]      branch_addr;

	wire[5:0]          stall;
	wire               stallreq_from_id;
	wire               stallreq_from_ex;

  wire[`RegBus]        cp0_data_o;
  wire[4:0]            cp0_raddr_i;

  //pc_reg例化
	pc_reg pc_reg0(
		.clk(clk),
		.rst(rst),
		.stall(stall),
		.branch_flag_i(id_branch_flag_o),
		.branch_addr_i(branch_addr),		
		.pc(pc),
		.ce(rom_ce_o)	
			
	);
	
  assign rom_addr_o = pc;

  //IF/ID模块例化
	if_id if_id0(
		.clk(clk),
		.rst(rst),
		.stall(stall),
		.if_pc(pc),
		.if_inst(rom_data_i),
		.id_pc(id_pc_i),
		.id_inst(id_inst_i)      	
	);
	
	//译码阶段ID模块
	id id0(
		.rst(rst),
		.pc_i(id_pc_i),
		.inst_i(id_inst_i),

		.ex_aluop_i(ex_aluop_o),

		.reg1_data_i(reg1_data),
		.reg2_data_i(reg2_data),

	  //处于执行阶段的指令要写入的目的寄存器信息
		.ex_wreg_i(ex_wreg_o),
		.ex_wdata_i(ex_wdata_o),
		.ex_wd_i(ex_wd_o),

	  //处于访存阶段的指令要写入的目的寄存器信息
		.mem_wreg_i(mem_wreg_o),
		.mem_wdata_i(mem_wdata_o),
		.mem_wd_i(mem_wd_o),

	  	.is_in_delayslot_i(is_in_delayslot_i),

		//送到regfile的信息
		.reg1_read_o(reg1_read),
		.reg2_read_o(reg2_read), 	  

		.reg1_addr_o(reg1_addr),
		.reg2_addr_o(reg2_addr), 
	  
		//送到ID/EX模块的信息
		.aluop_o(id_aluop_o),
		.alusel_o(id_alusel_o),
		.reg1_o(id_reg1_o),
		.reg2_o(id_reg2_o),
		.wd_o(id_wd_o),
		.wreg_o(id_wreg_o),
		.inst_o(id_inst_o),

	 	.next_inst_in_delayslot_o(next_inst_in_delayslot_o),	
		.branch_flag_o(id_branch_flag_o),
		.branch_addr_o(branch_addr),       
		.link_addr_o(id_link_addr_o),
		
		.is_in_delayslot_o(id_is_in_delayslot_o),

		.stallreq(stallreq_from_id)	
	);

  //通用寄存器Regfile例化
	regfile regfile1(
		.clk (clk),
		.rst (rst),
		.we	(wb_wreg_i),
		.waddr (wb_wd_i),
		.wdata (wb_wdata_i),
		.re1 (reg1_read),
		.raddr1 (reg1_addr),
		.rdata1 (reg1_data),
		.re2 (reg2_read),
		.raddr2 (reg2_addr),
		.rdata2 (reg2_data)
	);

	//ID/EX模块
	id_ex id_ex0(
		.clk(clk),
		.rst(rst),

		.stall(stall),
		
		//从译码阶段ID模块传递的信息
		.id_aluop(id_aluop_o),
		.id_alusel(id_alusel_o),
		.id_reg1(id_reg1_o),
		.id_reg2(id_reg2_o),
		.id_wd(id_wd_o),
		.id_wreg(id_wreg_o),
		.id_link_addr(id_link_addr_o),
		.id_is_in_delayslot(id_is_in_delayslot_o),
		.next_inst_in_delayslot_i(next_inst_in_delayslot_o),		
		.id_inst(id_inst_o),	
	
		//传递到执行阶段EX模块的信息
		.ex_aluop(ex_aluop_i),
		.ex_alusel(ex_alusel_i),
		.ex_reg1(ex_reg1_i),
		.ex_reg2(ex_reg2_i),
		.ex_wd(ex_wd_i),
		.ex_wreg(ex_wreg_i),
		.ex_link_addr(ex_link_addr_i),
  		.ex_is_in_delayslot(ex_is_in_delayslot_i),
		.is_in_delayslot_o(is_in_delayslot_i),
		.ex_inst(ex_inst_i)	
	);		
	
	//EX模块
	ex ex0(
		.rst(rst),
	
		//送到执行阶段EX模块的信息
		.aluop_i(ex_aluop_i),
		.alusel_i(ex_alusel_i),
		.reg1_i(ex_reg1_i),
		.reg2_i(ex_reg2_i),
		.wd_i(ex_wd_i),
		.wreg_i(ex_wreg_i),
		.hi_i(hi),
		.lo_i(lo),
		.inst_i(ex_inst_i),
	  	.link_addr_i(ex_link_addr_i),
		.is_in_delayslot_i(ex_is_in_delayslot_i),

		//访存阶段的指令是否要写CP0，用来检测数据相关
  		.mem_cp0_reg_we(mem_cp0_reg_we_o),
		.mem_cp0_reg_waddr(mem_cp0_reg_waddr_o),
		.mem_cp0_reg_data(mem_cp0_reg_data_o),
	
		//回写阶段的指令是否要写CP0，用来检测数据相关
  		.wb_cp0_reg_we(wb_cp0_reg_we_i),
		.wb_cp0_reg_waddr(wb_cp0_reg_waddr_i),
		.wb_cp0_reg_data(wb_cp0_reg_data_i),

		.cp0_reg_data_i(cp0_data_o),
		.cp0_reg_raddr_o(cp0_raddr_i),
		
		//向下一流水级传递，用于写CP0中的寄存器
		.cp0_reg_we_o(ex_cp0_reg_we_o),
		.cp0_reg_waddr_o(ex_cp0_reg_waddr_o),
		.cp0_reg_data_o(ex_cp0_reg_data_o),	  

		.wb_hi_i(wb_hi_i),
		.wb_lo_i(wb_lo_i),
		.wb_whilo_i(wb_whilo_i),
		.mem_hi_i(mem_hi_o),
		.mem_lo_i(mem_lo_o),
		.mem_whilo_i(mem_whilo_o),

		.div_result_i(div_result),
		.div_ready_i(div_ready), 
	  
	  //EX模块的输出到EX/MEM模块信息
		.wd_o(ex_wd_o),
		.wreg_o(ex_wreg_o),
		.wdata_o(ex_wdata_o),

		.hi_o(ex_hi_o),
		.lo_o(ex_lo_o),
		.whilo_o(ex_whilo_o),

		.div_opdata1_o(div_opdata1),
		.div_opdata2_o(div_opdata2),
		.div_start_o(div_start),
		.signed_div_o(signed_div),	

		.aluop_o(ex_aluop_o),
		.mem_addr_o(ex_mem_addr_o),
		.reg2_o(ex_reg2_o),

		.stallreq(stallreq_from_ex)
		
	);

	//EX/MEM模块
	ex_mem ex_mem0(
		.clk(clk),
		.rst(rst),

		.stall(stall),
	  
		//来自执行阶段EX模块的信息	
		.ex_wd(ex_wd_o),
		.ex_wreg(ex_wreg_o),
		.ex_wdata(ex_wdata_o),
		.ex_hi(ex_hi_o),
		.ex_lo(ex_lo_o),
		.ex_whilo(ex_whilo_o),	

  		.ex_aluop(ex_aluop_o),
		.ex_mem_addr(ex_mem_addr_o),
		.ex_reg2(ex_reg2_o),

		.ex_cp0_reg_we(ex_cp0_reg_we_o),
		.ex_cp0_reg_waddr(ex_cp0_reg_waddr_o),
		.ex_cp0_reg_data(ex_cp0_reg_data_o),

		//送到访存阶段MEM模块的信息
		.mem_wd(mem_wd_i),
		.mem_wreg(mem_wreg_i),
		.mem_wdata(mem_wdata_i),
		.mem_hi(mem_hi_i),
		.mem_lo(mem_lo_i),
		.mem_whilo(mem_whilo_i),

		.mem_cp0_reg_we(mem_cp0_reg_we_i),
		.mem_cp0_reg_waddr(mem_cp0_reg_waddr_i),
		.mem_cp0_reg_data(mem_cp0_reg_data_i),

  		.mem_aluop(mem_aluop_i),
		.mem_mem_addr(mem_mem_addr_i),
		.mem_reg2(mem_reg2_i)

						       	
	);
	
  //MEM模块例化
	mem mem0(
		.rst(rst),
	
		//来自EX/MEM模块的信息	
		.wd_i(mem_wd_i),
		.wreg_i(mem_wreg_i),
		.wdata_i(mem_wdata_i),	
		.hi_i(mem_hi_i),
		.lo_i(mem_lo_i),
		.whilo_i(mem_whilo_i),		

  		.aluop_i(mem_aluop_i),
		.mem_addr_i(mem_mem_addr_i),
		.reg2_i(mem_reg2_i),
	
		//来自memory的信息
		.mem_data_i(ram_data_i),

		.cp0_reg_we_i(mem_cp0_reg_we_i),
		.cp0_reg_waddr_i(mem_cp0_reg_waddr_i),
		.cp0_reg_data_i(mem_cp0_reg_data_i),

		.cp0_reg_we_o(mem_cp0_reg_we_o),
		.cp0_reg_waddr_o(mem_cp0_reg_waddr_o),
		.cp0_reg_data_o(mem_cp0_reg_data_o),
	  
		//送到MEM/WB模块的信息
		.wd_o(mem_wd_o),
		.wreg_o(mem_wreg_o),
		.wdata_o(mem_wdata_o),
		.hi_o(mem_hi_o),
		.lo_o(mem_lo_o),
		.whilo_o(mem_whilo_o),
		
		//送到memory的信息
		.mem_addr_o(ram_addr_o),
		.mem_we_o(ram_we_o),
		.mem_sel_o(ram_sel_o),
		.mem_data_o(ram_data_o),
		.mem_ce_o(ram_ce_o)	
	);

  //MEM/WB模块
	mem_wb mem_wb0(
		.clk(clk),
		.rst(rst),

		.stall(stall),

		//来自访存阶段MEM模块的信息	
		.mem_wd(mem_wd_o),
		.mem_wreg(mem_wreg_o),
		.mem_wdata(mem_wdata_o),	
		.mem_hi(mem_hi_o),
		.mem_lo(mem_lo_o),
		.mem_whilo(mem_whilo_o),	

		.mem_cp0_reg_we(mem_cp0_reg_we_o),
		.mem_cp0_reg_waddr(mem_cp0_reg_waddr_o),
		.mem_cp0_reg_data(mem_cp0_reg_data_o),	
	
		//送到回写阶段的信息
		.wb_wd(wb_wd_i),
		.wb_wreg(wb_wreg_i),
		.wb_wdata(wb_wdata_i),
		.wb_hi(wb_hi_i),
		.wb_lo(wb_lo_i),
		.wb_whilo(wb_whilo_i),

		.wb_cp0_reg_we(wb_cp0_reg_we_i),
		.wb_cp0_reg_waddr(wb_cp0_reg_waddr_i),
		.wb_cp0_reg_data(wb_cp0_reg_data_i)
									       	
	);

	hilo_reg hilo_reg0(
		.clk(clk),
		.rst(rst),

		// write port
		.we(wb_whilo_i),
		.hi_i(wb_hi_i),
		.lo_i(wb_lo_i),
	
		// read port
		.hi_o(hi),
		.lo_o(lo)
	);

	ctrl ctrl0(
		.rst(rst),
	
		.stallreq_from_id(stallreq_from_id),
	
  	    //来自执行阶段的暂停请求
		.stallreq_from_ex(stallreq_from_ex),

		.stall(stall)       	
	);

	div div0(
		.clk(clk),
		.rst(rst),
	
		.signed_div_i(signed_div),
		.opdata1_i(div_opdata1),
		.opdata2_i(div_opdata2),
		.start_i(div_start),
		.annul_i(1'b0),
	
		.result_o(div_result),
		.ready_o(div_ready)
	);

	LLbit_reg LLbit_reg0(
		.clk(clk),
		.rst(rst),
	    .flush(1'b0),
	  
		// write port
		.LLbit_i(wb_LLbit_value_i),
		.we(wb_LLbit_we_i),
	
		// read port
		.LLbit_o(LLbit_o)
	
	);

	cp0_reg cp0_reg0(
		.clk(clk),
		.rst(rst),
		
		.we_i(wb_cp0_reg_we_i),
		.waddr_i(wb_cp0_reg_waddr_i),
		.raddr_i(cp0_raddr_i),
		.data_i(wb_cp0_reg_data_i),
		
		//.excepttype_i(mem_excepttype_o),
		.interrupt_i(interrupt_i),
		//.current_inst_addr_i(mem_current_inst_address_o),
		//.is_in_delayslot_i(mem_is_in_delayslot_o),
		
		.data_o(cp0_data_o),
		
		
		.timer_interrupt_o(timer_interrupt_o)  			
	);

endmodule