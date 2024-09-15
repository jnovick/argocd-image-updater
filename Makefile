IMAGE_NAMESPACE?=171312943278.dkr.ecr.us-west-2.amazonaws.com
IMAGE_NAME=argocd-image-updater
IMAGE_TAG?=allow-adding-new-helm-value
ifdef IMAGE_NAMESPACE
IMAGE_PREFIX=${IMAGE_NAMESPACE}/
else
IMAGE_PREFIX=
endif
IMAGE_PUSH?=no
OS?=$(shell go env GOOS)
ARCH?=$(shell go env GOARCH)
OUTDIR?=dist
BINNAME?=argocd-image-updater

CURRENT_DIR=$(shell pwd)
VERSION=$(shell cat ${CURRENT_DIR}/VERSION)
GIT_COMMIT=$(shell git rev-parse HEAD)
BUILD_DATE=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ')

LDFLAGS=

RELEASE_IMAGE_PLATFORMS?=linux/amd64,linux/arm64

VERSION_PACKAGE=github.com/argoproj-labs/argocd-image-updater/pkg/version
ifeq ($(IMAGE_PUSH), yes)
DOCKERX_PUSH=--push
else
DOCKERX_PUSH=
endif

override LDFLAGS += -extldflags "-static"
override LDFLAGS += \
	-X ${VERSION_PACKAGE}.version=${VERSION} \
	-X ${VERSION_PACKAGE}.gitCommit=${GIT_COMMIT} \
	-X ${VERSION_PACKAGE}.buildDate=${BUILD_DATE}

.PHONY: all
all: prereq controller

.PHONY: clean
clean: clean-image
	rm -rf vendor/

.PHONY: clean-image
clean-image:
	rm -rf dist/
	rm -f coverage.out

.PHONY: mod-tidy
mod-tidy:
	go mod tidy

.PHONY: mod-download
mod-download:
	go mod download

.PHONY: mod-vendor
mod-vendor:
	go mod vendor

.PHONY: test
test:
	go test -coverprofile coverage.out `go list ./... | egrep -v '(test|mocks|ext/)'`


.PHONY: test-race
test-race:
	go test -race -coverprofile coverage.out `go list ./... | egrep -v '(test|mocks|ext/)'`

.PHONY: test-manifests
test-manifests:
	./scripts/test_manifests.sh


.PHONY: prereq
prereq:
	mkdir -p dist

.PHONY: controller
controller:
	CGO_ENABLED=0 GOOS=${OS} GOARCH=${ARCH} go build -ldflags '${LDFLAGS}' -o ${OUTDIR}/${BINNAME} cmd/*.go

.PHONY: image
image: clean-image
	docker build \
		-t ${IMAGE_PREFIX}${IMAGE_NAME}:${IMAGE_TAG} \
		-t ${IMAGE_PREFIX}${IMAGE_NAME}:latest \
		--pull \
		.

.PHONY: multiarch-image
multiarch-image:
	docker buildx build \
		-t ${IMAGE_PREFIX}${IMAGE_NAME}:${IMAGE_TAG} \
		-t ${IMAGE_PREFIX}${IMAGE_NAME}:latest \
		--progress plain \
		--pull \
		--platform ${RELEASE_IMAGE_PLATFORMS} ${DOCKERX_PUSH} \
		.

.PHONY: multiarch-image
multiarch-image-push:
	docker buildx build \
		-t ${IMAGE_PREFIX}${IMAGE_NAME}:${IMAGE_TAG} \
		-t ${IMAGE_PREFIX}${IMAGE_NAME}:latest \
		--progress plain \
		--pull \
		--push \
		--platform ${RELEASE_IMAGE_PLATFORMS} ${DOCKERX_PUSH} \
		.

.PHONY: image-push
image-push: image
	docker push ${IMAGE_PREFIX}${IMAGE_NAME}:${IMAGE_TAG}
	docker push ${IMAGE_PREFIX}${IMAGE_NAME}:latest
