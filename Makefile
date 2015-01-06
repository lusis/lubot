CURDIR = `pwd`
CONTENTDIR = $(CURDIR)/var_nginx


all: image run

image:
	docker build --rm -t lubot .

run:
	docker run --rm --name lubot -p 3232:3232 -v $(CONTENTDIR):/var/nginx -i $(DOCKER_ENV) -t lubot

.PHONY: image run all
