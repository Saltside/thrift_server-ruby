FROM ruby:2.1

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

ADD Gemfile /usr/src/app/Gemfile
ADD lib/thrift_server/version.rb /usr/src/app/lib/thrift_server/version.rb
ADD thrift_server.gemspec /usr/src/app/thrift_server.gemspec
ADD Gemfile.lock /usr/src/app/Gemfile.lock
ADD vendor /usr/src/app/vendor
RUN bundle install --local -j $(nproc)

CMD [ "bundle", "console" ]
