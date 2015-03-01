FROM ruby:2.1

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

ADD Gemfile /usr/src/app/Gemfile
ADD lib/thrift_server/version.rb /usr/src/app/lib/thrift_server/version.rb
ADD thrift_server.gemspec /usr/src/app/thrift_server.gemspec

RUN bundle install

ADD . /usr/src/app

CMD [ "bundle", "console" ]
