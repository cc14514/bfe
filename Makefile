# Copyright (c) 2019 The BFE Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# init project path
WORKROOT := $(shell pwd)
OUTDIR   := $(WORKROOT)/output
OS		 := $(shell go env GOOS)

# init environment variables
export PATH        := $(shell go env GOPATH)/bin:$(PATH)
export GO111MODULE := on

# init command params
GO           := go
GOBUILD      := $(GO) build
GOTEST       := $(GO) test
GOVET        := $(GO) vet
GOGET        := $(GO) get
GOGEN        := $(GO) generate
GOCLEAN      := $(GO) clean
GOINSTALL    := $(GO) install
GOFLAGS      := -race
STATICCHECK  := staticcheck
LICENSEEYE   := license-eye
PIP          := pip3
PIPINSTALL   := $(PIP) install

# init arch
ARCH := $(shell getconf LONG_BIT)
ifeq ($(ARCH),64)
	GOTEST += $(GOFLAGS)
endif

# init bfe version
BFE_VERSION ?= $(shell cat VERSION)
# init git commit id
GIT_COMMIT ?= $(shell git rev-parse HEAD)

# init bfe packages
BFE_PKGS := $(shell go list ./...)

# go install package
# $(1) package name
# $(2) package address
define INSTALL_PKG
	@echo installing $(1)
	$(GOINSTALL) $(2)
	@echo $(1) installed
endef

define PIP_INSTALL_PKG
	@echo installing $(1)
	$(PIPINSTALL) $(1)
	@echo $(1) installed
endef

# make, make all
all: prepare compile package

# make, make strip
strip: prepare compile-strip package

# make prepare, download dependencies
prepare: prepare-dep prepare-gen
prepare-dep:
	$(call INSTALL_PKG, goyacc, golang.org/x/tools/cmd/goyacc@latest)
prepare-gen:
	cd "bfe_basic/condition/parser" && $(GOGEN)

# make compile, go build
compile: test build
build:
ifeq ($(OS),darwin)
	$(GOBUILD) -ldflags "-X main.version=$(BFE_VERSION) -X main.commit=$(GIT_COMMIT)"
else
	$(GOBUILD) -ldflags "-X main.version=$(BFE_VERSION) -X main.commit=$(GIT_COMMIT) -extldflags=-static"
endif

# make compile-strip, go build without symbols and DWARFs
compile-strip: test build-strip
build-strip:
ifeq ($(OS),darwin)
	$(GOBUILD) -ldflags "-X main.version=$(BFE_VERSION) -X main.commit=$(GIT_COMMIT) -s -w"
else
	$(GOBUILD) -ldflags "-X main.version=$(BFE_VERSION) -X main.commit=$(GIT_COMMIT) -extldflags=-static -s -w"
endif

# make test, test your code
test: test-case vet-case
test-case:
	$(GOTEST) -cover ./...
vet-case:
	${GOVET} ./...

# make coverage for codecov
coverage:
	echo -n > coverage.txt
	for pkg in $(BFE_PKGS) ; do $(GOTEST) -coverprofile=profile.out -covermode=atomic $${pkg} && cat profile.out >> coverage.txt; done

# make package
package:
	mkdir -p $(OUTDIR)/bin
	mv bfe  $(OUTDIR)/bin
	cp -r conf $(OUTDIR)

# make deps
deps:
	$(call PIP_INSTALL_PKG, pre-commit)
	$(call INSTALL_PKG, goyacc, golang.org/x/tools/cmd/goyacc@latest)
	$(call INSTALL_PKG, staticcheck, honnef.co/go/tools/cmd/staticcheck)
	$(call INSTALL_PKG, license-eye, github.com/apache/skywalking-eyes/cmd/license-eye@latest)

# make precommit, enable autoupdate and install with hooks
precommit:
	pre-commit autoupdate
	pre-commit install --install-hooks

# make check
check:
	$(STATICCHECK) ./...

# make license-check, check code file's license declaration
license-check:
	$(LICENSEEYE) header check

# make license-fix, fix code file's license declaration
license-fix:
	$(LICENSEEYE) header fix

# make docker
docker:
	docker build \
		-t bfe:$(BFE_VERSION) \
		-f Dockerfile \
		.

# Kubernetes image build targets
DOCKER_DIR := deploy/docker
BASE_IMAGE_NAME ?= bfe-base
BFE_IMAGE_NAME ?= bfe
CONF_AGENT_VERSION ?= $(shell cat $(DOCKER_DIR)/CONF_AGENT_VERSION)
VARIANT ?= debug
PLATFORMS ?= linux/amd64,linux/arm64
OUTPUT_TYPE ?= docker
BUILDER_NAME := bfe-builder
NO_CACHE ?= false

# make k8s-init-buildx: Initialize buildx builder for multi-platform builds
k8s-init-buildx:
	@docker buildx inspect $(BUILDER_NAME) >/dev/null 2>&1 || \
		docker buildx create --name $(BUILDER_NAME) --driver docker-container --use
	@docker buildx use $(BUILDER_NAME)

# make k8s-base-debug: Build debug base image (with bash/vim)
k8s-base-debug:
	@echo "Building debug base image..."
	@NORM_VERSION=$$(echo "$(CONF_AGENT_VERSION)" | sed 's/^v*/v/'); \
	docker buildx inspect $(BUILDER_NAME) >/dev/null 2>&1 || docker buildx create --name $(BUILDER_NAME) --use; \
	if [ "$(OUTPUT_TYPE)" = "oci" ]; then \
		mkdir -p output; \
		docker buildx build \
			--platform $(PLATFORMS) \
			--build-arg CONF_AGENT_VERSION=$(CONF_AGENT_VERSION) \
			-t $(BASE_IMAGE_NAME):$$NORM_VERSION-debug \
			-f $(DOCKER_DIR)/Dockerfile.base-debug \
			--output type=oci,dest=output/$(BASE_IMAGE_NAME)-$$NORM_VERSION-debug.tar \
			.; \
	else \
		docker buildx build \
			--platform $(shell uname -m | sed 's/x86_64/linux\/amd64/;s/aarch64/linux\/arm64/;s/arm64/linux\/arm64/') \
			--build-arg CONF_AGENT_VERSION=$(CONF_AGENT_VERSION) \
			-t $(BASE_IMAGE_NAME):$$NORM_VERSION-debug \
			-f $(DOCKER_DIR)/Dockerfile.base-debug \
			--load \
			.; \
	fi; \
	echo "Debug base image built: $(BASE_IMAGE_NAME):$$NORM_VERSION-debug"; \
	echo "Cleaning up dangling images..."; \
	docker image prune -f

# make k8s-base-prod: Build production base image (minimal)
k8s-base-prod:
	@echo "Building production base image..."
	@NORM_VERSION=$$(echo "$(CONF_AGENT_VERSION)" | sed 's/^v*/v/'); \
	docker buildx inspect $(BUILDER_NAME) >/dev/null 2>&1 || docker buildx create --name $(BUILDER_NAME) --use; \
	if [ "$(OUTPUT_TYPE)" = "oci" ]; then \
		mkdir -p output; \
		docker buildx build \
			--platform $(PLATFORMS) \
			--build-arg CONF_AGENT_VERSION=$(CONF_AGENT_VERSION) \
			-t $(BASE_IMAGE_NAME):$$NORM_VERSION \
			-f $(DOCKER_DIR)/Dockerfile.base-prod \
			--output type=oci,dest=output/$(BASE_IMAGE_NAME)-$$NORM_VERSION.tar \
			.; \
	else \
		docker buildx build \
			--platform $(shell uname -m | sed 's/x86_64/linux\/amd64/;s/aarch64/linux\/arm64/;s/arm64/linux\/arm64/') \
			--build-arg CONF_AGENT_VERSION=$(CONF_AGENT_VERSION) \
			-t $(BASE_IMAGE_NAME):$$NORM_VERSION \
			-f $(DOCKER_DIR)/Dockerfile.base-prod \
			--load \
			.; \
	fi; \
	echo "Production base image built: $(BASE_IMAGE_NAME):$$NORM_VERSION"; \
	echo "Cleaning up dangling images..."; \
	docker image prune -f

# make k8s-base: Build both debug and production base images
k8s-base: k8s-base-debug k8s-base-prod

# make k8s-image: Build BFE application image for Kubernetes
k8s-image:
	@echo "Building BFE application image..."
	@NORM_CONF_VERSION=$$(echo "$(CONF_AGENT_VERSION)" | sed 's/^v*/v/'); \
	NORM_BFE_VERSION=$$(echo "$(BFE_VERSION)" | sed 's/^v*/v/'); \
	ARCH=$$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/'); \
	BASE_TAG=$$(if [ "$(VARIANT)" = "prod" ]; then echo "$$NORM_CONF_VERSION"; else echo "$$NORM_CONF_VERSION-debug"; fi); \
	IMAGE_TAG="$$NORM_BFE_VERSION"; \
	echo "Using base image: $(BASE_IMAGE_NAME):$$BASE_TAG"; \
	echo "Building application image: $(BFE_IMAGE_NAME):$$IMAGE_TAG"; \
	if [ "$(OUTPUT_TYPE)" = "oci" ]; then \
		mkdir -p output; \
		docker buildx create --name $(BUILDER_NAME) --use >/dev/null 2>&1 || docker buildx use $(BUILDER_NAME); \
		docker buildx build \
			--platform $(PLATFORMS) \
			--build-arg BASE_IMAGE=$(BASE_IMAGE_NAME):$$BASE_TAG \
			-t $(BFE_IMAGE_NAME):$$IMAGE_TAG \
			-f $(DOCKER_DIR)/Dockerfile \
			--output type=oci,dest=output/$(BFE_IMAGE_NAME)-$$IMAGE_TAG.tar \
			.; \
	else \
		docker build \
			$$(if [ "$(NO_CACHE)" = "true" ]; then echo "--no-cache"; fi) \
			--build-arg BASE_IMAGE=$(BASE_IMAGE_NAME):$$BASE_TAG \
			-t $(BFE_IMAGE_NAME):$$IMAGE_TAG-$$ARCH \
			-t $(BFE_IMAGE_NAME):$$IMAGE_TAG \
			-t $(BFE_IMAGE_NAME):latest \
			-f $(DOCKER_DIR)/Dockerfile \
			.; \
	fi; \
	echo "BFE application image built: $(BFE_IMAGE_NAME):$$IMAGE_TAG-$$ARCH (also tagged as $$IMAGE_TAG and latest)"; \
	echo "Cleaning up dangling images..."; \
	docker image prune -f

# make k8s-all: Build base images and BFE application image
k8s-all: k8s-base k8s-image

# make k8s-push: Build and push multi-arch images to registry (REGISTRY is required)
# Usage: make k8s-push REGISTRY=ghcr.io/your-org
k8s-push: k8s-init-buildx
	@if [ -z "$(REGISTRY)" ]; then \
		echo "Error: REGISTRY is required"; \
		echo "Usage: make k8s-push REGISTRY=ghcr.io/your-org"; \
		exit 1; \
	fi
	@echo "Building and pushing multi-arch images to $(REGISTRY)..."
	@NORM_CONF_VERSION=$$(echo "$(CONF_AGENT_VERSION)" | sed 's/^v*/v/'); \
	NORM_BFE_VERSION=$$(echo "$(BFE_VERSION)" | sed 's/^v*/v/'); \
	echo "Step 1/3: Building multi-arch base images..."; \
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg CONF_AGENT_VERSION=$(CONF_AGENT_VERSION) \
		-t $(REGISTRY)/$(BASE_IMAGE_NAME):$$NORM_CONF_VERSION-debug \
		-f $(DOCKER_DIR)/Dockerfile.base-debug \
		--push \
		.; \
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg CONF_AGENT_VERSION=$(CONF_AGENT_VERSION) \
		-t $(REGISTRY)/$(BASE_IMAGE_NAME):$$NORM_CONF_VERSION \
		-f $(DOCKER_DIR)/Dockerfile.base-prod \
		--push \
		.; \
	echo "Step 2/3: Building multi-arch application image..."; \
	BASE_TAG=$$(if [ "$(VARIANT)" = "prod" ]; then echo "$$NORM_CONF_VERSION"; else echo "$$NORM_CONF_VERSION-debug"; fi); \
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg BASE_IMAGE=$(REGISTRY)/$(BASE_IMAGE_NAME):$$BASE_TAG \
		-t $(REGISTRY)/$(BFE_IMAGE_NAME):$$NORM_BFE_VERSION \
		-t $(REGISTRY)/$(BFE_IMAGE_NAME):latest \
		-f $(DOCKER_DIR)/Dockerfile \
		--push \
		.; \
	echo "Step 3/3: Verifying manifest..."; \
	docker buildx imagetools inspect $(REGISTRY)/$(BFE_IMAGE_NAME):$$NORM_BFE_VERSION; \
	echo ""; \
	echo "✅ Multi-arch images pushed successfully!"; \
	echo "   Image: $(REGISTRY)/$(BFE_IMAGE_NAME):$$NORM_BFE_VERSION"; \
	echo "   Platforms: $(PLATFORMS)"; \
	echo ""; \
	echo "Pull on any platform:"; \
	echo "   docker pull $(REGISTRY)/$(BFE_IMAGE_NAME):$$NORM_BFE_VERSION"

# make clean
clean:
	$(GOCLEAN)
	rm -rf $(OUTDIR)k8s-
	rm -rf $(WORKROOT)/bfe
	rm -rf $(GOPATH)/pkg/linux_amd64

# avoid filename conflict and speed up build 
.PHONY: all prepare compile test package clean build \
        k8s-base-debug k8s-base-prod k8s-base k8s-image k8s-all k8s-push init-buildx
