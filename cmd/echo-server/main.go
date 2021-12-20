package main

import (
	"context"
	"fmt"
	"github.com/YasunoriISHIKAWA/anthos-service-mesh/pkg/pb"
	"github.com/pkg/errors"
	"google.golang.org/grpc"
	"google.golang.org/grpc/metadata"
	"log"
	"net"
	"os"
	"strings"
)

const port = ":50051"

type EchoServiceServer struct {
	pb.UnimplementedEchoServiceServer
}

func (s *EchoServiceServer) Call(ctx context.Context, req *pb.EchoCallRequest) (*pb.EchoCallResponse, error) {
	env := "none"
	md, ok := metadata.FromIncomingContext(ctx)
	if ok {
		env = strings.Join(md["env"], ",")
	}
	log.Printf("client request env:%s", env)
	return &pb.EchoCallResponse{
		Message: fmt.Sprintf("Hello World! ServerEnv:%s, ClientEnv:%s", os.Getenv("ENV"), env),
	}, nil
}

func set() error {
	ln, err := net.Listen("tcp", port)
	if err != nil {
		return errors.Wrap(err, "port listen")
	}
	s := grpc.NewServer()
	var server EchoServiceServer
	pb.RegisterEchoServiceServer(s, &server)
	if err := s.Serve(ln); err != nil {
		return errors.Wrap(err, "serve")
	}
	return nil
}

func main() {
	log.Printf("start server. port%s, env:%s", port, os.Getenv("ENV"))
	if err := set(); err != nil {
		errors.New(fmt.Sprintf("%v", err))
	}
}
