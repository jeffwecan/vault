VERSION         	:= $(shell git describe --tags --always)
AMI_NAME			:= "vault-consul-ubuntu-$(VERSION)"
SERVER_CM_TAG		:= "v3.31"
TLS_OWNER			?= "root"
PACKER_IMAGE		:= wpengine/packer
PACKER_TEST_IMAGE	:= wpengine/ubuntu-1604-test-image

MARKDOWN_LINTER := wpengine/mdl

all: lint test build-images deploy

lint: markdownlint ansiblelint
# Run markdown analysis tool.
markdownlint: | pull-linters
	@echo
	# Running markdownlint against all markdown files in this project...
	@docker run -v `pwd`:/workspace ${MARKDOWN_LINTER} /workspace
	@echo
	# Successfully linted Markdown.

# Pull down our mdl image.
pull-linters:
	docker pull ${MARKDOWN_LINTER}

build-images: build-test-image build-ami

test: test-packer
	docker run -v $(PWD)/terraform/modules/generate-tls-cert:/workspace -v $(PWD)/artifacts:/artifacts -w /workspace wpengine/terraform \
		terraform destroy \
		-var-file variables.json \
		-var 'private_key_file_path=/artifacts/vault.key.pem' \
		-var 'ca_public_key_file_path=/artifacts/vault.ca.crt.pem' \
		-var 'public_key_file_path=/artifacts/vault.crt.pem' \
		-var owner=$(TLS_OWNER) \
		-force

ansiblelint: | build-ansible-lint-image
	docker run \
		-v $(PWD)/ansible:/workspace \
		wpengine/ansible-lint:$(VERSION) \
		-p -x ANSIBLE0004,ANSIBLE0006,ANSIBLE0016,ANSIBLE0018 -v \
		/workspace/local.yml

test-packer: | build-test-image
	@echo "=====> I'm like calling packer and testing the results or something here <====="

clean:
	rm -rvf artifacts/*

	docker run -v $(PWD)/terraform/modules/generate-tls-cert:/workspace -v $(PWD)/artifacts:/artifacts -w /workspace wpengine/terraform \
		terraform destroy \
		-var-file variables.json \
		-var 'private_key_file_path=/artifacts/vault.key.pem' \
		-var 'ca_public_key_file_path=/artifacts/vault.ca.crt.pem' \
		-var 'public_key_file_path=/artifacts/vault.crt.pem' \
		-var owner=$(TLS_OWNER) \
		-force

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

build-ami: | build-packer-image ensure-tls-certs-apply
	@echo "=====> Packer'ing up an AMI <====="
	docker run \
		-v $(PWD):/workspace \
		-v $(PWD)/artifacts:/artifacts \
		-w /workspace \
		wpengine/packer:$(VERSION) \
			build \
			-var version=$(VERSION) \
			-var-file packer/vault-consul-ami/variables.json \
			-var 'tls_private_key_path=/artifacts/vault.key.pem' \
			-var 'ca_public_key_path=/artifacts/vault.ca.crt.pem' \
			-var 'tls_public_key_path=/artifacts/vault.crt.pem' \
			packer/vault-consul-ami/vault-consul.json

build-ansible-lint-image:
	docker build -t wpengine/ansible-lint:$(VERSION) docker/ansible-lint

build-test-image-base:
	# This should go else where if we want to use it, maybe in a wpengine/ansible:16.04 image that also includes ansiblelint?
	docker build -t $(PACKER_TEST_IMAGE):$(VERSION) docker/ubuntu-1604-test-image

build-packer-image: | build-test-image-base
	docker build -t $(PACKER_IMAGE):$(VERSION) docker/packer

build-test-image: | build-packer-image ensure-tls-certs-apply build-test-image-base
	@echo "=====> Packer'ing up an docker image <====="
	docker run \
		--rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(PWD):/workspace \
		-v $(PWD)/artifacts:/artifacts \
		-w /workspace \
		$(PACKER_IMAGE):$(VERSION) \
		build \
			-except=ubuntu16-ami \
			-var version=$(VERSION) \
			-var-file packer/vault-consul-ami/variables.json \
			-var 'tls_private_key_path=artifacts/vault.key.pem' \
			-var 'ca_public_key_path=artifacts/vault.ca.crt.pem' \
			-var 'tls_public_key_path=artifacts/vault.crt.pem' \
			-var 'test_image_name=$(PACKER_TEST_IMAGE)' \
			packer/vault-consul-ami/vault-consul.json

deploy: build-ami
	@echo "Testing deploys?"
	$(eval AMI_ID := $(aws ec2 describe-images --filter "Name=name,Values=$(AMI_NAME)" --query 'Images[0].ImageId' --output text))


