`include "defines.v"

module pc_reg (
    input                    clk, 
    input                    rst,
    input [5: 0]             stall,

    input                    flush,
    input [`RegBus]          new_pc, 

    // from decode phase, for J-type inst
    input                    branch_flag_i,
    input [`RegBus]          branch_addr_i,

    output reg[`InstAddrBus] pc,
    output reg               ce 
);
  
  always @ (posedge clk or posedge rst) begin
    if (ce == `ChipDisable) begin
        pc <= 32'h0000_0000;
    end else if(flush == `Flush) begin
        pc <= new_pc;
    end else if(stall[0] == `NoStop) begin
        if(branch_flag_i == `DoBranch) begin
            pc <= branch_addr_i;
        end else begin
            pc <= pc + 4'h4;
        end
    end
  end

  always @ (posedge clk or posedge rst) begin
    if (rst == `RstEnable) begin
        ce <= `ChipDisable;       
    end else begin
        ce <= `ChipEnable;    
    end
  end


endmodule