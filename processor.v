`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/06/2017 02:04:30 PM
// Design Name: 
// Module Name: processor
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`define word		[15:0]
`define halfword	[7:0]
`define opcode      [15:12]
`define dest        [11:8]
`define src         [7:4]
`define Tsrc        [3:0]
`define regName     [3:0]
`define state       [4:0]
`define start       5'b11111
`define start1      5'b11110
`define ALopCompletion 5'b11101
`define regsize		[15:0]
`define memsize 	[65535:0]
`define width		16;
`define aluc		[2:0]
`define regc		[1:0]
`define regsel		[3:0]

//condition codes
`define fPos [0]
`define ltPos [1]
`define lePos [2]
`define eqPos [3]
`define nePos [4]
`define gePos [5]
`define gtPos [6]
`define tPos [7]

//op codes
`define OPad	4'b0000
`define OPan	4'b0001
`define OPor	4'b0010
`define OPno	4'b0011
`define OPeo	4'b0100
`define OPmi	4'b0101
`define OPal	4'b0110
`define OPdl	4'b0111
`define OPml	4'b1000
`define OPsr	4'b1001
`define OPbr	4'b1010
`define OPjr	4'b1011
`define OPli	4'b1100
`define OPsi	4'b1101
`define OPlo	4'b1110
`define OPcl	4'b1110
`define OPco	4'b1110
`define OPst	4'b1110
`define OPnl	4'b1110
`define OPsy	4'b1111

`define OPnop   5'b11111

module decode(opout, regdst, opin, ir);
    output reg `opcode opout;
    output reg `dest regdst;
    input wire `opcode opin;
    input `word ir;
    
    always@(opin, ir) begin
        if(1) begin
            //TODO: handle loading immediates?
        end else begin
            case(ir`opcode)
                //TODO: handle jumps/branches
                //TODO: handle stores
                default: begin opout = ir`opcode; regdst <= ir`dest; end
            endcase
        end
    end
endmodule

module ALU(ALUResult, op, a, b);

output reg `word ALUResult;
input wire `opcode instruct;
input wire `word a, b;

always@(instruct, a, b) begin
    case(instruct)
        `OPad:
            begin
                ALUResult <= a+b;
            end
        `OPan: ALUResult <= a&b;
        `OPeo: ALUResult <= a^b;
        `OPli: ; //???????????
        `OPmi: ; //???????????
        `OPno: ALUResult <= !a;
        `OPor: ALUResult <= a|b;
        `OPsi: ; //???????????
        `OPsr: ALUResult <= a >> b;
        `OPbr:
            begin
                   ALUResult <= b; //address to label
                   if(cond[currentDst-7] == 1) //currentDst is the condition register for branch
                       brEnable <= 1;
                   else
                       brEnable <= 0;
                end
        `OPco: 
        begin
            case(currentDst)
                //cl
                4'b0000: ; //dont need to implement for this assignment
                //co
                4'b0001: 
                    begin
                    cond <= 8'b10000000;
                    
                    if (a == b)
                    begin
                        cond`eqPos <= 1;
                        cond`lePos <= 1;
                        cond`gePos <= 1;
                    end
                    else
                    begin
                        if(a > b)
                        begin
                            cond`gtPos <= 1;
                            cond`nePos <= 1;
                            cond`gePos <= 1;
                        end
                        else
                        begin
                            if(a < b)
                            begin
                                cond`ltPos <= 1;
                                 cond`nePos <= 1;
                                 cond`lePos <= 1;
                            end
                        end
                    end
                    end
                        default:
                            case(currentTsrc)
                            //lo
                            4'b0010: ;
                            //nl
                            4'b0011: ; //dont need to implement for this assignment
                            //st
                            4'b0100: ;
                            endcase
                    endcase
                end
               default: ;
    endcase
end
end

endmodule

module processor(halt, reset, clk);
    output reg halt;
    input reset, clk;
    
    reg `word regfile `regsize;
    reg `word mainmem `memsize;
    
    reg `word ir, srcValue, destValue, nextPC;
    wire `opcode op;
    wire `regName regdst;
    wire `word ALUResult;
    
    reg isSquash;
    reg `opcode stage0op, stage1op, stage2op;
    reg `word pc;
    
    always@(reset)begin
        halt = 0;
        pc = 0;
        stage0op = `OPnop;
        stage1op = `OPnop;
        stage2op = `OPnop;
        $readmemh0(regfile);
        $readmemh1(mainmem);
    end
    
    decode inst_decode(op, regdest, stage0op, ir);
    ALU inst_ALU(ALUResult, stage1op, stage1srcValue, stage1dstValue);
    
    always@(*) ir = mainmem[pc];
    
    //fetch instruction
    always@(posedge clk)
    begin
        if(!halt)
        begin
            stage0op <= (isSquash ? `OPnop : op);
            //TODO:set stage 0's buffers
        end
    end
    
    //reg read
    always@(posedge clk)
    begin
        if(!halt)
        begin

        end
    end
    
    //ALU operation
    always@(posedge clk)
    begin
        if(!halt)
        begin

        end
    end
    
    //reg write
    always@(posedge clk)
    begin
        if(!halt)
        begin

        end
    end
endmodule

module processor_tb();

endmodule