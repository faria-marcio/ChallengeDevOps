SHA = $(shell git rev-parse --short HEAD)
RUN = docker compose run --rm

##TASKS
_awsinit:
	$(RUN) aws configure
.PHONY: _awsinit

_awsinit-sso:
	$(RUN) aws configure sso
.PHONY: _awsinit-sso

init:
	echo ID=$(SHA) > .env
	$(RUN) terraform init
	make dev-workspace
.PHONY: init

dev-workspace:
	$(RUN) terraform workspace select dev
.PHONY: dev-workspace

staging-workspace:
	$(RUN) terraform workspace select staging
.PHONY: staging-workspace

prod-workspace:
	$(RUN) terraform workspace select prod
.PHONY: prod-workspace

plan:
	$(RUN) terraform plan -var-file="dev.tfvars" -out=.terraform-plan 
.PHONY: plan

apply:
	$(RUN) terraform apply .terraform-plan 
.PHONY: apply

build:
	$(RUN) terraform apply -var-file="dev.tfvars" -auto-approve
.PHONY: build

destroy:
	$(RUN) terraform destroy -var-file="dev.tfvars" -auto-approve
.PHONY: destroy

show:
	$(RUN) terraform show
.PHONY: show

all:
	make _awsinit-sso
	make init
	make build
	make plan
	make apply
.PHONY: all
