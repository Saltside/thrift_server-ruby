#!/usr/bin/env bash

# pre-command hook to build thrift-files
#
# This script will compile and generate client code for any
# thrift-files submodule. It only generates when the current branch
# isn't master, and when the submodule reference isn't reachable from
# the submodule's master branch.
#
# This is done to make development involving thrift-files changes
# smoother.

git submodule foreach '
upstream=$(git config --local --get remote.origin.url | cut -f2 -d:)

# We do not care about submodules other than thrift-files.
echo "${upstream}" | grep -i "saltside/platform-thrift-files" || exit 0

# Check if the reference is reachable from the master branch.
if ! git merge-base --is-ancestor $sha1 origin/master; then
	# Do not allow to run non-master thrift-files in master branch!
	if [ "${BUILDKITE_BRANCH}" = "master" ]; then
		echo "--- :red_button: master branch must not reference non-master thrift-files"
		exit 1
	fi

	echo "--- :construction: thrift-files is running non-master branch, generating"
	make
fi
'
