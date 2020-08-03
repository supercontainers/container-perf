#!/bin/bash --rcfile /etc/profile -l

#------------------------------------------------------------------------------#
#   run command
#------------------------------------------------------------------------------#
if [ -z "${1}" ]; then
    exec /bin/bash -l
fi

# try to use timem if inside container
: ${TIME:=$(which timem)}
# if timem, not available, look for time
: ${TIME:=$(which time)}
# execute
eval ${TIME} $@
