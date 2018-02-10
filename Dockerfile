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
ARG NODE_VERSION=9.5.0
ARG YARN_VERSION=1.3.2
#
ARG RUNTIME_USER=domainr
ARG RUNTIME_UID=1001
ARG RUNTIME_GID=1001
ENV RUNTIME_USER=${RUNTIME_USER}

# We import PGP keys from local disk instead of depending upon the keyserver swamps
# Run fetch-signing-keys to go fishing, then commit the resulting PGP-keys.txt file.
COPY PGP-keys.txt .
RUN gpg --import PGP-keys.txt && rm -v PGP-keys.txt && gpg --batch --list-keys </dev/null

# need 'zip' for slug build
# need 'nc' for sanity checks in one project; deb netcat-traditional
#
# We also spin up instances for debugging builds, so needed for my sanity:
#   bind9utils chrpath dnsutils ed gdb-minimal lsof net-tools pcregrep procps rsync sysstat tcpdump vim-nox

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true; \
	apt-get update \
	&& apt-get -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" upgrade \
	&& apt-get install -q -y --no-install-recommends \
		apt-transport-https \
		software-properties-common \
		netcat-traditional netcat zip \
		bind9utils chrpath dnsutils ed gdb-minimal lsof net-tools pcregrep procps rsync sysstat tcpdump vim-nox \
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

# Install Node
# This is mostly from nodejs/docker-node but I cleaned up various things
# (checksum verifications, curl, gpg invocation, etc)
# We add _showing_ a computed checksum so that it's part of the build output,
# which is logged and retained; that way we get not just "it matched something
# which we thought was good" but the actual value.
RUN cd /tmp && ARCH= \
	&& dpkgArch="$(dpkg --print-architecture)" \
	&& case "${dpkgArch##*-}" in \
	amd64) ARCH='x64';; \
	ppc64el) ARCH='ppc64le';; \
	s390x) ARCH='s390x';; \
	arm64) ARCH='arm64';; \
	armhf) ARCH='armv7l';; \
	i386) ARCH='x86';; \
	*) echo "unsupported architecture"; exit 1 ;; \
	esac \
	&& TARBALL="node-v${NODE_VERSION}-linux-${ARCH}.tar.xz" SRCURLDIR="https://nodejs.org/dist/v${NODE_VERSION}" \
	&& curl -fsSL --remote-name-all --compressed "${SRCURLDIR}/${TARBALL}" "${SRCURLDIR}/SHASUMS256.txt.asc" \
	&& gpg </dev/null --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
	&& sha256sum --ignore-missing -c SHASUMS256.txt \
	&& sha256sum >&2 "${TARBALL}" \
	&& tar -xJf "${TARBALL}" -C /usr/local --strip-components=1 --no-same-owner \
	&& rm "${TARBALL}" SHASUMS256.txt.asc SHASUMS256.txt \
	&& ln -s /usr/local/bin/node /usr/local/bin/nodejs

# Install Yarn
# Commands from same source as Node, same sorts of changes.
RUN cd /tmp \
	&& TARBALL="yarn-v${YARN_VERSION}.tar.gz" SRCURLDIR="https://yarnpkg.com/downloads/${YARN_VERSION}" \
	&& curl -fsSL --remote-name-all --compressed "${SRCURLDIR}/${TARBALL}" "${SRCURLDIR}/${TARBALL}.asc" \
	&& gpg </dev/null --batch --verify "${TARBALL}.asc" "${TARBALL}" \
	&& sha256sum >&2 "${TARBALL}" \
	&& mkdir -pv /opt/yarn \
	&& tar -xzf "${TARBALL}" -C /opt/yarn --strip-components=1 \
	&& ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn \
	&& ln -s /opt/yarn/bin/yarn /usr/local/bin/yarnpkg \
	&& rm -fv "${TARBALL}.asc" "${TARBALL}"

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

# Unlike every other instruction, LABELs coalesce so we only introduce one layer here.
# The MAINTAINER instruction is deprecated.
LABEL maintainer="ping@domainr.com"
LABEL io.domainr.baseimage="golang:${GOLANG_BASE_IMAGE}"
LABEL io.domainr.versions.go="${GOLANG_VERSION}"
LABEL io.domainr.versions.dep="${DEP_VERSION}"
LABEL io.domainr.versions.node="${NODE_VERSION}"
LABEL io.domainr.versions.yarn="${YARN_VERSION}"
LABEL io.domainr.runtimeuser="${RUNTIME_USER}"
