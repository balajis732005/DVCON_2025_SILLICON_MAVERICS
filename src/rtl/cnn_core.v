`timescale 1ns/10ps

module cnn_core (
    
    clk,
    reset_n,
    i_soft_reset,
    i_cnn_weight,
    i_cnn_bias,
    i_in_valid,
    i_in_fmap,
    o_ot_valid,
    o_ot_fmap             
    );

    parameter   CNN_PIPE    = 5;  // no used, to use ctrl latency
parameter   CI          = 3;  // Number of Channel Input 
parameter   CO          = 16; // Number of Channel Output
parameter	KX			= 3;  // Number of Kernel X
parameter	KY			= 3;  // Number of Kernel Y

parameter   I_F_BW      = 8;  // Bit Width of Input Feature
parameter   W_BW        = 8;  // BW of weight parameter
parameter   B_BW        = 8;  // BW of bias parameter

parameter   M_BW        = 16; // I_F_BW * W_BW
parameter   AK_BW       = 20; // M_BW + log(KY*KX) Accum Kernel 
parameter   ACI_BW		= 22; // AK_BW + log (CI) Accum Channel Input
parameter   AB_BW       = 23; // ACI_BW + bias (#1). 
parameter   O_F_BW      = 23; // No Activation, So O_F_BW == AB_BW

parameter   O_F_ACC_BW  = 27; // for demo, O_F_BW + log (CO)

localparam LATENCY = 1;

input                               clk         	;
input                               reset_n     	;
input                               i_soft_reset	;
input     [CO*CI*KX*KY*W_BW-1 : 0]  i_cnn_weight 	;
input     [CO*B_BW-1    : 0]  		i_cnn_bias   	;
input                               i_in_valid  	;
input     [CI*KX*KY*I_F_BW-1 : 0]  	i_in_fmap    	;
output                              o_ot_valid  	;
output    [CO*O_F_BW-1 : 0]  		o_ot_fmap    	;

wire    [LATENCY-1 : 0] 	ce;
reg     [LATENCY-1 : 0] 	r_valid;
wire    [CO-1 : 0]          w_ot_valid;
always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        r_valid   <= {LATENCY{1'b0}};
    end else if(i_soft_reset) begin
        r_valid   <= {LATENCY{1'b0}};
    end else begin
        r_valid[LATENCY-1]  <= &w_ot_valid;
    end
end

assign	ce = r_valid;

wire    [CO-1 : 0]              w_in_valid;
wire    [CO*(ACI_BW)-1 : 0]  	w_ot_ci_acc;

wire      [CO*AB_BW-1 : 0]   add_bias  ;
reg       [CO*AB_BW-1 : 0]   r_add_bias;

assign o_ot_valid = r_valid[LATENCY-1];
assign o_ot_fmap  = r_add_bias;

endmodule