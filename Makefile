APP:=thrift_server

.DEFAULT_GOAL:=build

APP_RUN:=docker run --rm -t -v $(CURDIR):/usr/src/app $(APP)

Gemfile.lock: Gemfile thrift_server.gemspec
	docker run --rm -t -v $(CURDIR):/data -e BUNDLE_GEMFILE=/data/Gemfile ruby:2.1 \
		bundle package
	touch $@

gen-rb/echo_service.rb: echo_service.thrift
	docker run --rm -t -v $(CURDIR):/data registry.platform.saltside.io/platform/thrift:0.9.2 \
		-o /data --gen rb /data/$<

.PHONY: thrift
thrift: gen-rb/echo_service.rb

tmp/image: Dockerfile Gemfile.lock lib/thrift_server/version.rb thrift_server.gemspec
	docker build -t $(APP) .
	mkdir -p $(@D)
	docker inspect -f '{{.Id}}' $(APP) >> $@

.PHONY: build
build: tmp/image

.PHONY: test-unit
test-unit: tmp/image
	$(APP_RUN) bundle exec rake

.PHONY: test-network
test-network: tmp/image
	-@docker stop server > /dev/null 2>&1
	-@docker rm -v server > /dev/null 2>&1
	docker run -d --name server -v $(CURDIR):/usr/src/app $(APP) ruby echo_server.rb
	docker run --rm -t -v $(CURDIR):/usr/src/app --link server:server $(APP) ruby echo_client.rb server 9090

.PHONY: test-ci
test-ci: test-unit test-network

.PHONY: clean
clean:
	-docker stop server > /dev/null 2>&1
	-docker rm -v server > /dev/null 2>&1
	@mkdir -p tmp
	@touch tmp/image
	cat tmp/image | xargs --no-run-if-empty docker rmi
	rm -rf tmp/image
