FROM golang:1.16.3-buster

WORKDIR /app
ENV GOPATH /app/.go

COPY . .

RUN go build ./cmd/echo-server
