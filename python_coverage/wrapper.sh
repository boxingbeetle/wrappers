#!/bin/bash

exit_with_error() {
    echo "Aborting build because of error: $1"
    echo "result=error" >> "$SF_RESULTS"
    echo "summary=$1" >> "$SF_RESULTS"
    exit 0
}

cd "$SF_PRODUCT_ROOT/$CC_ROOT" || exit_with_error "Cannot access source dir"

# Combine coverage data from all inputs.
# The coverage tool removes its inputs as it combines them, which is not
# what we want in SoftFab, so we run it on copies of the data instead of
# on the actual inputs.
for TASK in $SF_PROD_COVERAGE_KEYS
do
    eval LOCATOR="\$SF_PROD_COVERAGE_${TASK}_LOCATOR"
    cp "$LOCATOR" "$SF_REPORT_ROOT/$TASK.coverage"
done
poetry run sh -c 'cd '"$SF_REPORT_ROOT"' && coverage combine --rcfile='"$SF_PRODUCT_ROOT/$CC_ROOT/.coveragerc"' *.coverage .'

# Generate coverage report.
poetry run sh -c 'cd '"$SF_REPORT_ROOT"' && coverage html --rcfile='"$SF_PRODUCT_ROOT/$CC_ROOT/.coveragerc"' -d '"$SF_REPORT_ROOT/coverage"
sed -i "s%$PWD/src/softfab/%softfab/%g" "$SF_REPORT_ROOT/coverage/"*.html
echo "result=ok" > "$SF_RESULTS"
echo "summary=Coverage report generated" >> "$SF_RESULTS"
echo "report=$SF_REPORT_ROOT/coverage/" >> "$SF_RESULTS"
