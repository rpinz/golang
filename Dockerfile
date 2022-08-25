# syntax=docker/dockerfile:1

ARG OSVENDOR=ubuntu
ARG OSVERSION=bionic
ARG GOVERSION=1.19

FROM $OSVENDOR:$OSVERSION

ARG GOVERSION

ENV GOLANG_VERSION $GOVERSION
ENV GOPATH /go

ARG DEBIAN_FRONTEND=noninteractive
ARG DEBCONF_NONINTERACTIVE_SEEN=true
ENV TZ=Etc/UTC
RUN ln -snf "/usr/share/zoneinfo/$TZ" "/etc/localtime" \
 && echo "$TZ" > /etc/timezone
# from buildpack-deps-curl
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		curl \
		netbase \
		wget \
# https://bugs.debian.org/929417
		tzdata \
	    $( \
	        if ! command -v gpg > /dev/null; then \
			        echo "gnupg"; \
			        echo "dirmngr"; \
	        fi \
	    ) \
	    \
# from buildpack-deps-curl-scm
# procps is very common in build systems, and is a reasonably small package
		git \
		mercurial \
		openssh-client \
		subversion \
		\
		procps \
		\
# from buildpack-deps
		autoconf \
		automake \
		build-essential \
		bzip2 \
		dpkg-dev \
		file \
		g++ \
		gcc \
		imagemagick \
		libbz2-dev \
		libc6-dev \
		libcurl4-openssl-dev \
		libdb-dev \
		libevent-dev \
		libffi-dev \
		libgdbm-dev \
		libglib2.0-dev \
		libgmp-dev \
		libjpeg-dev \
		libkrb5-dev \
		liblzma-dev \
		libmagickcore-dev \
		libmagickwand-dev \
		libmaxminddb-dev \
		libncurses5-dev \
		libncursesw5-dev \
		libpng-dev \
		libpq-dev \
		libreadline-dev \
		libsqlite3-dev \
		libssl-dev \
		libtool \
		libwebp-dev \
		libxml2-dev \
		libxslt-dev \
		libyaml-dev \
		make \
		patch \
		unzip \
		xz-utils \
		zlib1g-dev \
# https://lists.debian.org/debian-devel-announce/2016/09/msg00000.html
		$( \
# if we use just "apt-cache show" here, it returns zero because "can't select versions from package 'libmysqlclient-dev' as it is purely virtual", hence the pipe to grep
			if apt-cache show "default-libmysqlclient-dev" 2>/dev/null | grep -q "^version:"; then \
				echo "default-libmysqlclient-dev"; \
			else \
				echo "libmysqlclient-dev"; \
			fi \
		) \
		\
# from buildpack-deps golang
# install cgo-related dependencies
		g++ \
		gcc \
		libc6-dev \
		make \
		pkg-config \
	; \
	rm -rf /var/lib/apt/lists/*
RUN set -eux; \
	arch="$(dpkg --print-architecture)"; arch="${arch##*-}"; \
	url=; \
	case "$arch" in \
		"amd64") \
			url="https://dl.google.com/go/go$GOLANG_VERSION.linux-amd64.tar.gz"; \
			sha256="464b6b66591f6cf055bc5df90a9750bf5fbc9d038722bb84a9d56a2bea974be6"; \
			;; \
		"armel") \
			export GOARCH="arm" GOARM="5" GOOS="linux"; \
			;; \
		"armhf") \
			url="https://dl.google.com/go/go$GOLANG_VERSION.linux-armv6l.tar.gz"; \
			sha256="25197c7d70c6bf2b34d7d7c29a2ff92ba1c393f0fb395218f1147aac2948fb93"; \
			;; \
		"arm64") \
			url="https://dl.google.com/go/go$GOLANG_VERSION.linux-arm64.tar.gz"; \
			sha256="efa97fac9574fc6ef6c9ff3e3758fb85f1439b046573bf434cccb5e012bd00c8"; \
			;; \
		"i386") \
			url="https://dl.google.com/go/go$GOLANG_VERSION.linux-386.tar.gz"; \
			sha256="6f721fa3e8f823827b875b73579d8ceadd9053ad1db8eaa2393c084865fb4873"; \
			;; \
		"mips64el") \
			export GOARCH="mips64le" GOOS="linux"; \
			;; \
		"ppc64el") \
			url="https://dl.google.com/go/go$GOLANG_VERSION.linux-ppc64le.tar.gz"; \
			sha256="92bf5aa598a01b279d03847c32788a3a7e0a247a029dedb7c759811c2a4241fc"; \
			;; \
		"s390x") \
			url="https://dl.google.com/go/go$GOLANG_VERSION.linux-s390x.tar.gz"; \
			sha256="58723eb8e3c7b9e8f5e97b2d38ace8fd62d9e5423eaa6cdb7ffe5f881cb11875"; \
			;; \
		*) echo >&2 "error: unsupported architecture "$arch" (likely packaging update needed)"; exit 1 ;; \
	esac; \
	build=; \
	if [ -z "$url" ]; then \
# https://github.com/golang/go/issues/38536#issuecomment-616897960
		build=1; \
		url="https://dl.google.com/go/go$GOLANG_VERSION.src.tar.gz"; \
		sha256="9419cc70dc5a2523f29a77053cafff658ed21ef3561d9b6b020280ebceab28b9"; \
		echo >&2; \
		echo >&2 "warning: current architecture ($arch) does not have a compatible Go binary release; will be building from source"; \
		echo >&2; \
	fi; \
	\
	wget -O go.tgz.asc "$url.asc"; \
	wget -O go.tgz "$url" --progress=dot:giga; \
	echo "$sha256 *go.tgz" | sha256sum -c -; \
	\
# https://github.com/golang/go/issues/14739#issuecomment-324767697
	GNUPGHOME="$(mktemp -d)"; export GNUPGHOME; \
# https://www.google.com/linuxrepositories/
	gpg --batch --keyserver "hkp://keyserver.ubuntu.com:80" --recv-keys "EB4C 1BFD 4F04 2F6D DDCC  EC91 7721 F63B D38B 4796"; \
# let's also fetch the specific subkey of that key explicitly that we expect "go.tgz.asc" to be signed by, just to make sure we definitely have it
	gpg --batch --keyserver "hkp://keyserver.ubuntu.com:80" --recv-keys "2F52 8D36 D67B 69ED F998  D857 78BD 6547 3CB3 BD13"; \
	gpg --batch --verify go.tgz.asc go.tgz; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" go.tgz.asc; \
	\
	tar -C /opt -xzf go.tgz; \
	rm go.tgz; \
	\
	if [ -n "$build" ]; then \
		savedAptMark="$(apt-mark showmanual)"; \
		apt-get update; \
		apt-get install -y --no-install-recommends golang-go; \
		\
		export GOCACHE="/tmp/gocache"; \
		\
		( \
			cd /opt/go/src; \
# set GOROOT_BOOTSTRAP + GOHOST* such that we can build Go successfully
			export GOROOT_BOOTSTRAP="$(go env GOROOT)" GOHOSTOS="$GOOS" GOHOSTARCH="$GOARCH"; \
			./make.bash; \
		); \
		\
		apt-mark auto ".*" > /dev/null; \
		apt-mark manual $savedAptMark > /dev/null; \
		apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
		rm -rf /var/lib/apt/lists/*; \
		\
# remove a few intermediate / bootstrapping files the official binary release tarballs do not contain
		rm -rf \
			/opt/go/pkg/*/cmd \
			/opt/go/pkg/bootstrap \
			/opt/go/pkg/obj \
			/opt/go/pkg/tool/*/api \
			/opt/go/pkg/tool/*/go_bootstrap \
			/opt/go/src/cmd/dist/dist \
			"$GOCACHE" \
		; \
	fi; \
	rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/* /usr/share/man/* /root/.cache
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
WORKDIR $GOPATH
ENV PATH /opt/go/bin:$GOPATH/bin:$PATH
RUN go version
