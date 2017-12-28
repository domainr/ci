ARG CIRCLE_GOLANG_VERSION=1.9.2
FROM circleci/golang:${CIRCLE_GOLANG_VERSION}

# Install Heroku
RUN cd /tmp \
	&& curl -fsSL "https://cli-assets.heroku.com/heroku-cli/channels/stable/heroku-cli-linux-x64.tar.gz" -o heroku.tar.gz \
	&& tar -zxvf heroku.tar.gz \
	&& sudo mv heroku-cli-*-linux-x64 /usr/local/lib/heroku \
	&& sudo ln -s /usr/local/lib/heroku/bin/heroku /usr/local/bin/heroku \
	&& rm heroku.tar.gz

# Install our Go tools
RUN go get -u -v github.com/jstemmer/go-junit-report
RUN go get -u -v github.com/nbio/slugger
RUN go get -u -v github.com/nbio/cart

