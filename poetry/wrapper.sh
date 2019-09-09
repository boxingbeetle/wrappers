#!/bin/sh

exit_with_error() {
    echo "Aborting build because of error: $1"
    echo "result=error" >> "$SF_RESULTS"
    echo "summary=$1" >> "$SF_RESULTS"
    exit 0
}

cd "${SF_PRODUCT_ROOT}/${CC_ROOT}" || exit_with_error "Cannot access Control Center source dir"

poetry update || exit_with_error "Poetry could not install or update dependencies"

poetry run inv ${INVOKE_ARGS} --results="${SF_RESULTS}" || exit_with_error "Invoke task failed"
