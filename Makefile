GO_VERSION = 1.16.3
HELM_VERSION = 3.5.3
PROTOC_VERSION = 3.15.6
PROTOC_GEN_GO_VERSION = 1.26.0
PROTOC_GEN_BUF_LINT_VERSION = 0.41.0
PROTOC_GEN_GO_GRPC_VERSION = 1.1.0
GRPCURL_VERSION = 1.8.5

REPOSITORY_ROOT := $(patsubst %/,%,$(dir $(abspath $(MAKEFILE_LIST))))
BUILD_DIR = $(REPOSITORY_ROOT)/build
TOOLCHAIN_DIR = $(BUILD_DIR)/.toolchain
TOOLCHAIN_BIN = $(TOOLCHAIN_DIR)/bin
HELM = $(TOOLCHAIN_BIN)/helm
GOROOT = $(TOOLCHAIN_DIR)/go
GO = $(GOROOT)/bin/go
GRPCURL = $(TOOLCHAIN_BIN)/grpcurl

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
	HELM_PACKAGE = https://get.helm.sh/helm-v$(HELM_VERSION)-linux-amd64.tar.gz
# 	KUBECTL_PACKAGE = https://storage.googleapis.com/kubernetes-release/release/v$(KUBECTL_VERSION)/bin/linux/amd64/kubectl
	GO_PACKAGE = https://golang.org/dl/go$(GO_VERSION).linux-amd64.tar.gz
	PROTOC_PACKAGE = https://github.com/protocolbuffers/protobuf/releases/download/v$(PROTOC_VERSION)/protoc-$(PROTOC_VERSION)-linux-x86_64.zip
	PROTOC_GEN_BUF_LINT_PACKAGE=https://github.com/bufbuild/buf/releases/download/v${PROTOC_GEN_BUF_LINT_VERSION}/buf-Linux-x86_64
	GRPCURL_PACKAGE=https://github.com/fullstorydev/grpcurl/releases/download/v$(GRPCURL_VERSION)/grpcurl_$(GRPCURL_VERSION)_linux_x86_64.tar.gz
endif
ifeq ($(UNAME_S),Darwin)
	HELM_PACKAGE = https://get.helm.sh/helm-v$(HELM_VERSION)-darwin-amd64.tar.gz
# 	KUBECTL_PACKAGE = https://storage.googleapis.com/kubernetes-release/release/v$(KUBECTL_VERSION)/bin/darwin/amd64/kubectl
	GO_PACKAGE = https://golang.org/dl/go$(GO_VERSION).darwin-amd64.tar.gz
	PROTOC_PACKAGE = https://github.com/protocolbuffers/protobuf/releases/download/v$(PROTOC_VERSION)/protoc-$(PROTOC_VERSION)-osx-x86_64.zip
	PROTOC_GEN_BUF_LINT_PACKAGE=https://github.com/bufbuild/buf/releases/download/v${PROTOC_GEN_BUF_LINT_VERSION}/buf-Darwin-x86_64
	GRPCURL_PACKAGE=https://github.com/fullstorydev/grpcurl/releases/download/v$(GRPCURL_VERSION)/grpcurl_$(GRPCURL_VERSION)_osx_x86_64.tar.gz
endif

#######################################
## helm
##

## install helm
## usage: make install-helm
install-helm:
	mkdir -p $(TOOLCHAIN_BIN)
	mkdir -p $(TOOLCHAIN_DIR)/temp-helm
	cd $(TOOLCHAIN_DIR)/temp-helm && curl -Lo helm.tar.gz $(HELM_PACKAGE) && tar xzf helm.tar.gz --strip-components 1
	mv $(TOOLCHAIN_DIR)/temp-helm/helm $(HELM)
	rm -rf $(TOOLCHAIN_DIR)/temp-helm/

## create-local-values : create helm local-values.yaml
##
create-local-values:
	cat deployments/helm/local/local-values.yaml.dist | sed -e 's#{{path}}#$(REPOSITORY_ROOT)#g' > deployments/helm/local/local-values.yaml

#######################################
## Protobuf
##

## buf-generate
## usage: make buf-generate
buf-generate: $(TOOLCHAIN_BIN)/protoc $(GOPATH)/bin/protoc-gen-go $(GOPATH)/bin/protoc-gen-go-grpc $(TOOLCHAIN_BIN)/buf
	./build/.toolchain/bin/buf generate --template api/buf.gen.yaml api

## install protoc
$(TOOLCHAIN_BIN)/protoc:
	mkdir -p $(TOOLCHAIN_BIN)
	curl -o $(TOOLCHAIN_DIR)/protoc-temp.zip -L $(PROTOC_PACKAGE)
	(cd $(TOOLCHAIN_DIR); unzip -q -o protoc-temp.zip)
	rm $(TOOLCHAIN_DIR)/protoc-temp.zip $(TOOLCHAIN_DIR)/readme.txt

## install protoc-gen-go
$(GOPATH)/bin/protoc-gen-go: $(GOROOT)
	$(GO) install google.golang.org/protobuf/cmd/protoc-gen-go@v${PROTOC_GEN_GO_VERSION}

## install protoc-gen-go-grpc
$(GOPATH)/bin/protoc-gen-go-grpc: $(GOROOT)
	$(GO) install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v${PROTOC_GEN_GO_GRPC_VERSION}

## install buf
$(TOOLCHAIN_BIN)/buf:
	mkdir -p $(TOOLCHAIN_BIN)
	cd $(TOOLCHAIN_BIN) && curl -sSL ${PROTOC_GEN_BUF_LINT_PACKAGE} -o "buf"
	chmod u+x "$(TOOLCHAIN_BIN)/buf"

#######################################
## go tools
##

## install go
$(GOROOT):
	mkdir -p $(TOOLCHAIN_DIR)
	curl -L $(GO_PACKAGE) | tar xzC $(TOOLCHAIN_DIR)

## buf-generate
## usage: make install-grpcurl
install-grpcurl:
	mkdir -p $(TOOLCHAIN_BIN)
	mkdir -p $(TOOLCHAIN_DIR)/temp-grpcurl
	cd $(TOOLCHAIN_DIR)/temp-grpcurl && curl -Lo grpcurl.tar.gz $(GRPCURL_PACKAGE) && tar xzf grpcurl.tar.gz
	mv $(TOOLCHAIN_DIR)/temp-grpcurl/grpcurl $(GRPCURL)
	rm -rf $(TOOLCHAIN_DIR)/temp-grpcurl/
