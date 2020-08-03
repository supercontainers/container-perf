#!/bin/bash --rcfile /etc/profile -l

# The purpose of this entrypoint is to embed some lightweight
# performance monitoring in the application
#
if [ -z "${1}" ]; then
    exec /bin/bash -l
fi

# try to use timem if inside container
: ${TIME:=$(which timem)}
# if timem, not available, look for time
: ${TIME:=$(which time)}
# execute
eval ${TIME} $@
