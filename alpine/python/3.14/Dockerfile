FROM alpine:3.24

ENV PATH /usr/local/bin:$PATH
ENV PYTHON_VERSION 3.14.6
ENV PYTHON_SHA256 143b1dddefaec3bd2e21e3b839b34a2b7fb9842272883c576420d605e9f30c63

RUN set -eux; \
	\
	apk add --no-cache --virtual .build-deps \
		bluez-dev \
		bzip2-dev \
		dpkg-dev dpkg \
		findutils \
		gcc \
		gdbm-dev \
		gnupg \
		libc-dev \
		libffi-dev \
		libnsl-dev \
		libtirpc-dev \
		linux-headers \
		make \
		ncurses-dev \
		openssl-dev \
		pax-utils \
		readline-dev \
		sqlite-dev \
		tar \
		tcl-dev \
		tk \
		tk-dev \
		util-linux-dev \
		xz \
		xz-dev \
		zlib-dev \
		zstd-dev 
RUN wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz"; \
	echo "$PYTHON_SHA256 *python.tar.xz" | sha256sum -c -; \
	mkdir -p /usr/src/python; \
	tar --extract --directory /usr/src/python --strip-components=1 --file python.tar.xz; \
	rm python.tar.xz; \
	\
	cd /usr/src/python; \
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	./configure \
		--build="$gnuArch" \
		--enable-loadable-sqlite-extensions \
		--enable-option-checking=fatal \
		--enable-shared \
		$(test "${gnuArch%%-*}" != 'riscv64' && echo '--with-lto') \
		--with-ensurepip \
	; \
	nproc="$(nproc)"; \
	EXTRA_CFLAGS="-DTHREAD_STACK_SIZE=0x100000"; \
	LDFLAGS="${LDFLAGS:-} -Wl,--strip-all"; \
	arch="$(apk --print-arch)"; \
	case "$arch" in \
		x86_64|aarch64) \
			EXTRA_CFLAGS="${EXTRA_CFLAGS:-} -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer"; \
			;; \
		x86) \
			;; \
		*) \
			EXTRA_CFLAGS="${EXTRA_CFLAGS:-} -fno-omit-frame-pointer"; \
			;; \
	esac; \
	make -j "$nproc" \
		"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
		"LDFLAGS=${LDFLAGS:-}" \
	; \
	rm python; \
	make -j "$nproc" \
		"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
		"LDFLAGS=${LDFLAGS:-} -Wl,-rpath='\$\$ORIGIN/../lib'" \
		python \
	; \
	make install; \
	\
	cd /; \
	rm -rf /usr/src/python; \
	\
	find /usr/local -depth \
		\( \
			\( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
			-o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name 'libpython*.a' \) \) \
		\) -exec rm -rf '{}' + \
	; \
	\
	find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec scanelf --needed --nobanner --format '%n#p' '{}' ';' \
		| tr ',' '\n' \
		| sort -u \
		| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
		| xargs -rt apk add --no-network --virtual .python-rundeps \
	; \
	apk del --no-network .build-deps; \
	\
	export PYTHONDONTWRITEBYTECODE=1; \
	python3 --version; \
	pip3 --version

RUN set -eux; \
	for src in idle3 pip3 pydoc3 python3 python3-config; do \
		dst="$(echo "$src" | tr -d 3)"; \
		[ -s "/usr/local/bin/$src" ]; \
		[ ! -e "/usr/local/bin/$dst" ]; \
		ln -svT "$src" "/usr/local/bin/$dst"; \
	done
ENV UID=1000 \
    USER=app-user    
RUN adduser \
    --disabled-password \
	--gecos "" \
	--uid "$UID" \
	--shell "/bin/bash" \
	$USER
# RUN set -eux; \
# 	apk add --no-cache \
# 		build-base alpine-sdk traceroute bash busybox-extras ca-certificates tzdata; \
#         update-ca-certificates
RUN set -eux; \
        apk update --no-cache ;\
        apk upgrade --no-cache ;\
        apk add --no-cache \
            ca-certificates \
            tzdata \
            gnupg \
            xz \
            bluez-dev \
            bzip2-dev \
            dpkg-dev dpkg \
            findutils \
            gcc \
            gdbm-dev \
            libc-dev \
            libffi-dev \
            libnsl-dev \
            libtirpc-dev \
            linux-headers \
            ncurses-dev \
            openssl-dev \
            pax-utils \
            readline-dev \
            sqlite-dev \
            tcl-dev \
            tk \
            tk-dev \
            util-linux-dev \
            xz-dev \
            zlib-dev \
            build-base \
            alpine-sdk \
            traceroute \
            bash \
            busybox-extras \
            curl; \
            update-ca-certificates
    
USER 1000		
CMD ["python3"]