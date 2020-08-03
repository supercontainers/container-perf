#!/bin/bash -e

# supply any text files to append to the build
# one spec per line
: ${ARGS:="$@"}
for i in ${ARGS}
do
    if [ -f ${i} ]; then
        while read line
        do
            EXTRA_SPEC="${EXTRA_SPEC}- ${line}$(echo '')    "
        done < ${i}
    fi
done

TARG_DIR=${PWD}
while read OS_SPEC
do
    while read MPI_SPEC
    do
        APP_NAME=kokkos
        OS_NAME="$(echo ${OS_SPEC} | sed 's/:/ /g' | awk '{print $1}')"
        MPI_NAME="$(echo ${MPI_SPEC} | sed 's/[@+~.]/ /g' | awk '{print $1}')"
        echo "OS: ${OS_NAME}, MPI: ${MPI_NAME}"
        mkdir -p ${MPI_NAME}
        cp ./runtime-entrypoint.sh ./${MPI_NAME}
        pushd ./${MPI_NAME}
        rm -rf .spack-env
        rm -f spack.yaml
        rm -f Dockerfile.${OS_NAME}
        cat ${TARG_DIR}/spack.yaml.in | sed \
            -e s,'@MPI_SPEC@',"${MPI_SPEC}",g \
            -e s,'@MPI_NAME@',"${MPI_NAME}",g \
            -e s,'@APP_NAME@',"${APP_NAME}",g \
            -e s,'@OS_SPEC@',"${OS_SPEC}",g \
            -e s,'@EXTRA_SPEC@',"${EXTRA_SPEC}",g \
            > ./spack.yaml
        spack containerize | sed \
            -e /'^ENTRYPOINT'/d \
            -e s,'spack install','spack --env . install',g \
            > Dockerfile.${OS_NAME}
        echo 'ENTRYPOINT [ "/runtime-entrypoint.sh" ]' >> Dockerfile.${OS_NAME}
        rm -rf .spack-env
        rm -f spack.yaml
        popd
    done < mpi.txt
done < os.txt
