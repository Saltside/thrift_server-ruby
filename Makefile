APP:=thrift_server

.DEFAULT_GOAL:=build

DOCKER_RUN:=docker run --rm -it

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
test-network: tmp/image gen-rb/echo_service.rb clean-containers
	docker run -d --name threaded_server $(APP) ruby echo_server.rb --threaded
	docker run -d --name thread_pool_server $(APP) ruby echo_server.rb --thread-pool
	$(DOCKER_RUN) --link threaded_server:server $(APP) ruby echo_client.rb server 9090
	$(DOCKER_RUN) --link thread_pool_server:server $(APP) ruby echo_client.rb server 9090

.PHONY: test-ci
test-ci: test-lib test-network

.PHONY: clean-containers
clean-containers:
	-@docker stop thread_pool_server threaded_server > /dev/null 2>&1
	-@docker rm -v thread_pool_server threaded_server > /dev/null 2>&1

.PHONY: clean
clean: clean-containers
	@mkdir -p tmp
	@touch tmp/image
	-cat tmp/image | xargs --no-run-if-empty docker rmi
	rm -rf tmp/image
