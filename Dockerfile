# Base image described here: https://devcenter.heroku.com/articles/stack-packages
FROM heroku/heroku:16-build

# Install Mercurial
RUN apt-get update && apt-get install -y --no-install-recommends \
		mercurial \
	&& rm -rf /var/lib/apt/lists/*

# Install Go
ENV GOLANG_VERSION 1.8.1
ENV GOLANG_DOWNLOAD_URL https://golang.org/dl/go$GOLANG_VERSION.linux-amd64.tar.gz
ENV GOLANG_DOWNLOAD_SHA256 a579ab19d5237e263254f1eac5352efcf1d70b9dacadb6d6bb12b0911ede8994

RUN curl -fsSL "$GOLANG_DOWNLOAD_URL" -o golang.tar.gz \
	&& echo "$GOLANG_DOWNLOAD_SHA256  golang.tar.gz" | sha256sum -c - \
	&& tar -C /usr/local -xzf golang.tar.gz \
	&& rm golang.tar.gz

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
WORKDIR $GOPATH

# Install go-junit-report
RUN go get -v -u github.com/jstemmer/go-junit-report
