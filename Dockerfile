FROM doomhammer/busybox:glibc
MAINTAINER Piotr Gaczkowski <DoomHammerNG@gmail.com>

RUN adduser --home /home/linuxbrew \
        --shell /bin/sh \
        -D \
        linuxbrew

USER linuxbrew
WORKDIR /home/linuxbrew
ENV PATH /home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH
ENV SHELL /bin/sh
