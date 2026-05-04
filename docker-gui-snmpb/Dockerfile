FROM i386/debian:buster-slim

RUN apt-get update && apt-get install --yes \
    libc6 \
    libgcc1 \
    libqtcore4 \
    libqtgui4 \
    libstdc++6 \
    x11vnc \
    x11-xserver-utils \
    xinit \
    xvfb \
    locales && \
    echo "C.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen C.UTF-8 && \
    dpkg-reconfigure locales && \
    mkdir --parents /app
COPY ./snmpb_0.8_i386.deb /app
WORKDIR /app
RUN apt-get update && apt-get install --yes \
    ./snmpb_0.8_i386.deb
