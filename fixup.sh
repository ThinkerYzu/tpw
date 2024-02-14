#!/bin/bash

N=$1
TMP=.fixup-tmp-patch
BRANCH=$(git branch --show-current)
TIP=$(git log --pretty="format:%h" -1)
HASH=$(git log --pretty="format:%h" '@{upstream}..'| tail -$N | head -1)

echo "BRANCH=$BRANCH" > .fixup-vars
echo "HASH=$HASH" >> .fixup-vars

echo "BRANCH $BRANCH @ $TIP"
echo "fixup $(git log --pretty="format:%h %s" $HASH^..$HASH)"
git diff HEAD > $TMP
echo "Clear working directory"
git reset --hard -q || exit 1
echo "checkout $HASH"
git checkout -q $HASH || exit 1
echo "apply patch"
patch -p1 < $TMP || exit 1

D=$(dirname $0)
$D/fixup-cont.sh
