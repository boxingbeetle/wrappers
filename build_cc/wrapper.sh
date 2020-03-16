#!/bin/sh

exit_with_error() {
    echo "Aborting build because of error: $1"
    echo "result=error" >> "$SF_RESULTS"
    echo "summary=$1" >> "$SF_RESULTS"
    exit 0
}

cd "${SF_PRODUCT_ROOT}/${CC_ROOT}" || exit_with_error "Cannot access source dir"

HASH=`git rev-parse --short HEAD`
test -n "$HASH" || exit_with_error "Failed to get Git hash"

VERSION=`sed -ne 's/^version = "\(.*\)"/\1/p' pyproject.toml`
test -n "$VERSION" || exit_with_error "No version found in project file"

sed -i 's/^version = "'"$VERSION"'"/version = "'"$VERSION+g$HASH"'"/' pyproject.toml

rm -f dist/*.whl
poetry build -f wheel || exit_with_error "Poetry failed to build package"
WHEEL=`cd dist && echo *.whl`

scp "dist/$WHEEL" www.softfab.io:softfab/snapshots || exit_with_error "Wheel upload failed"

echo "result=ok" >> "$SF_RESULTS"
echo "summary=Wheel built and uploaded" >> "$SF_RESULTS"
echo "output.CC_WHEEL.locator=https://softfab.io/snapshots/$WHEEL" >> "$SF_RESULTS"
