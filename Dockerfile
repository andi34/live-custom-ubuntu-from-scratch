ARG BASE_IMAGE=ubuntu:22.04
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -y update && \
    apt-get -y install \
        binutils debootstrap squashfs-tools \
        xorriso grub-pc-bin grub-efi-amd64-bin \
        mtools dosfstools unzip lsb-core sudo

COPY . /live-custom-ubuntu-from-scratch/

VOLUME [ "/live-custom-ubuntu-from-scratch/scripts"]
