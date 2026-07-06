SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

.PHONY: help install full-install packages apply doctor system greetd

help:
	@printf '%s\n' \
		'Targets:' \
		'  make install       Install packages, apply configs, and run system tuning' \
		'  make full-install  Install everything plus greetd/regreet setup' \
		'  make packages      Install package manifests only' \
		'  make apply         Sync repo configs into ~/.config and ~/Pictures' \
		'  make doctor        Check that the setup is wired correctly' \
		'  make system        Re-run system tuning' \
		'  make greetd        Configure greetd/regreet as the login manager'

install:
	./scripts/install.sh

full-install:
	WITH_GREETD=1 ./scripts/install.sh

packages:
	./scripts/install.sh --packages-only --skip-system

apply:
	./scripts/apply.sh

doctor:
	./scripts/doctor.sh

system:
	sudo ./scripts/system/configure-system-performance.sh "$${USER}"

greetd:
	sudo ./scripts/system/configure-regreet.sh "$${USER}"
