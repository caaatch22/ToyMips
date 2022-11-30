`include "defines.v"

module cp0_reg(
    input                        clk,
    input                        rst,

    input                        we_i,
    input [4: 0]                 waddr_i,             
    input [4: 0]                 raddr_i,
    input [`RegBus]              data_i,

    input [5:0]                  interrupt_i,

    output reg[`RegBus]          data_o,
    output reg[`RegBus]          count_o,
    output reg[`RegBus]          compare_o,
    output reg[`RegBus]          status_o,
    output reg[`RegBus]          cause_o,
    output reg[`RegBus]          epc_o,
    output reg[`RegBus]          config_o,
    output reg[`RegBus]          PRId_o,        // Processor Identifier

    output reg                   timer_interrupt_o
);

  always @(posedge clk) begin
    if(rst == `RstEnable) begin
        count_o              <= `ZeroWord;
        compare_o            <= `ZeroWord;
        status_o             <= 32'h10000000;    // CP0 exsit
        cause_o              <= `ZeroWord;
        epc_o                <= `ZeroWord;
        config_o             <= 32'h00008000;
        PRId_o               <= 32'b00000000010011000000000100000010;   // !! TODO
        timer_interrupt_o    <= `ZeroWord;
    end else begin
        count_o        <= count_o + 1;
        cause_o[15:10] <= interrupt_i;

        if(compare_o != `ZeroWord && count_o == compare_o) begin
            timer_interrupt_o <= `interruptAssert;
        end

        if(we_i == `WriteEnable) begin
            case (waddr_i)
            `CP0_REG_COUNT:     count_o  <= data_i;
            `CP0_REG_STATUS:    status_o <= data_i;
            `CP0_REG_EPC :      epc_o    <= data_i;
            `CP0_REG_COMPARE: begin
              compare_o         <= data_i;
              timer_interrupt_o <= `interruptAssert;    
            end  
            `CP0_REG_CAUSE: begin
              cause_o[9:8] <= data_i[9:8];
              cause_o[23]  <= data_i[23];
              cause_o[22]  <= data_i[22];
            end
            endcase
        end
    end
  end


  always @ (*) begin
    if(rst == `RstEnable) begin
      data_o <= `ZeroWord;
		end else begin
				case (raddr_i) 
				`CP0_REG_COUNT:    data_o <= count_o;
				`CP0_REG_COMPARE:	 data_o <= compare_o;
				`CP0_REG_STATUS:	 data_o <= status_o;
				`CP0_REG_CAUSE:	   data_o <= cause_o;
				`CP0_REG_EPC:	     data_o <= epc_o ;
				`CP0_REG_PRId:	   data_o <= PRId_o ;
				`CP0_REG_CONFIG:	 data_o <= config_o ;				
				default: 	begin end			
				endcase  //case addr_i			
		end   
  end     

endmodule