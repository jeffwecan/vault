VERSION         	:= $(shell git describe --tags --always)
AMI_NAME			:= "vault-consul-ubuntu-$(VERSION)"
SERVER_CM_TAG		:= "v3.31"
TLS_OWNER			?= "root"

MARKDOWN_LINTER 	:= wpengine/mdl
YAML_LINTER			:= wpengine/yamllint
TERRAFORM_IMAGE		:= wpengine/terraform
PACKER_IMAGE		:= wpengine/packer
ANSIBLE_TEST_IMAGE	:= wpengine/ansible
ACCOUNTS			:= development corporate

# default is meant to generally map to Jenkinsfile/pipeline for anything other than the master branch
default: lint test terraform-plan

# all is meant to generally map to Jenkinsfile/pipeline for the master branch (minus deploying to prod ;P)
all: lint test packer-build-ami terraform-apply-development smoke-development

lint: markdownlint ansible-lint yamllint terraform-validate
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
	@echo # TODO: think about linting other yaml things here? maybe exclude the yaml that *could* be pulled down by terraform get and placed in .terraform subidrs

lint-packer-template:
	@echo
	# Running yamllint against packer template
	docker run --rm \
		--volume $(PWD)/packer:/workspace \
		$(YAML_LINTER):latest \
			/workspace
	@echo
	# Successfully linted yaml.

# ~*~*~*~* Test Tasks *~*~*~*~
test-packer: | packer-build-image
	docker run --rm \
		--volume $(PWD)/tests/testinfra:/tests \
		wpengine/vault-packer:$(VERSION) \
		py.test -v /tests

# ~*~*~*~* Smoke Tasks *~*~*~*~
build-smoke-image:
	docker build -t vault-smokes:$(VERSION) tests/smokes/

smoke-: $(addprefix smoke-, $(ACCOUNTS))

smoke-development: | build-smoke-image
	docker run --rm \
		--volume $(PWD)/artifacts:/artifacts \
		--volume $(PWD)/tests:/workspace/tests \
		--env SMOKE_DOMAIN=vault.wpenginedev.com \
		vault-smokes:$(VERSION)

smoke-corporate: | build-smoke-image
	docker run --rm \
		--volume $(PWD)/artifacts:/artifacts \
		--volume $(PWD)/tests:/workspace/tests \
		--env SMOKE_DOMAIN=vault.wpengine.io \
		vault-smokes:$(VERSION)

# ~*~*~*~* Utility Tasks *~*~*~*~
clean: | ensure-tls-certs-get
	rm -rvf artifacts/*
	find packer \! -name 'variables.json' -a -name '*.json' -print
#	find . -name '.terraform' -type d -exec rm -rfv {} \;

	docker run --rm \
		--volume $(PWD)/terraform/modules/generate-tls-cert:/workspace \
		--volume $(PWD)/artifacts:/artifacts \
		--workdir=/workspace \
		$(TERRAFORM_IMAGE) \
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
		$(TERRAFORM_IMAGE) \
		terraform init

ensure-tls-certs-get: ensure-tls-certs-init
	docker run --rm \
		--volume $(PWD)/terraform/modules/generate-tls-cert:/workspace \
		--workdir=/workspace \
		$(TERRAFORM_IMAGE) \
		terraform get

ensure-tls-certs-apply: ensure-artifacts-dir ensure-tls-certs-get
	@echo "=====> Using private-tls-cert module to ensure certs <====="
	docker run --rm \
		--volume $(PWD)/terraform/modules/generate-tls-cert:/workspace \
		--volume $(PWD)/artifacts:/artifacts \
		--workdir=/workspace \
		$(TERRAFORM_IMAGE) \
		terraform apply \
		-var-file variables.json \
		-var 'private_key_file_path=/artifacts/vault.key.pem' \
		-var 'ca_public_key_file_path=/artifacts/vault.ca.crt.pem' \
		-var 'public_key_file_path=/artifacts/vault.crt.pem' \
		-var owner=$(TLS_OWNER)

packer-yaml-to-json: | lint-packer-template
	@echo
	# Generating JSON version of YAML packer template
	docker run --rm \
		-i \
		--entrypoint="" \
		--workdir=/workspace \
		--volume $(PWD)/packer:/workspace \
		$(YAML_LINTER):latest \
			python /workspace/yaml2json.py vault-consul-ami/vault-consul.yaml
	@echo
	# Successfully converted YAML packer template to JSON

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
		$(TERRAFORM_IMAGE) \
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
		$(TERRAFORM_IMAGE) \
		terraform get .

terraform-validate: $(addprefix terraform-validate-, $(ACCOUNTS))
terraform-validate-%: | terraform-init-%
	echo hello

terraform-plan: $(addprefix terraform-plan-, $(ACCOUNTS))
terraform-plan-%: | terraform-get-%
	docker run --rm \
		--workdir=/workspace \
		--volume $(PWD)/terraform/aws/$(*):/workspace \
		--env GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" \
		--volume $(HOME)/.ssh/github_rsa:/root/.ssh/id_rsa \
		--volume $(HOME)/.ssh/known_hosts:/root/.ssh/known_hosts \
		--env GIT_TRACE=1 \
		--env AWS_ACCESS_KEY_ID \
		--env AWS_SECRET_ACCESS_KEY \
		$(TERRAFORM_IMAGE) \
		terraform plan .

terraform-apply: $(addprefix terraform-apply-, $(ACCOUNTS))
terraform-apply-%: | terraform-plan-%
	docker run --rm \
		--workdir=/workspace \
		--volume $(PWD)/terraform/aws/$(*):/workspace \
		--env GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" \
		--volume $(HOME)/.ssh/github_rsa:/root/.ssh/id_rsa \
		--volume $(HOME)/.ssh/known_hosts:/root/.ssh/known_hosts \
		--env GIT_TRACE=1 \
		--env AWS_ACCESS_KEY_ID \
		--env AWS_SECRET_ACCESS_KEY \
		$(TERRAFORM_IMAGE) \
		terraform apply .

terraform-destroy: $(addprefix terraform-destroy-, $(ACCOUNTS))
terraform-destroy-%: | terraform-get-%
	docker run --rm \
		-it \
		--workdir=/workspace \
		--volume $(PWD)/terraform/aws/$(*):/workspace \
		--env GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" \
		--volume $(HOME)/.ssh/github_rsa:/root/.ssh/id_rsa \
		--volume $(HOME)/.ssh/known_hosts:/root/.ssh/known_hosts \
		--env GIT_TRACE=1 \
		--env AWS_ACCESS_KEY_ID \
		--env AWS_SECRET_ACCESS_KEY \
		$(TERRAFORM_IMAGE) \
		terraform \
		 destroy \
		 -var 'aws_role_arn=arn:aws:iam::844484402121:role/wpengine/robots/TerraformDestroyer' \
		 .
