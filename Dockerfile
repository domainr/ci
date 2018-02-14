ARG GOLANG_BASE_IMAGE=1.9.4-stretch
FROM golang:${GOLANG_BASE_IMAGE}
ARG GOLANG_VERSION=1.9.4
#
# While the main key is: ARG DOCKER_REPO_KEY=9DC858229FC7DD38854AE2D88D81803C0EBFCD88
# the apt repo signed-by constraint checks the _subkey_, so:
ARG DOCKER_REPO_KEY=D3306A018370199E527AE7997EA0A9C3F273FCD8
#
# Dep readme says "It is strongly recommended that you use a released version."
ARG DEP_VERSION=0.4.1
#
ARG RUNTIME_USER=domainr
ARG RUNTIME_UID=1001
ARG RUNTIME_GID=1001
ENV RUNTIME_USER=${RUNTIME_USER}

# need 'zip' for slug build
# need 'nc' for sanity checks in one project; deb netcat-traditional
# need 'git-hub' for GitHub's hub command, for one-off runners using this CI image

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true; \
	apt-get update \
	&& apt-get -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" upgrade \
	&& apt-get install -q -y --no-install-recommends \
		apt-transport-https \
		software-properties-common \
		netcat-traditional netcat zip \
		git-hub \
	&& true
# defer removing /var/lib/apt/lists/* until done with apt-get below

# nb: no way to mark imported key as "only for use where explicitly in signed-by", alas.
#
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true; \
	echo "Adding docker repositories and installing Docker" \
	&& curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | apt-key add - \
	&& echo \
		"deb [arch=amd64 signed-by=${DOCKER_REPO_KEY}] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")" \
		$(lsb_release -cs) \
		stable \
		> /etc/apt/sources.list.d/docker.list \
	&& apt-get update \
	&& apt-get -q -y install docker-ce \
	&& rm -rf /var/lib/apt/lists/*

RUN groupadd -g ${RUNTIME_GID} ${RUNTIME_USER} && \
    useradd -p '*' -u ${RUNTIME_UID} -g ${RUNTIME_USER} -m ${RUNTIME_USER}

# Install Heroku
RUN cd /tmp \
	&& curl -fsSL "https://cli-assets.heroku.com/heroku-cli/channels/stable/heroku-cli-linux-x64.tar.gz" -o heroku.tar.gz \
	&& tar -zxf heroku.tar.gz \
	&& mv heroku-cli-*-linux-x64 /usr/local/lib/heroku \
	&& ln -s /usr/local/lib/heroku/bin/heroku /usr/local/bin/heroku \
	&& rm heroku.tar.gz \
	&& heroku version

# Install Dep
# There are no signatures, only a checksum to download from the same place, which buys us nothing security-wise, but does
# let us know about corruption.  We'll check it, most easily by downloading to same name that was signed.
RUN cd /tmp && mkdir release \
	&& curl -fsSL "https://github.com/golang/dep/releases/download/v${DEP_VERSION}/dep-linux-amd64" -o release/dep-linux-amd64 \
	&& have="$(sha256sum release/dep-linux-amd64)" \
	&& want="$(curl -fsSL "https://github.com/golang/dep/releases/download/v${DEP_VERSION}/dep-linux-amd64.sha256")" \
	&& [ ".$have" = ".$want" ] \
	&& echo "checksum match: $have" \
	&& chmod 0755 release/dep-linux-amd64 \
	&& mv release/dep-linux-amd64 /usr/local/bin/dep \
	&& dep version

# Copy in local scripts
COPY cmd/* /usr/local/bin/
RUN chmod +x /usr/local/bin/*

WORKDIR /home/${RUNTIME_USER}
# We don't use /go because we don't build as root and 777 permissions are daft
RUN rm -rf /go

# nb: we don't have a password and have not set up sudo, so no way back at this
# point.  Do we _want_ to still have root?
USER ${RUNTIME_USER}
# Want to just remove the Go image's GOPATH setting but while we can replace
# ENV in Docker, we can't unset.  So suck it up and just set it, old style.
ENV GOPATH=/home/${RUNTIME_USER}/go
ENV PATH=${GOPATH}/bin:/usr/local/go/bin:$PATH

# Install our Go tools
RUN go version && \
	go get -u -v github.com/jstemmer/go-junit-report && \
	go get -u -v github.com/nbio/slugger && \
	go get -u -v github.com/nbio/cart && \
	true
