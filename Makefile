IMAGE := runbook-publisher:0.1.0

.PHONY: build run

build:
	docker build -t $(IMAGE) .

run:
	docker run --rm -u $$(id -u):$$(id -g) -v "$(CURDIR):/workspace" $(IMAGE)
