# container-perf

This repository builds several variants of MPI + Kokkos + CUDA for container performance benchmarking

## Overview

This repository can be configured to build an array of containers for different operating systems and MPI variants.
The MPI specifications are configured in `packages/mpi.txt` with one Spack spec per-line.
The OS specifications are configured in `packages/os.txt` with one Spack spec per-line.
CUDA, Kokkos, and a mini-app are always installed. Additionally Spack specs can be placed in files and
passed to the `packages/generate.sh` script. A sample is placed in `packages/extra.txt`.

## Quick Start

```console
cd packages
./generate.sh
cd ..
docker-compose build --pull ubuntu-mpich
```

## Example

```console
$ cd packages

$ cat extra.txt
timemory@develop +tools +cuda +cupti +gotcha +mpi +mpip_library +papi +gperftools cuda_arch=volta

$ ./generate extra.txt
OS: ubuntu, MPI: mpich
OS: ubuntu, MPI: mvapich2
OS: ubuntu, MPI: openmpi
OS: centos, MPI: mpich
OS: centos, MPI: mvapich2
OS: centos, MPI: openmpi

$ cat mpich/Dockerfile.ubuntu
# Build stage with Spack pre-installed and ready to be used
FROM spack/ubuntu-bionic:latest as builder

# What we want to install and how we want to install it
# is specified in a manifest file (spack.yaml)
RUN mkdir /opt/spack-environment \
&&  (echo "spack:" \
&&   echo "  specs:" \
&&   echo "  - cuda" \
&&   echo "  - kokkos build_type=Release +cuda cuda_arch=72 +cuda_lambda +cuda_uvm +hwloc +memkind +numactl +openmp +wrapper std=14" \
&&   echo "  - mpich device=ch3 +hydra netmod=tcp ~pci pmi=pmi +romio ~slurm" \
&&   echo "  - timemory@develop +tools +cuda +cupti +gotcha +mpi +mpip_library +papi +gperftools cuda_arch=volta" \
&&   echo "  concretization: together" \
&&   echo "  config:" \
&&   echo "    install_tree: /opt/software" \
&&   echo "  view: /opt/view") > /opt/spack-environment/spack.yaml

# Install the software, remove unecessary deps
RUN cd /opt/spack-environment && spack --env . install && spack gc -y

# Modifications to the environment that are necessary to run
RUN cd /opt/spack-environment && \
    spack env activate --sh -d . >> /etc/profile.d/z10_spack_environment.sh

SHELL ["/bin/bash", "--rcfile", "/etc/profile", "-l"]
WORKDIR /tmp
RUN git clone https://github.com/jrmadsen/kokkos-miniapps.git && \
    cd kokkos-miniapps && \
    git checkout submodules && \
    mkdir -p build-container && \
    cd build-container && \
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_CXX_COMPILER=nvcc_wrapper -DUSE_MPI=ON .. && \
    make install -j8 && \
    cd /tmp && \
    rm -rf /tmp/kokkos-miniapps


# Bare OS image to run the installed executables
FROM ubuntu:18.04

COPY --from=builder /opt/spack-environment /opt/spack-environment
COPY --from=builder /opt/software /opt/software
COPY --from=builder /opt/view /opt/view
COPY --from=builder /etc/profile.d/z10_spack_environment.sh /etc/profile.d/z10_spack_environment.sh


ENV OMP_PROC_BIND spread
ENV OMP_PLACES threads
ENV CUDA_HOME "/opt/view"
ENV NVIDIA_REQUIRE_CUDA "cuda>=10.2"
ENV NVIDIA_VISIBLE_DEVICES "all"
ENV NVIDIA_DRIVER_CAPABILITIES "compute,utility"
COPY ./runtime-entrypoint.sh /runtime-entrypoint.sh
RUN echo 'export PS1="\[$(tput bold)\]\[$(tput setaf 1)\][kokkos-mpich]\[$(tput setaf 2)\]\u\[$(tput sgr0)\]:\w $ \[$(tput sgr0)\]"' >> ~/.bashrc


LABEL "app"="kokkos"
LABEL "mpi"="mpich"

ENTRYPOINT [ "/runtime-entrypoint.sh" ]
```