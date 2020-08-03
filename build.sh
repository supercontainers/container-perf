#/bin/bash -e

build()
{
    docker-compose build --pull $@
}

if [ -z "${1}" ]; then
    for i in ubuntu centos
    do
	for j in mpich openmpi mvapich
	do
	    build ${i}-${j}
	done
    done
else
    build $@
fi
