#!/bin/sh

exit_with_error() {
    echo "Aborting build because of error: $1"
    echo "result=error" >> "$SF_RESULTS"
    echo "summary=$1" >> "$SF_RESULTS"
    exit 0
}

# Run build.
echo "Starting build"
echo "report=build_log.txt" >> "$SF_RESULTS"
make -C "$SF_PRODUCT_ROOT/$WRAPTREE_ROOT" > "$SF_REPORT_ROOT/build_log.txt" 2>&1
MAKE_RESULT=$?
if [ $MAKE_RESULT -ne 0 ]
then
    exit_with_error "Make returned exit code $MAKE_RESULT"
fi

# Move executable to products directory.
mkdir -p "$SF_PRODUCT_ROOT"
mv "$SF_PRODUCT_ROOT/$WRAPTREE_ROOT/WrapTree.exe" "$SF_PRODUCT_ROOT"
echo "output.WRAPTREE_EXE.locator=$SF_PRODUCT_ROOT/WrapTree.exe" >> "$SF_RESULTS"

# Check build log for warnings.
grep '^[^ ]*: warning:' "$SF_REPORT_ROOT/build_log.txt" > /dev/null
if [ $? -eq 0 ]
then
    echo "result=warning" >> "$SF_RESULTS"
    echo "summary=Build log contains warnings" >> "$SF_RESULTS"
else
    echo "result=ok" >> "$SF_RESULTS"
    echo "summary=Build succeeded" >> "$SF_RESULTS"
fi
