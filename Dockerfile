FROM alveusdev/overtedomainserver-buildenv:latest AS build

ARG REPO=https://github.com/overte-org/overte
ARG TAG=master

ARG DEBIAN_FRONTEND=noninteractive
ARG TERM=linux
ARG MAKEFLAGS=-j2
ARG TARGETARCH

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
    && cmake -DSERVER_ONLY=1 -DOVERTE_CPU_ARCHITECTURE=-msse3 ..

RUN cd /opt/overte-build/build \
    && make

# Move built binraries etc to output directory
RUN mv /opt/overte-build/build/libraries /opt/overte/libraries \
    && mv /opt/overte-build/build/assignment-client/assignment-client /opt/overte/assignment-client \
    && mv /opt/overte-build/build/assignment-client/plugins /opt/overte/plugins \
    && mv /opt/overte-build/build/domain-server/domain-server /opt/overte/domain-server \
    && mv /opt/overte-build/domain-server/resources /opt/overte/resources

# Runtime
FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS runtime

LABEL maintainer="alveus.dev"
LABEL description="Overte Domain Server AIO"

ARG DEBIAN_FRONTEND=noninteractive
ARG TERM=linux
ARG TARGETARCH

RUN echo UTC >/etc/timezone

RUN echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf.d/00-docker
RUN echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/00-docker

# Install dependencies
RUN apt update && apt install -y tzdata supervisor libopengl-dev ca-certificates \
    libqt5widgets5 libqt5network5 libqt5script5 libqt5core5a libqt5qml5 libqt5websockets5 libqt5gui5 libnode108

# Cleanup
RUN apt clean && rm -rf /var/lib/app/lists/*

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

RUN useradd -Ms /bin/bash services

RUN mkdir /var/log/overte

# Expose required ports
EXPOSE 40100 40101 40102
EXPOSE 40100/udp 40101/udp 40102/udp
EXPOSE 48000/udp 48001/udp 48002/udp 48003/udp 48004/udp 48005/udp 48006/udp

ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/overte.conf"]


