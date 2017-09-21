VERSION         := $(shell git describe --tags --always)
AMI_NAME		:= "vault-consul-ubuntu-$(VERSION)"
SERVER_CM_TAG	:= "v3.31"
TLS_OWNER		?= $(whoami)

all: test build-images deploy

build-images: build-ami

test: test-image test-ansible

test-ansible:
	@echo "TODO: test ansible. ansible-lint?"

test-image: | build-test-image
	@echo "=====> I'm like calling packer or something here <====="

ensure-tls-certs-init:
	docker run -v $(PWD)/terraform/modules/generate-tls-cert:/workspace -w /workspace wpengine/terraform terraform init

ensure-tls-certs-get: ensure-tls-certs-init
	docker run -v $(PWD)/terraform/modules/generate-tls-cert:/workspace -w /workspace wpengine/terraform terraform get

ensure-tls-certs-apply: ensure-tls-certs-get
	@echo "=====> Using private-tls-cert module to ensure certs <====="
	docker run -v $(PWD)/terraform/modules/generate-tls-cert:/workspace -w /workspace wpengine/terraform \
		terraform apply \
        -var-file variables.json \
		-var 'owner=$(TLS_OWNER)'

build-ami: | ensure-tls-certs-apply
	@echo "=====> Packer'ing up an AMI <====="
	@packer build \
		-var version=$(VERSION) \
		-var-file packer/vault-consul-ami/variables.json \
		packer/vault-consul-ami/vault-consul.json

build-test-image-base:
	docker build -t wpe-vault-test-image:$(VERSION) docker


build-test-image: | ensure-tls-certs-apply build-test-image-base
	@echo "=====> Packer'ing up an AMI <====="
	packer build \
		-except=ubuntu16-ami \
		-var version=$(VERSION) \
		-var-file packer/vault-consul-ami/variables.json \
		packer/vault-consul-ami/vault-consul.json

deploy: build-ami
	@echo "Testing deploys?"
	$(eval AMI_ID := $(aws ec2 describe-images --filter "Name=name,Values=$(AMI_NAME)" --query 'Images[0].ImageId' --output text))


