#!/bin/sh

exit_with_error() {
    echo "Aborting build because of error: $1"
    echo "result=error" >> "$SF_RESULTS"
    echo "summary=$1" >> "$SF_RESULTS"
    exit 0
}

for INPUT in ${SF_INPUTS}
do
    case "${INPUT}" in
    *_ROOT)
        eval SOURCE_DIR='${'"${INPUT}"'}'
        ;;
    esac
done
if [ -z ${SOURCE_DIR} ]
then
    exit_with_error "No source input found (*_ROOT)"
fi

cd "${SF_PRODUCT_ROOT}/${SOURCE_DIR}" || exit_with_error "Cannot access source dir"

poetry update || exit_with_error "Poetry could not install or update dependencies"

poetry run inv ${INVOKE_ARGS} --results="${SF_RESULTS}" || exit_with_error "Invoke task failed"
