# Base Python image has most up to date Python parts
FROM python:2

MAINTAINER Tom Daff "tdd20@cam.ac.uk"

# Needed to build QUIP
RUN apt-get -y update \
    && apt-get upgrade -y \
    && apt-get install -y \
        gfortran \
        liblapack-dev \
        libblas-dev \
        libnetcdf-dev \
        netcdf-bin

# Custom install of openblas so OpenMP can be used
# otherwise linear algebra is limited to single core
RUN git clone https://github.com/xianyi/OpenBLAS.git /tmp/OpenBLAS
RUN cd /tmp/OpenBLAS \
    && make DYNAMIC_ARCH=1 NO_AFFINITY=1 USE_OPENMP=1 NUM_THREADS=32 \
    && make DYNAMIC_ARCH=1 install

# Make openblas the default
RUN update-alternatives --install /usr/lib/libblas.so libblas.so /opt/OpenBLAS/lib/libopenblas.so 1000
RUN update-alternatives --install /usr/lib/libblas.so.3 libblas.so.3 /opt/OpenBLAS/lib/libopenblas.so 1000
RUN update-alternatives --install /usr/lib/liblapack.so liblapack.so /opt/OpenBLAS/lib/libopenblas.so 1000
RUN update-alternatives --install /usr/lib/liblapack.so.3 liblapack.so.3 /opt/OpenBLAS/lib/libopenblas.so 1000

# get missing library errors without this
RUN ldconfig

RUN pip install --upgrade pip
RUN pip install notebook numpy scipy matplotlib ase

# To build within the image without additonal libraries use
# the git+VANILLA version
# RUN git clone https://github.com/libAtoms/QUIP.git /opt/QUIP
ENV BUILD VANILLA
ADD . /opt/QUIP
# ENV BUILD ALL
ENV QUIP_ARCH linux_x86_64_gfortran_openmp

RUN cd /opt/QUIP \
    && mkdir -p build/${QUIP_ARCH} \
    && cp tests/rules/${BUILD}_Makefile.${QUIP_ARCH}.inc build/${QUIP_ARCH}/Makefile.inc \
    && make \
    && make install-quippy

ENV PATH="/opt/QUIP/build/linux_x86_64_gfortran_openmp:${PATH}"

CMD jupyter notebook --port=8899 --ip="*" --allow-root --NotebookApp.token='' --NotebookApp.password=''

ENTRYPOINT /bin/bash

EXPOSE 8899
