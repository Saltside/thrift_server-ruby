APP:=thrift_server

.DEFAULT_GOAL:=build

# CircleCI does not support --rm, so if the environment variable has
# value, then don't include --rm.
ifneq ($(shell echo $$CIRCLECI),)
DOCKER_RUN:=docker run -it
else
DOCKER_RUN:=docker run --rm -it
endif

gen-rb/echo_service.rb: echo_service.thrift
	$(DOCKER_RUN) -v $(CURDIR):/data thrift:0.9.2 \
		thrift -o /data --gen rb /data/$<

.PHONY: thrift
thrift: gen-rb/echo_service.rb

tmp/image: Dockerfile lib/thrift_server/version.rb thrift_server.gemspec gen-rb/echo_service.rb
	docker build -t $(APP) .
	mkdir -p $(@D)
	docker inspect -f '{{.Id}}' $(APP) >> $@

.PHONY: build
build: tmp/image

.PHONY: test
test: tmp/image
	$(DOCKER_RUN) -v $(CURDIR):/usr/src/app $(APP) bundle exec rake

.PHONY: test-unit
test-lib: tmp/image
	$(DOCKER_RUN) $(APP) bundle exec rake

.PHONY: test-network
test-network: tmp/image gen-rb/echo_service.rb
	-@docker stop server > /dev/null 2>&1
	-@docker rm -v server > /dev/null 2>&1
	docker run -d --name server $(APP) ruby echo_server.rb
	$(DOCKER_RUN) --link server:server $(APP) ruby echo_client.rb server 9090

.PHONY: test-ci
test-ci: test-lib test-network

.PHONY: clean
clean:
	-docker stop server > /dev/null 2>&1
	-docker rm -v server > /dev/null 2>&1
	@mkdir -p tmp
	@touch tmp/image
	-cat tmp/image | xargs --no-run-if-empty docker rmi
	rm -rf tmp/image
