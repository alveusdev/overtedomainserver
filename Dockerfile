FROM alveusdev/overtedomainserver-buildenv:latest AS build

ARG REPO=https://github.com/overte-org/overte
ARG TAG=master

ARG DEBIAN_FRONTEND=noninteractive
ARG TERM=linux
ARG MAKEFLAGS=-j4

# Create build and output directory
RUN mkdir /opt/overte-build \
    && mkdir /opt/overte

# Fetch repository
RUN git clone --depth 1 --branch $TAG $REPO /opt/overte-build/

# Build just the server
RUN cd /opt/overte-build \
    && mkdir build \
    && cd ./build \
    && export OVERTE_USE_SYSTEM_QT=1 \
    && export RELEASE_TYPE=PRODUCTION \
    && export RELEASE_NUMBER=${TAG} \
    && if [ $(uname -m) == "x86_64" ]; then \
        # amd64 \
        cmake -G "Unix Makefiles" -DSERVER_ONLY=1 -DBUILD_TOOLS=1 -DOVERTE_CPU_ARCHITECTURE=-msse3 ..; \
    else \
        # aarch64 \
        VCPKG_FORCE_SYSTEM_BINARIES=1 cmake -G "Unix Makefiles" -DSERVER_ONLY=1 -DBUILD_TOOLS=1 -DOVERTE_CPU_ARCHITECTURE= ..; \
    fi

# put number after -j to limit cores.
RUN cd /opt/overte-build/build \
    && make -j`nproc` domain-server \
    && make -j`nproc` assignment-client \
    && make -j`nproc` oven  # needed for baking

RUN VCPKG_PATH=$(python3 /opt/overte-build/prebuild.py --get-vcpkg-path --build-root . --quiet) && \
    echo "VCPKG Path: $VCPKG_PATH" && \
    find "$VCPKG_PATH" -type f -name "libnode.so.108" -exec cp {} /opt/overte-build/build/libraries \; || \
    echo "libnode.so.108 not found in $VCPKG_PATH"

# Move built binaries etc to output directory
RUN mv /opt/overte-build/build/libraries /opt/overte/libraries \
    && mv /opt/overte-build/build/assignment-client/assignment-client /opt/overte/assignment-client \
    && mv /opt/overte-build/build/assignment-client/plugins /opt/overte/plugins \
    && mv /opt/overte-build/build/domain-server/domain-server /opt/overte/domain-server \
    && mv /opt/overte-build/domain-server/resources /opt/overte/resources

# Runtime
FROM debian:bookworm-slim AS runtime

LABEL maintainer="alveus.dev"
LABEL description="Overte Domain Server AIO"

ARG DEBIAN_FRONTEND=noninteractive
ARG TERM=linux

RUN echo UTC >/etc/timezone

# Install libraries
COPY --from=build /opt/overte/libraries/*/*.so /lib/

RUN mkdir /opt/overte

# Fetch built services
COPY --from=build /opt/overte/domain-server /opt/overte
COPY --from=build /opt/overte/assignment-client /opt/overte
COPY --from=build /opt/overte/plugins /opt/overte/plugins
COPY --from=build /opt/overte/resources /opt/overte/resources

RUN chmod +x /opt/overte/domain-server && \
    chmod +x /opt/overte/assignment-client

# Run test
RUN /opt/overte/domain-server --version > /opt/overte/version && \
    /opt/overte/assignment-client --version >> /opt/overte/version

# Install supervisor config
COPY ./services.conf /etc/supervisor/conf.d/overte.conf

RUN mkdir /var/log/overte

# Expose required ports
EXPOSE 40100 40101 40102
EXPOSE 40100/udp 40101/udp 40102/udp
EXPOSE 48000/udp 48001/udp 48002/udp 48003/udp 48004/udp 48005/udp 48006/udp

ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/overte.conf"]


