// Hand shake Synchronizer
module handshake_sync(
  output reg [31:0]Rd_port,
  output REQ,ACK,
  input clk_a,clk_b,rst,
  input [31:0]Wr_port);
  wire qb2;
  REQ_gen Tx_fsm(REQ,rst,clk_a,Wr_port);
  flop_sync Multi_flop_synchronizer_B(qb2,REQ,clk_b,rst);
  flop_sync Multi_flop_synchronizer_A(ACK,qb2,clk_a,rst);
  always@(posedge clk_b) Rd_port<=Wr_port;
endmodule

// Request Signal generator
module REQ_gen(
  output reg Req,
  input rst,clk,
  input [31:0]data);
  reg [31:0]q;
  reg [1:0]count;
  reg [31:0]comp;
  reg trigger;
  integer i,j;

  always@(posedge clk or posedge rst) begin
    if(rst) q<=32'd0;
    else q<=data;
  end

  always@(posedge clk or posedge rst) begin
    if(rst || (count==3)) Req<=1'b0;
    else if(trigger) Req<=1'b1;
    else Req<=Req;
  end

  always@(posedge clk or posedge rst) begin
    if(rst || (count==3)) count<=2'd0;
    else if(Req) count<=count+1'b1;
    else count<=count;
  end

  always@(*) begin
    for(i=0;i<32;i=i+1) begin
      comp[i]=data[i]^q[i];
    end
    trigger=comp[0];
    for(j=1;j<32;j=j+1) begin
      trigger=trigger|comp[j];
    end
  end
endmodule

// Multi Flop Synchronizer
module flop_sync(
  output reg q2,
  input d,clk,rst);
  reg q1;
  always@(posedge clk) begin
    if(rst) begin
      q1<=1'b0;
      q2<=1'b0;
    end
    else begin
      q1<=d;
      q2<=q1;
    end
  end
endmodule
