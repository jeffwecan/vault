VERSION         	:= $(shell git describe --tags --always)
IMAGE_TAG			?= $(VERSION)

MARKDOWN_LINTER 	:= wpengine/mdl
YAML_LINTER			:= wpengine/yamllint
TERRAFORM_IMAGE		:= wpengine/terraform
PACKER_IMAGE		:= wpengine/packer
ANSIBLE_TEST_IMAGE	:= wpengine/ansible
MOLECULE_TEST_IMAGE	:= jeffreymhogan/ansible:molecule-16.04
ACCOUNTS			:= development production
# we can skip the nginx and supervisor roles for now since other roles have them as dependencies
ROLES_TO_TEST		:= ami-cleanup common-packages consul ldap-client security td-agent ufw-firewall vault zabbix-agent

# override this for things
TERRAFORM_GCP_SERVICE_ACCOUNT ?= /tmp/account.json


# default is meant to generally map to Jenkinsfile/pipeline for anything other than the master branch
default: lint test terraform-plan

# all is meant to generally map to Jenkinsfile/pipeline for the master branch (minus deploying to prod ;P)
all: lint test packer-build-ami terraform-apply-development smoke-development

lint: markdownlint molecule-lint lint-packer-template terraform-validate
test: molecule-test

# ~*~*~*~* Linter Tasks *~*~*~*~
# Run markdown analysis tool.
markdownlint:
	@echo
	# Running markdownlint against all markdown files in this project...
	@docker run --rm \
		--volume $(PWD):/workspace \
		${MARKDOWN_LINTER} /workspace
	@echo
	# Successfully linted Markdown.

lint-packer-template:
	@echo
	# Running yamllint against packer template
	@docker run --rm \
		--volume $(PWD)/packer:/workspace \
		$(YAML_LINTER):latest \
			/workspace
	@echo
	# Successfully linted yaml.

# ~*~*~*~* Test Tasks *~*~*~*~ # $(VERSION)
define run_molecule
	@echo
	# Running molecule image for role $(2) with command: $(1)
	@docker run --rm \
		--name $(2)_molecule_test_runner_$(IMAGE_TAG) \
		--volume /var/run/docker.sock:/var/run/docker.sock \
		--volume $(PWD):/workspace \
		--volume $(PWD)/tests/ansible:/tests \
		--volume $(PWD)/tests/ansible/ansible.cfg:/etc/ansible/ansible.cfg \
		--workdir=/workspace \
		$(MOLECULE_TEST_IMAGE) \
			$(1)
	@echo
	# Successfully molecule'd role $(2) with command: $(1)
endef

infratest-docker-image: | packer-build-image
	docker run --rm \
	--volume $(PWD)/artifacts/infratest:/artifacts/infratest:rw \
	--volume $(PWD)/tests/testinfra:/tests \
	wpengine/vault-packer:latest \
	/bin/bash -c "service supervisord start && py.test -v /tests --junit-xml /artifacts/infratest/docker_image.xml"

molecule-tests: | ensure-artifacts-dir ensure-tls-certs-apply
	$(call run_molecule,/tests/run_all_molecule_tests.sh)

pull-molecule-image:
	docker pull $(MOLECULE_TEST_IMAGE)

molecule-test: $(addprefix molecule-test-, $(ROLES_TO_TEST))
molecule-test-%:
	$(call run_molecule,/bin/bash -c "/tests/run_molecule_tests.sh $(*)",$(*))

molecule-lint: pull-molecule-image $(addprefix molecule-lint-, $(ROLES_TO_TEST))
molecule-lint-%:
	$(call run_molecule,/bin/bash -c "/tests/run_molecule_lint.sh $(*)",$(*))

molecule-destroy: pull-molecule-image $(addprefix molecule-destroy-, $(ROLES_TO_TEST))
molecule-destroy-%:
	@$(call run_molecule,/bin/bash -c "/tests/run_molecule_destroy.sh $(*)",$(*))

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

smoke-production: | build-smoke-image
	docker run --rm \
		--volume $(PWD)/artifacts:/artifacts \
		--volume $(PWD)/tests:/workspace/tests \
		--env SMOKE_DOMAIN=vault.wpengine.io \
		vault-smokes:$(VERSION)

# ~*~*~*~* Utility Tasks *~*~*~*~
clean: #| ensure-tls-certs-get
	rm -rvf artifacts/*
	find packer \! -name 'variables.json' -a -name '*.json' -print

	@docker run --rm \
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
	@mkdir -p artifacts/molecule
	@mkdir -p artifacts/ansible

ensure-tls-certs-init:
	@echo
	# Using private-tls-cert module to ensure certs
	@docker run --rm \
		--volume $(PWD)/terraform/modules/generate-tls-cert:/workspace \
		--workdir=/workspace \
		$(TERRAFORM_IMAGE) \
		/bin/bash -c 'terraform init &>/dev/null'

ensure-tls-certs-get: ensure-tls-certs-init
	@docker run --rm \
		--volume $(PWD)/terraform/modules/generate-tls-cert:/workspace \
		--workdir=/workspace \
		$(TERRAFORM_IMAGE) \
		/bin/bash -c 'terraform get &>/dev/null'

ensure-tls-certs-apply: ensure-artifacts-dir ensure-tls-certs-get
	@docker run --rm \
		--volume $(PWD)/terraform/modules/generate-tls-cert:/workspace \
		--volume $(PWD)/artifacts:/artifacts \
		--workdir=/workspace \
		$(TERRAFORM_IMAGE) \
		/bin/bash -c "terraform apply \
		-var-file variables.json \
		-var 'private_key_file_path=/artifacts/vault.key.pem' \
		-var 'ca_public_key_file_path=/artifacts/vault.ca.crt.pem' \
		-var 'public_key_file_path=/artifacts/vault.crt.pem' &>/dev/null"

packer-yaml-to-json:
	@echo
	# Generating JSON version of YAML packer template
	@docker run --rm \
		-i \
		--entrypoint="" \
		--workdir=/workspace \
		--volume $(PWD)/packer:/workspace \
		$(YAML_LINTER):latest \
			python /workspace/yaml2json.py vault-consul-ami/vault-consul.yaml
	@echo
	# Successfully converted YAML packer template to JSON

# ~*~*~*~* Terraform Tasks *~*~*~*~
define run_terraform
	docker run --rm \
		--workdir=/workspace \
		--volume $(PWD)/terraform/aws/$(1):/workspace \
		--volume $(PWD)/artifacts:/artifacts \
		--volume $(HOME)/.ssh/id_rsa_github:/root/.ssh/id_rsa:ro \
		--volume $(HOME)/.ssh/known_hosts:/root/.ssh/known_hosts \
		-e GOOGLE_APPLICATION_CREDENTIALS=/account.json \
		-v $(TERRAFORM_GCP_SERVICE_ACCOUNT):/account.json \
		--env GIT_TRACE=1 \
		--env AWS_ACCESS_KEY_ID \
		--env AWS_SECRET_ACCESS_KEY \
		$(TERRAFORM_IMAGE) \
		$(2)
endef

terraform-init-: $(addprefix terraform-init-, $(ACCOUNTS))
terraform-init-%: | ensure-artifacts-dir
	$(call run_terraform,$(*),terraform init .)

terraform-get-: $(addprefix terraform-get-, $(ACCOUNTS))
terraform-get-%: | terraform-init-%
	$(call run_terraform,$(*),terraform get .)

terraform-validate: $(addprefix terraform-validate-, $(ACCOUNTS))
terraform-validate-%: | terraform-init-% # need to be able to run this in a jenkins shared var maybe... see: https://jenkins.wpengine.io/job/WPEngineGitHubRepos/job/vault-package/job/terraform_vault/93/console
	$(call run_terraform,$(*),terraform validate .)

terraform-plan: $(addprefix terraform-plan-, $(ACCOUNTS))
terraform-plan-%: | terraform-get-%
	$(call run_terraform,$(*),terraform plan .)

terraform-apply: $(addprefix terraform-apply-, $(ACCOUNTS))
terraform-apply-%: | terraform-plan-%
	$(call run_terraform,$(*),terraform apply .)

terraform-destroy: $(addprefix terraform-destroy-, $(ACCOUNTS))
terraform-destroy-development: | terraform-get-development
	$(call run_terraform,$(*),terraform destroy -var 'aws_role_arn=arn:aws:iam::844484402121:role/wpengine/robots/TerraformDestroyer' .)

terraform-destroy-production: | terraform-get-production
	$(call run_terraform,$(*),terraform destroy -var 'aws_role_arn=arn:aws:iam::844484402121:role/wpengine/robots/TerraformDestroyer' .)

terraform-graph: $(addprefix terraform-graph-, $(ACCOUNTS))
terraform-graph-%: | terraform-get-%
	$(call run_terraform,$(*),/bin/bash -c 'terraform graph -module-depth 1 . > /artifacts/$(*)_$(IMAGE_TAG)_tf.gv')

# ~*~*~*~* Packer Tasks *~*~*~*~

packer-build-image: | packer-yaml-to-json ensure-tls-certs-apply
	docker run --rm \
		--volume /var/run/docker.sock:/var/run/docker.sock \
		--volume $(PWD):/workspace \
		--volume $(PWD)/artifacts:/artifacts \
		--workdir=/workspace \
		$(PACKER_IMAGE):latest \
		build \
			-except=vault-ubuntu-16.04-ami \
			-var version=$(IMAGE_TAG) \
			-var-file packer/vault-consul-ami/variables.json \
			-var 'tls_private_key_path=artifacts/vault.key.pem' \
			-var 'ca_public_key_path=artifacts/vault.ca.crt.pem' \
			-var 'tls_public_key_path=artifacts/vault.crt.pem' \
			-var 'test_image_name=$(ANSIBLE_TEST_IMAGE)' \
			-var 'ansible_extra_arguments=-v, -e vault_supervisor_cmd_flags=-dev, -e nginx_dhparam_bit=256, --skip-tags=bootstrap' \
			packer/vault-consul-ami/vault-consul.json

packer-build-ami: | packer-yaml-to-json ensure-tls-certs-apply
	docker run --rm \
		--volume $(PWD):/workspace \
		--volume $(PWD)/artifacts:/artifacts \
		--workdir=/workspace \
		--env AWS_ACCESS_KEY_ID \
		--env AWS_SECRET_ACCESS_KEY \
		$(PACKER_IMAGE):latest \
			build \
			-except=vault-ubuntu-16.04-docker \
			-var version=$(IMAGE_TAG) \
			-var-file packer/vault-consul-ami/variables.json \
			-var 'tls_private_key_path=/artifacts/vault.key.pem' \
			-var 'ca_public_key_path=/artifacts/vault.ca.crt.pem' \
			-var 'tls_public_key_path=/artifacts/vault.crt.pem' \
			-var 'ansible_extra_arguments=-e vault_supervisor_cmd_flags=-dev' \
			packer/vault-consul-ami/vault-consul.json

packer-debug-ami: | packer-yaml-to-json ensure-tls-certs-apply
	docker run --rm \
		-it \
		--volume $(PWD):/workspace \
		--volume $(PWD)/artifacts:/artifacts \
		--workdir=/workspace \
		--env AWS_ACCESS_KEY_ID \
		--env AWS_SECRET_ACCESS_KEY \
		$(PACKER_IMAGE):latest \
			build \
			-except=vault-ubuntu-16.04-docker \
			-var version=$(IMAGE_TAG) \
			-var-file packer/vault-consul-ami/variables.json \
			-var 'tls_private_key_path=/artifacts/vault.key.pem' \
			-var 'ca_public_key_path=/artifacts/vault.ca.crt.pem' \
			-var 'tls_public_key_path=/artifacts/vault.crt.pem' \
			-var 'ansible_extra_arguments=-e vault_supervisor_cmd_flags=-dev' \
			-debug \
			packer/vault-consul-ami/vault-consul.json
	# TODO add packer profile to jenkins nodes IAM instance role debug mode for locally-initiaited troubleshooting?
