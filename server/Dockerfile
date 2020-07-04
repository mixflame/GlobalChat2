FROM ruby
RUN gem install gserver

RUN mkdir /app /app/data

WORKDIR /app
COPY server.rb /app


VOLUME /app/data
EXPOSE 9994
CMD ["ruby", "server.rb"]