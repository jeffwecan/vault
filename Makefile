VERSION         := $(shell git describe --tags --always)
AMI_NAME		:= "vault-consul-ubuntu-$(VERSION)"
SERVER_CM_TAG	:= "v3.31"
TLS_OWNER		?= "root"

all: test build-images deploy

build-images: build-ami

test: test-image test-ansible

test-ansible:
	@echo "TODO: test ansible. ansible-lint?"

test-image: | build-test-image
	@echo "=====> I'm like calling packer or something here <====="

clean:
	rm -rv artifacts

ensure-artifacts-dir:
	mkdir -p artifacts

ensure-tls-certs-init:
	docker run -v $(PWD)/terraform/modules/generate-tls-cert:/workspace -w /workspace wpengine/terraform terraform init

ensure-tls-certs-get: ensure-tls-certs-init
	docker run -v $(PWD)/terraform/modules/generate-tls-cert:/workspace -w /workspace wpengine/terraform terraform get

ensure-tls-certs-apply: ensure-artifacts-dir ensure-tls-certs-get
	@echo "=====> Using private-tls-cert module to ensure certs <====="
	docker run -v $(PWD)/terraform/modules/generate-tls-cert:/workspace -v $(PWD)/artifacts:/artifacts -w /workspace wpengine/terraform \
		terraform apply \
		-var-file variables.json \
		-var 'private_key_file_path=/artifacts/vault.key.pem' \
		-var 'ca_public_key_file_path=/artifacts/vault.ca.crt.pem' \
		-var 'public_key_file_path=/artifacts/vault.crt.pem' \
		-var owner=$(TLS_OWNER)

build-ami: | ensure-tls-certs-apply
	@echo "=====> Packer'ing up an AMI <====="
	docker run -v $(PWD):/workspace -v $(PWD)/artifacts:/artifacts -w /workspace hashicorp/packer:light build \
		-var version=$(VERSION) \
		-var-file packer/vault-consul-ami/variables.json \
		-var 'tls_private_key_path=/artifacts/vault.key.pem' \
		-var 'ca_public_key_path=/artifacts/vault.ca.crt.pem' \
		-var 'tls_public_key_path=/artifacts/vault.crt.pem' \
		packer/vault-consul-ami/vault-consul.json

build-test-image-base:
	docker build -t wpe-vault-test-image:$(VERSION) docker

build-test-image: | ensure-tls-certs-apply build-test-image-base
	@echo "=====> Packer'ing up an AMI <====="
	# TODO: don't use a janky packer bin from one users home dir in the future
	/home/jhogan_/packer build \
		-except=ubuntu16-ami \
		-var version=$(VERSION) \
		-var-file packer/vault-consul-ami/variables.json \
		-var 'tls_private_key_path=artifacts/vault.key.pem' \
		-var 'ca_public_key_path=artifacts/vault.ca.crt.pem' \
		-var 'tls_public_key_path=artifacts/vault.crt.pem' \
		packer/vault-consul-ami/vault-consul.json

deploy: build-ami
	@echo "Testing deploys?"
	$(eval AMI_ID := $(aws ec2 describe-images --filter "Name=name,Values=$(AMI_NAME)" --query 'Images[0].ImageId' --output text))


