VERSION         	:= $(shell git describe --tags --always)
IMAGE_TAG			?= $(VERSION)
AMI_NAME			:= "vault-consul-ubuntu-$(IMAGE_TAG)"
SERVER_CM_TAG		:= "v3.31"
TLS_OWNER			?= "root"

MARKDOWN_LINTER 	:= wpengine/mdl
YAML_LINTER			:= wpengine/yamllint
TERRAFORM_IMAGE		:= wpengine/terraform
PACKER_IMAGE		:= wpengine/packer
ANSIBLE_TEST_IMAGE	:= wpengine/ansible
MOLECULE_TEST_IMAGE	:= jeffreymhogan/ansible:molecule-16.04
ACCOUNTS			:= development production
ROLES_TO_TEST		:= td-agent
# ami-cleanup,common-packages,consul,ldap-client,nginx,security,supervisor

# default is meant to generally map to Jenkinsfile/pipeline for anything other than the master branch
default: lint test terraform-plan

# all is meant to generally map to Jenkinsfile/pipeline for the master branch (minus deploying to prod ;P)
all: lint test packer-build-ami terraform-apply-development smoke-development

lint: markdownlint ansible-lint yamllint terraform-validate
test: molecule-test

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
		/bin/bash -c '/usr/bin/find /workspace -maxdepth 1 -name '*.yml' -print0 | /usr/bin/xargs -0 ansible-lint -p -v'

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

# ~*~*~*~* Test Tasks *~*~*~*~ # $(VERSION)
infratest-docker-image: | packer-build-image
	docker run --rm \
	--volume $(PWD)/artifacts/infratest:/artifacts/infratest:rw \
	--volume $(PWD)/tests/testinfra:/tests \
	wpengine/vault-packer:latest \
	/bin/bash -c "service supervisord start && py.test -v /tests --junit-xml /artifacts/infratest/docker_image.xml"

molecule-test: | ensure-artifacts-dir ensure-tls-certs-apply
	#tests/ansible/run_all_molecule_tests.sh $(ROLES_TO_TEST)

	docker run --rm \
		--name vault_molecule_test_runner \
		--volume /var/run/docker.sock:/var/run/docker.sock \
		--volume $(PWD):/workspace \
		--volume $(PWD)/tests/ansible:/tests \
		--volume $(PWD)/tests/ansible/ansible.cfg:/etc/ansible/ansible.cfg \
		--workdir=/workspace \
		--env WPE_DEPLOY_LOG_DIR=/workspace/artifacts/ansible \
		--env JUNIT_OUTPUT_DIR=/workspace/artifacts/ansible \
		$(MOLECULE_TEST_IMAGE) \
		/tests/run_all_molecule_tests.sh

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
	mkdir -p artifacts/molecule
	mkdir -p artifacts/ansible

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

packer-yaml-to-json:
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

# ~*~*~*~* Terraform Tasks *~*~*~*~

define run_terraform
	docker run --rm \
		--workdir=/workspace \
		--volume $(PWD)/terraform/aws/$(1):/workspace \
		--volume $(PWD)/artifacts/$(1)/iam:/artifacts \
		--volume $(HOME)/.ssh/id_rsa_github:/root/.ssh/id_rsa:ro \
		--volume $(HOME)/.ssh/known_hosts:/root/.ssh/known_hosts \
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
	$(call run_terraform,$(*),/bin/bash -c 'terraform graph . > /artifacts/$(*)_tf.gv')

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
	# TODO add packer profile to jenkins nodes IAM instance role
