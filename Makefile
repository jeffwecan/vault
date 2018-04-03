MARKDOWN_LINTER := wpengine/mdl
TERRAFORM_IMAGE := wpengine/terraform
ACCOUNTS        := development corporate

# default is meant to generally map to Jenkinsfile/pipeline for anything other than the master branch
default: lint
lint: markdownlint

# Run markdown analysis tool.
markdownlint:
	@echo
	# Running markdownlint against all markdown files in this project...
	@docker run --rm \
		--volume $(PWD):/workspace \
		${MARKDOWN_LINTER} /workspace
	@echo
	# Successfully linted Markdown.
