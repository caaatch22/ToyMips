`timescale 1ns/1ps

module sopc_tb();
    reg clock, reset;
    sopc sopc0(
        .clk(clock),
        .rst(reset)
    );

    always #1 clock = ~clock;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
        $readmemh("rom.txt", sopc0.inst_rom0.inst_mem);

        clock = 1'b0;
        reset = 1'b1;

        #20 reset = 1'b0;
        #1000 $finish;
    end
endmodule