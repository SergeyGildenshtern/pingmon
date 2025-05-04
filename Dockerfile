FROM ruby:3.4.1-alpine

RUN apk add build-base && gem install foreman --no-document

WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN bundle config set --local without rubocop && bundle install

COPY . .

EXPOSE $PORT

CMD foreman start $FORMATION
