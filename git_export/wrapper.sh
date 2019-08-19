#!/bin/bash

# This wrapper is used by the Git export of different modules. Per module a
# different set of output products is defined.

# This wrapper consumes the following input products:
#	<none>:

# It uses the following input parameters:
#   GIT_REPO_URL:	for example: https://git.example.com/project.git
#   GIT_PATH_<prod>:	subdirectory to append to <prod>_ROOT locator
#   GIT_REVISION:	specifies branch, tag or commit ID to retrieve

# The wrapper produces (on success) the following output products:
#   <mod>_REVISION:	commit ID of exported module
#   <mod>_ROOT:		root specification of exported module
#   <mod>_VERSION: 	CC only - specifies the Control Center version number,
#			only generated if the Control Center code is exported.


if [ -n "$GIT_REVISION" ]; then
	REVISION_OPT="--branch $GIT_REVISION"
else
	REVISION_OPT=""
fi

if [ -z "$GIT_PRODUCT" ]; then
	GIT_PRODUCT="export"
fi

echo "Exporting from Git: $GIT_REPO_URL"
mkdir -p "$SF_PRODUCT_ROOT"
cd "$SF_PRODUCT_ROOT"
git clone --depth 1 $REVISION_OPT -- "$GIT_REPO_URL" "$GIT_PRODUCT"
GIT_RESULT=$?

if [ $GIT_RESULT != 0 ]; then
	RESULT="error"
	SUMMARY="Export failed: Git returned exit code $GIT_RESULT"
else
	EXPORTED_REVISION=`cd "$GIT_PRODUCT" && git rev-parse HEAD`
	if [ -z "$EXPORTED_REVISION" ]; then
		RESULT="error"
		SUMMARY="Could not get revision number from Git export"
	else
		RESULT="ok"
		SUMMARY="Exported revision $EXPORTED_REVISION"
	fi
fi

# write to SF_RESULTS file (results.properties)
echo "result=$RESULT" > $SF_RESULTS
echo "summary=$SUMMARY" >> $SF_RESULTS

#
# Generate for all required output products the locator in the result file
#
if [ $RESULT == ok ]; then
	for OUTPUT in $SF_OUTPUTS; do
		if [ ${OUTPUT: -5} == _ROOT ]; then
			eval GIT_PATH='${'"GIT_PATH_${OUTPUT:0:-5}"'}'
			echo "output.$OUTPUT.locator=$GIT_PRODUCT/$GIT_PATH" >> $SF_RESULTS
		elif [ ${OUTPUT: -9} == _REVISION ]; then
			echo "output.$OUTPUT.locator=$EXPORTED_REVISION" >> $SF_RESULTS
		fi
	done
	# extraction data
	echo "data.git_revision=$EXPORTED_REVISION" >> $SF_RESULTS
else
	# write error message to stdout / wrapper_log.txt
	echo $SUMMARY
fi
