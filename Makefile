VERSION         := $(shell git describe --tags --always)
AMI_NAME		:= "vault-consul-ubuntu-$(VERSION)"
SERVER_CM_TAG	:= "v3.31"
TLS_OWNER		?= "root"

all: test build-images deploy

build-images: build-test-image build-ami

test: test-image test-ansible

test-ansible:
	@echo "TODO: test ansible. ansible-lint?"

test-image: | build-test-image
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

build-test-image-base:
	docker build -t jeffreymhogan/ubuntu-1604-test-image:$(VERSION) docker/ubuntu-1604-test-image
#	docker push jeffreymhogan/ubuntu-1604-test-image:$(VERSION)
	#docker save -o artifacts/vault-test-image.tar wpengine/vault-test-image:$(VERSION)

build-packer-image: | build-test-image-base
	docker build -t wpengine/packer:$(VERSION) docker/packer

build-test-image: | build-packer-image ensure-tls-certs-apply build-test-image-base
	@echo "=====> Packer'ing up an AMI <====="
	docker run \
		--rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(PWD):/workspace \
		-v $(PWD)/artifacts:/artifacts \
		-w /workspace \
		wpengine/packer:$(VERSION) \
		build \
			-except=ubuntu16-ami \
			-var version=$(VERSION) \
			-var-file packer/vault-consul-ami/variables.json \
			-var 'tls_private_key_path=artifacts/vault.key.pem' \
			-var 'ca_public_key_path=artifacts/vault.ca.crt.pem' \
			-var 'tls_public_key_path=artifacts/vault.crt.pem' \
			packer/vault-consul-ami/vault-consul.json
#	docker run \
#		--privileged \
#		-v $(PWD):/workspace \
#		-v $(PWD)/artifacts:/artifacts \
#		-w /workspace \
#		--entrypoint /bin/sh
#		wpengine/packer:$(VERSION) \
#		/bin/packer build \
#			-except=ubuntu16-ami \
#			-var version=$(VERSION) \
#			-var-file packer/vault-consul-ami/variables.json \
#			-var 'tls_private_key_path=artifacts/vault.key.pem' \
#			-var 'ca_public_key_path=artifacts/vault.ca.crt.pem' \
#			-var 'tls_public_key_path=artifacts/vault.crt.pem' \
#			packer/vault-consul-ami/vault-consul.json

deploy: build-ami
	@echo "Testing deploys?"
	$(eval AMI_ID := $(aws ec2 describe-images --filter "Name=name,Values=$(AMI_NAME)" --query 'Images[0].ImageId' --output text))


