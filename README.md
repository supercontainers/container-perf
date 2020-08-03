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

## Benchmarking

```console
$ docker run -it --rm supercontainers/container-perf:ubuntu-mpich /usr/bin/lulesh-optimized --help
To run other sizes, use -s <integer>.
To run a fixed number of iterations, use -i <integer>.
To run a more or less balanced region set, use -b <integer>.
To change the relative costs of regions, use -c <integer>.
To print out progress, use -p
To write an output file for VisIt, use -v
See help (-h) for more options
```

### Sample Output

```console
Running problem size 30^3 per domain until completion
Num processors: 8
Num threads: 4
Total number of elements: 216000

To run other sizes, use -s <integer>.
To run a fixed number of iterations, use -i <integer>.
To run a more or less balanced region set, use -b <integer>.
To change the relative costs of regions, use -c <integer>.
To print out progress, use -p
To write an output file for VisIt, use -v
See help (-h) for more options

cycle = 1, time = 6.852019e-07, dt=6.852019e-07
cycle = 2, time = 1.507444e-06, dt=8.222423e-07
cycle = 3, time = 1.789278e-06, dt=2.818333e-07
cycle = 4, time = 2.024630e-06, dt=2.353527e-07
cycle = 5, time = 2.234438e-06, dt=2.098079e-07
cycle = 6, time = 2.429254e-06, dt=1.948161e-07
cycle = 7, time = 2.614474e-06, dt=1.852199e-07
cycle = 8, time = 2.793376e-06, dt=1.789023e-07
cycle = 9, time = 2.968181e-06, dt=1.748048e-07
cycle = 10, time = 3.140521e-06, dt=1.723397e-07
cycle = 11, time = 3.347329e-06, dt=2.068076e-07
cycle = 12, time = 3.580825e-06, dt=2.334965e-07
cycle = 13, time = 3.801554e-06, dt=2.207292e-07
cycle = 14, time = 4.009569e-06, dt=2.080144e-07
cycle = 15, time = 4.204856e-06, dt=1.952872e-07
cycle = 16, time = 4.391294e-06, dt=1.864386e-07
cycle = 17, time = 4.572177e-06, dt=1.808824e-07
cycle = 18, time = 4.750330e-06, dt=1.781535e-07
cycle = 19, time = 4.928456e-06, dt=1.781255e-07
cycle = 20, time = 5.106581e-06, dt=1.781255e-07
cycle = 21, time = 5.284707e-06, dt=1.781255e-07
cycle = 22, time = 5.462832e-06, dt=1.781255e-07
cycle = 23, time = 5.640958e-06, dt=1.781255e-07
cycle = 24, time = 5.838115e-06, dt=1.971575e-07
cycle = 25, time = 6.035273e-06, dt=1.971575e-07
cycle = 26, time = 6.232430e-06, dt=1.971575e-07
cycle = 27, time = 6.457155e-06, dt=2.247252e-07
cycle = 28, time = 6.681880e-06, dt=2.247252e-07
cycle = 29, time = 6.950244e-06, dt=2.683634e-07
cycle = 30, time = 7.254776e-06, dt=3.045323e-07
cycle = 31, time = 7.547127e-06, dt=2.923506e-07
cycle = 32, time = 7.829604e-06, dt=2.824770e-07
cycle = 33, time = 8.105297e-06, dt=2.756935e-07
cycle = 34, time = 8.376591e-06, dt=2.712932e-07
cycle = 35, time = 8.645899e-06, dt=2.693089e-07
cycle = 36, time = 8.915208e-06, dt=2.693089e-07
cycle = 37, time = 9.184517e-06, dt=2.693089e-07
cycle = 38, time = 9.453826e-06, dt=2.693089e-07
cycle = 39, time = 9.723135e-06, dt=2.693089e-07
cycle = 40, time = 1.002492e-05, dt=3.017811e-07
cycle = 41, time = 1.032670e-05, dt=3.017811e-07
cycle = 42, time = 1.062848e-05, dt=3.017811e-07
cycle = 43, time = 1.093026e-05, dt=3.017811e-07
cycle = 44, time = 1.123204e-05, dt=3.017811e-07
cycle = 45, time = 1.153141e-05, dt=2.993676e-07
cycle = 46, time = 1.182441e-05, dt=2.930026e-07
cycle = 47, time = 1.211197e-05, dt=2.875624e-07
cycle = 48, time = 1.239508e-05, dt=2.831021e-07
cycle = 49, time = 1.267466e-05, dt=2.795814e-07
cycle = 50, time = 1.295174e-05, dt=2.770851e-07
Run completed:
   Problem size        =  30
   MPI tasks           =  8
   Iteration count     =  50
   Final Origin Energy = 1.750636e+07
   Testing Plane 0 of Energy Array on rank 0:
        MaxAbsDiff   = 2.328306e-09
        TotalAbsDiff = 5.189477e-09
        MaxRelDiff   = 1.496717e-11


Elapsed time         =      13.32 (s)
Grind time (us/z/c)  =  9.8646646 (per dom)  ( 1.2330831 overall)
FOM                  =  810.97537 (z/s)
```