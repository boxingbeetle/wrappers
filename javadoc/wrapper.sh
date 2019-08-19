#!/bin/bash

set -u

echo "Running JavaDoc documentation extractor..."

cd $SF_PRODUCT_ROOT/$TR_ROOT
ant doc
exitcode=$?

echo "Ant exit code: $exitcode"
if [ $exitcode = 0 ]
then
    mv "derived/doc" "$SF_PRODUCT_ROOT/task_runner_docs"
    echo "result=ok" > $SF_RESULTS
    echo "summary=JavaDoc extracted" >> $SF_RESULTS
    echo "report=$SF_PRODUCT_ROOT/task_runner_docs" >> $SF_RESULTS
else
    echo "result=error" > $SF_RESULTS
    echo "summary=Ant failed with exit code $exitcode" >> $SF_RESULTS
fi
