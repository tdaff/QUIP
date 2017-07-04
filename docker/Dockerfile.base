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

