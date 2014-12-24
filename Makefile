CURDIR = `pwd`
CONTENTDIR = $(CURDIR)/var_nginx


all: image run

image:
	docker build --rm -t lubot .

run:
	docker run --rm --name lubot -p 3232:3232 -v $(CONTENTDIR):/var/nginx -i --env ETCD_URL="http://127.0.0.1:5001" $(DOCKER_ENV) -t lubot

.PHONY: image run all
