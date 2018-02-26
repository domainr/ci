# domainr/ci Dockerfile
#
# We work in two steps: as root, then as not-root.
# We use two stages, so that we can --target=rootstage to do other work.
#
# Multi-stage Dockerfile requires Docker 17.05 or higher.

# Note: ARG goes out of scope on the next FROM line, so any ARGs wanted
#       have to be repeated.  Try to avoid wanting them more than once.
#       However, if you can live with the variable in the process environment
#       of images launched from the final image, then ENV is a decent
#       workaround.

ARG GOLANG_BASE_IMAGE=1.10.0-stretch
FROM golang:${GOLANG_BASE_IMAGE} AS rootstage
ARG GOLANG_BASE_IMAGE=1.10.0-stretch
#
# Only for stamping into the labels, and tracking
ARG GOLANG_VERSION=1.10
#
# Dep readme says "It is strongly recommended that you use a released version."
ARG DEP_VERSION=0.4.1
#
ARG RUNTIME_USER=domainr
ARG RUNTIME_UID=1001
ARG RUNTIME_GID=1001
# Persisting this in ENV makes it available to RUN commands in the second stage:
ENV RUNTIME_USER=${RUNTIME_USER}

# need 'zip' for slug build
# need 'nc' for sanity checks in one project; deb netcat-traditional
# need 'git-hub' for GitHub's hub command, for one-off runners using this CI image
#   but link it to the more common name found outside Debian, too

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true; \
	apt-get update \
	&& apt-get -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" upgrade \
	&& apt-get install -q -y --no-install-recommends \
		apt-transport-https \
		software-properties-common \
		netcat-traditional netcat zip \
		git-hub \
	&& ln -s /usr/bin/git-hub /usr/local/bin/hub
# defer removing /var/lib/apt/lists/* until done with apt-get below

# For the trust reduction, see:
#  <https://wiki.debian.org/DebianRepository/UseThirdParty>
#  <https://public-packages.pennock.tech/>
#
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true; \
	echo "Adding docker repositories and installing Docker" \
	&& mkdir -pv /etc/apt/keys /etc/apt/preferences.d \
	&& curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | gpg --dearmor > /etc/apt/keys/docker.gpg \
	&& printf > /etc/apt/preferences.d/docker.pref 'Package: *\nPin: origin download.docker.com\nPin-Priority: 100\n' \
	&& echo \
		"deb [arch=amd64 signed-by=/etc/apt/keys/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")" \
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
RUN chmod -v +x /usr/local/bin/*

WORKDIR /
# We don't use /go because we don't build as root and 777 permissions are daft
RUN rm -rf /go

LABEL maintainer="ops+docker+ci@domainr.com"
LABEL com.domainr.name="Domainr Continuous Integration (root-stage)"
LABEL com.domainr.baseimage="${GOLANG_BASE_IMAGE}"
LABEL com.domainr.versions.go="${GOLANG_VERSION}"
LABEL com.domainr.versions.dep="${DEP_VERSION}"
# These aren't "our runtime" but "runtime we target"
LABEL com.domainr.runtime.username="${RUNTIME_USER}"
LABEL com.domainr.runtime.uid="${RUNTIME_UID}"
LABEL com.domainr.runtime.gid="${RUNTIME_GID}"
LABEL com.domainr.runtime.enabled="false"

# ---------------------8< dropped privileges image >8---------------------

FROM rootstage

# I've checked, and the ENV persisence of an ARG in the first stage makes the
# value available for WORKDIR/USER directives, etc.

WORKDIR /home/${RUNTIME_USER}
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

LABEL com.domainr.name="Domainr Continuous Integration"
LABEL com.domainr.runtime.enabled="true"
