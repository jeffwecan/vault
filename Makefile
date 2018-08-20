MARKDOWN_LINTER := wpengine/mdl
TERRAFORM_IMAGE := wpengine/terraform
ACCOUNTS        := development corporate
# used for tagging terraform graphs with a "version"
GIT_HASH        := $(shell git rev-parse --short HEAD)
# override this for terraform modules that require GCP access TODO: or better yet, pass this without needing the filesystem
TERRAFORM_GCP_SERVICE_ACCOUNT ?= $(PWD)/account.json

# default is meant to generally map to Jenkinsfile/pipeline for anything other than the master branch
default: lint
lint: lint-markdown

# Run markdown analysis tool.
lint-markdown:
	@echo
	# Running markdownlint against all markdown files in this project...
	@docker run --rm \
		--volume $(PWD):/workspace \
		${MARKDOWN_LINTER} /workspace
	@echo
	# Successfully linted Markdown.

# Set up some common boilerplate arround running terraform locally using a makefile "define" directive
define run_terraform
	@echo
	# Running "$(2)" for account "$(1)"
	@docker run --rm \
		--workdir=/workspace \
		--volume $(PWD)/terraform/aws/$(1):/workspace \
		--volume $(PWD)/terraform/modules:/modules \
		--volume $(PWD)/artifacts:/artifacts \
		--volume $(HOME)/.ssh/id_rsa_github:/root/.ssh/id_rsa:ro \
		--volume $(HOME)/.ssh/known_hosts:/root/.ssh/known_hosts:ro \
		-e GOOGLE_APPLICATION_CREDENTIALS=/account.json \
		-v $(TERRAFORM_GCP_SERVICE_ACCOUNT):/account.json \
		--env AWS_ACCESS_KEY_ID \
		--env AWS_SECRET_ACCESS_KEY \
		$(TERRAFORM_IMAGE) \
		$(2) .
	@echo
	# Completed "$(2)" for account "$(1)"
endef

terraform-init-: $(addprefix terraform-init-, $(ACCOUNTS))
terraform-init-%:
	$(call run_terraform,$(*),terraform init)

terraform-get-: $(addprefix terraform-get-, $(ACCOUNTS))
terraform-get-%: | terraform-init-%
	$(call run_terraform,$(*),terraform get)

terraform-validate: $(addprefix terraform-validate-, $(ACCOUNTS))
terraform-validate-%: | terraform-init-%
	$(call run_terraform,$(*),terraform validate)

terraform-plan: $(addprefix terraform-plan-, $(ACCOUNTS))
terraform-plan-%: | terraform-get-%
	$(call run_terraform,$(*),terraform plan)

terraform-apply: $(addprefix terraform-apply-, $(ACCOUNTS))
terraform-apply-%: | terraform-plan-%
	$(call run_terraform,$(*),terraform apply)

terraform-destroy: $(addprefix terraform-destroy-, $(ACCOUNTS))
terraform-destroy-%: | terraform-get-%
	$(call run_terraform,$(*),terraform destroy)

terraform-graph: $(addprefix terraform-graph-, $(ACCOUNTS))
terraform-graph-%: | terraform-get-%
	$(call run_terraform,$(*),/bin/bash -c 'terraform graph -module-depth 1 . > /artifacts/$(*)_$(GIT_HASH)_tf.gv')
	cat artifacts/$(*)_$(GIT_HASH)_tf.gv | dot -Tsvg > artifacts/$(*)_$(GIT_HASH)_tf.svg
	rsvg-convert artifacts/$(*)_$(GIT_HASH)_tf.svg > artifacts/$(*)_$(GIT_HASH)_tf.png
	rm -fv artifacts/$(*)_$(GIT_HASH)_tf.svg
