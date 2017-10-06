VERSION         	:= $(shell git describe --tags --always)
AMI_NAME			:= "vault-consul-ubuntu-$(VERSION)"
SERVER_CM_TAG		:= "v3.31"
TLS_OWNER			?= "root"
PACKER_IMAGE		:= wpengine/packer
ANSIBLE_TEST_IMAGE	:= wpengine/ansible
ACCOUNTS			:= development corporate

MARKDOWN_LINTER := wpengine/mdl

# default is meant to generally map to Jenkinsfile/pipeline for anything other than the master branch
default: lint test terraform-plan

# all is meant to generally map to Jenkinsfile/pipeline for the master branch (minus deploying to prod ;P)
all: lint test packer-build-ami terraform-apply-development smoke-development

lint: markdownlint ansible-lint yamllint
test: test-packer

# ~*~*~*~* Linter Tasks *~*~*~*~
# Run markdown analysis tool.
markdownlint:
	@echo
	# Running markdownlint against all markdown files in this project...
	docker run --rm \
		--volume $(PWD):/workspace \
		${MARKDOWN_LINTER} /workspace
	@echo
	# Successfully linted Markdown.

ansible-lint:
	@echo
	# Running ansible-lint against all ansible playbooks in this project...
	docker run --rm \
		--volume $(PWD)/ansible:/workspace \
		$(ANSIBLE_TEST_IMAGE):latest \
		ansible-lint -p -x ANSIBLE0004,ANSIBLE0006,ANSIBLE0016,ANSIBLE0018 -v \
		/workspace/local.yml
	@echo
	# Successfully linted ansible.

yamllint: | lint-packer-template
	@echo
	# Running yamllint against all yaml in this project... or not... (.terraform get ends up with a bunch of malformed yaml as-is)
	#docker run --rm \
	#	--volume $(PWD):/workspace \
	#	wpengine/yamllint:latest \
	#	/workspace
	@echo
	# Successfully linted yaml.

lint-packer-template:
	@echo
	# Running yamllint against packer template
	docker run --rm \
		--volume $(PWD)/packer:/workspace \
		wpengine/yamllint:latest \
			/workspace
	@echo
	# Successfully linted yaml.

# ~*~*~*~* Test Tasks *~*~*~*~
test-packer: | packer-build-image
	docker run --volume $(PWD)/tests/testinfra:/tests \
		wpengine/vault-packer:$(VERSION) \
		py.test -v /tests

# ~*~*~*~* Smoke Tasks *~*~*~*~
smoke-: $(addprefix smoke-, $(ACCOUNTS))
smoke-%: |
	echo "This is where we would smoke $(*) if we got em"

# ~*~*~*~* Utility Tasks *~*~*~*~
clean: | ensure-tls-certs-get
	rm -rvf artifacts/*
	find packer \! -name 'variables.json' -a -name '*.json' -print
#	find . -name '.terraform' -type d -exec rm -rfv {} \;

	docker run --rm \
		--volume $(PWD)/terraform/modules/generate-tls-cert:/workspace \
		--volume $(PWD)/artifacts:/artifacts \
		--workdir=/workspace \
		wpengine/terraform \
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
	docker run --rm \
		--volume $(PWD)/terraform/modules/generate-tls-cert:/workspace \
		--workdir=/workspace \
		wpengine/terraform \
		terraform init

ensure-tls-certs-get: ensure-tls-certs-init
	docker run --rm \
		--volume $(PWD)/terraform/modules/generate-tls-cert:/workspace \
		--workdir=/workspace wpengine/terraform \
		terraform get

ensure-tls-certs-apply: ensure-artifacts-dir ensure-tls-certs-get
	@echo "=====> Using private-tls-cert module to ensure certs <====="
	docker run --rm \
		--volume $(PWD)/terraform/modules/generate-tls-cert:/workspace \
		--volume $(PWD)/artifacts:/artifacts \
		--workdir=/workspace wpengine/terraform \
		terraform apply \
		-var-file variables.json \
		-var 'private_key_file_path=/artifacts/vault.key.pem' \
		-var 'ca_public_key_file_path=/artifacts/vault.ca.crt.pem' \
		-var 'public_key_file_path=/artifacts/vault.crt.pem' \
		-var owner=$(TLS_OWNER)

packer-yaml-to-json:
	@echo
	# Running yamllint against packer template
	docker run --rm \
		-i \
		--entrypoint="" \
		--workdir=/workspace \
		--volume $(PWD)/packer:/workspace \
		wpengine/yamllint:latest \
			python /workspace/yaml2json.py vault-consul-ami/vault-consul.yaml
	@echo
	# Successfully linted yaml.

# ~*~*~*~* Packer Tasks *~*~*~*~
packer-build-image: | packer-yaml-to-json ensure-tls-certs-apply
	@echo "=====> Packer'ing up an docker image <====="
	docker run --rm \
		--volume /var/run/docker.sock:/var/run/docker.sock \
		--volume $(PWD):/workspace \
		--volume $(PWD)/artifacts:/artifacts \
		--workdir=/workspace \
		$(PACKER_IMAGE):latest \
		build \
			-except=vault-ubuntu-16.04-ami \
			-var version=$(VERSION) \
			-var-file packer/vault-consul-ami/variables.json \
			-var 'tls_private_key_path=artifacts/vault.key.pem' \
			-var 'ca_public_key_path=artifacts/vault.ca.crt.pem' \
			-var 'tls_public_key_path=artifacts/vault.crt.pem' \
			-var 'test_image_name=$(ANSIBLE_TEST_IMAGE)' \
			packer/vault-consul-ami/vault-consul.json

packer-build-ami: | packer-yaml-to-json ensure-tls-certs-apply
	@echo "=====> Packer'ing up an AMI <====="
	docker run --rm \
		--volume $(PWD):/workspace \
		--volume $(PWD)/artifacts:/artifacts \
		--workdir=/workspace \
		--env AWS_ACCESS_KEY_ID \
		--env AWS_SECRET_ACCESS_KEY \
		$(PACKER_IMAGE):latest \
			build \
			-except=vault-ubuntu-16.04-docker \
			-var version=$(VERSION) \
			-var-file packer/vault-consul-ami/variables.json \
			-var 'tls_private_key_path=/artifacts/vault.key.pem' \
			-var 'ca_public_key_path=/artifacts/vault.ca.crt.pem' \
			-var 'tls_public_key_path=/artifacts/vault.crt.pem' \
			packer/vault-consul-ami/vault-consul.json
	# TODO add packer profile to jenkins nodes IAM instance role

# ~*~*~*~* Terraform Tasks *~*~*~*~
terraform-init-: $(addprefix terraform-init-, $(ACCOUNTS))
terraform-init-%:
	docker run --rm \
		--workdir=/workspace \
		--volume $(PWD)/terraform/aws/$(*):/workspace \
		--volume $(HOME)/.ssh/github_rsa:/root/.ssh/id_rsa \
		--volume $(HOME)/.ssh/known_hosts:/root/.ssh/known_hosts \
		--env GIT_TRACE=1 \
		--env AWS_ACCESS_KEY_ID \
		--env AWS_SECRET_ACCESS_KEY \
		wpengine/terraform \
		terraform init .

terraform-get-: $(addprefix terraform-get-, $(ACCOUNTS))
terraform-get-%: | terraform-init-%
	docker run --rm \
		--workdir=/workspace \
		--volume $(PWD)/terraform/aws/$(*):/workspace \
		--volume $(HOME)/.ssh/github_rsa:/root/.ssh/id_rsa \
		--volume $(HOME)/.ssh/known_hosts:/root/.ssh/known_hosts \
		--env GIT_TRACE=1 \
		--env AWS_ACCESS_KEY_ID \
		--env AWS_SECRET_ACCESS_KEY \
		wpengine/terraform \
		terraform get .

terraform-plan-: $(addprefix terraform-plan-, $(ACCOUNTS))
terraform-plan-%: | terraform-get-%
	docker run \
		--workdir=/workspace \
		--volume $(PWD)/terraform/aws/$(*):/workspace \
		--env GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" \
		--volume $(HOME)/.ssh/github_rsa:/root/.ssh/id_rsa \
		--volume $(HOME)/.ssh/known_hosts:/root/.ssh/known_hosts \
		--env GIT_TRACE=1 \
		--env AWS_ACCESS_KEY_ID \
		--env AWS_SECRET_ACCESS_KEY \
		wpengine/terraform \
		terraform plan .

terraform-apply-: $(addprefix terraform-apply-, $(ACCOUNTS))
terraform-apply-%: | terraform-plan-%
	docker run \
		--workdir=/workspace \
		--volume $(PWD)/terraform/aws/$(*):/workspace \
		--env GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" \
		--volume $(HOME)/.ssh/github_rsa:/root/.ssh/id_rsa \
		--volume $(HOME)/.ssh/known_hosts:/root/.ssh/known_hosts \
		--env GIT_TRACE=1 \
		--env AWS_ACCESS_KEY_ID \
		--env AWS_SECRET_ACCESS_KEY \
		wpengine/terraform \
		terraform apply .

terraform-destroy-: $(addprefix terraform-destroy-, $(ACCOUNTS))
terraform-destroy-%: | terraform-get-%
	docker run \
		-it \
		--workdir=/workspace \
		--volume $(PWD)/terraform/aws/$(*):/workspace \
		--env GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" \
		--volume $(HOME)/.ssh/github_rsa:/root/.ssh/id_rsa \
		--volume $(HOME)/.ssh/known_hosts:/root/.ssh/known_hosts \
		--env GIT_TRACE=1 \
		--env AWS_ACCESS_KEY_ID \
		--env AWS_SECRET_ACCESS_KEY \
		wpengine/terraform \
		terraform destroy .
