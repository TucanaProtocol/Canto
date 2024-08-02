// Code generated by protoc-gen-go-grpc. DO NOT EDIT.
// versions:
// - protoc-gen-go-grpc v1.3.0
// - protoc             (unknown)
// source: canto/coinswap/v1/query.proto

package coinswapv1

import (
	context "context"
	grpc "google.golang.org/grpc"
	codes "google.golang.org/grpc/codes"
	status "google.golang.org/grpc/status"
)

// This is a compile-time assertion to ensure that this generated file
// is compatible with the grpc package it is being compiled against.
// Requires gRPC-Go v1.32.0 or later.
const _ = grpc.SupportPackageIsVersion7

const (
	Query_Params_FullMethodName         = "/canto.coinswap.v1.Query/Params"
	Query_LiquidityPool_FullMethodName  = "/canto.coinswap.v1.Query/LiquidityPool"
	Query_LiquidityPools_FullMethodName = "/canto.coinswap.v1.Query/LiquidityPools"
)

// QueryClient is the client API for Query service.
//
// For semantics around ctx use and closing/ending streaming RPCs, please refer to https://pkg.go.dev/google.golang.org/grpc/?tab=doc#ClientConn.NewStream.
type QueryClient interface {
	// Params returns parameters of the module.
	Params(ctx context.Context, in *QueryParamsRequest, opts ...grpc.CallOption) (*QueryParamsResponse, error)
	// LiquidityPool returns the liquidity pool for the provided
	// lpt_denom
	LiquidityPool(ctx context.Context, in *QueryLiquidityPoolRequest, opts ...grpc.CallOption) (*QueryLiquidityPoolResponse, error)
	// LiquidityPools returns all the liquidity pools available
	LiquidityPools(ctx context.Context, in *QueryLiquidityPoolsRequest, opts ...grpc.CallOption) (*QueryLiquidityPoolsResponse, error)
}

type queryClient struct {
	cc grpc.ClientConnInterface
}

func NewQueryClient(cc grpc.ClientConnInterface) QueryClient {
	return &queryClient{cc}
}

func (c *queryClient) Params(ctx context.Context, in *QueryParamsRequest, opts ...grpc.CallOption) (*QueryParamsResponse, error) {
	out := new(QueryParamsResponse)
	err := c.cc.Invoke(ctx, Query_Params_FullMethodName, in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (c *queryClient) LiquidityPool(ctx context.Context, in *QueryLiquidityPoolRequest, opts ...grpc.CallOption) (*QueryLiquidityPoolResponse, error) {
	out := new(QueryLiquidityPoolResponse)
	err := c.cc.Invoke(ctx, Query_LiquidityPool_FullMethodName, in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (c *queryClient) LiquidityPools(ctx context.Context, in *QueryLiquidityPoolsRequest, opts ...grpc.CallOption) (*QueryLiquidityPoolsResponse, error) {
	out := new(QueryLiquidityPoolsResponse)
	err := c.cc.Invoke(ctx, Query_LiquidityPools_FullMethodName, in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

// QueryServer is the server API for Query service.
// All implementations must embed UnimplementedQueryServer
// for forward compatibility
type QueryServer interface {
	// Params returns parameters of the module.
	Params(context.Context, *QueryParamsRequest) (*QueryParamsResponse, error)
	// LiquidityPool returns the liquidity pool for the provided
	// lpt_denom
	LiquidityPool(context.Context, *QueryLiquidityPoolRequest) (*QueryLiquidityPoolResponse, error)
	// LiquidityPools returns all the liquidity pools available
	LiquidityPools(context.Context, *QueryLiquidityPoolsRequest) (*QueryLiquidityPoolsResponse, error)
	mustEmbedUnimplementedQueryServer()
}

// UnimplementedQueryServer must be embedded to have forward compatible implementations.
type UnimplementedQueryServer struct {
}

func (UnimplementedQueryServer) Params(context.Context, *QueryParamsRequest) (*QueryParamsResponse, error) {
	return nil, status.Errorf(codes.Unimplemented, "method Params not implemented")
}
func (UnimplementedQueryServer) LiquidityPool(context.Context, *QueryLiquidityPoolRequest) (*QueryLiquidityPoolResponse, error) {
	return nil, status.Errorf(codes.Unimplemented, "method LiquidityPool not implemented")
}
func (UnimplementedQueryServer) LiquidityPools(context.Context, *QueryLiquidityPoolsRequest) (*QueryLiquidityPoolsResponse, error) {
	return nil, status.Errorf(codes.Unimplemented, "method LiquidityPools not implemented")
}
func (UnimplementedQueryServer) mustEmbedUnimplementedQueryServer() {}

// UnsafeQueryServer may be embedded to opt out of forward compatibility for this service.
// Use of this interface is not recommended, as added methods to QueryServer will
// result in compilation errors.
type UnsafeQueryServer interface {
	mustEmbedUnimplementedQueryServer()
}

func RegisterQueryServer(s grpc.ServiceRegistrar, srv QueryServer) {
	s.RegisterService(&Query_ServiceDesc, srv)
}

func _Query_Params_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(QueryParamsRequest)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(QueryServer).Params(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: Query_Params_FullMethodName,
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(QueryServer).Params(ctx, req.(*QueryParamsRequest))
	}
	return interceptor(ctx, in, info, handler)
}

func _Query_LiquidityPool_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(QueryLiquidityPoolRequest)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(QueryServer).LiquidityPool(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: Query_LiquidityPool_FullMethodName,
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(QueryServer).LiquidityPool(ctx, req.(*QueryLiquidityPoolRequest))
	}
	return interceptor(ctx, in, info, handler)
}

func _Query_LiquidityPools_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(QueryLiquidityPoolsRequest)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(QueryServer).LiquidityPools(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: Query_LiquidityPools_FullMethodName,
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(QueryServer).LiquidityPools(ctx, req.(*QueryLiquidityPoolsRequest))
	}
	return interceptor(ctx, in, info, handler)
}

// Query_ServiceDesc is the grpc.ServiceDesc for Query service.
// It's only intended for direct use with grpc.RegisterService,
// and not to be introspected or modified (even as a copy)
var Query_ServiceDesc = grpc.ServiceDesc{
	ServiceName: "canto.coinswap.v1.Query",
	HandlerType: (*QueryServer)(nil),
	Methods: []grpc.MethodDesc{
		{
			MethodName: "Params",
			Handler:    _Query_Params_Handler,
		},
		{
			MethodName: "LiquidityPool",
			Handler:    _Query_LiquidityPool_Handler,
		},
		{
			MethodName: "LiquidityPools",
			Handler:    _Query_LiquidityPools_Handler,
		},
	},
	Streams:  []grpc.StreamDesc{},
	Metadata: "canto/coinswap/v1/query.proto",
}
