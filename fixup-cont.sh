#!/bin/bash

TMP=.fixup-tmp-patch

. .fixup-vars

echo "commit changes"
git add -u || exit 1
git commit --amend --no-edit || exit 1
NEWHASH=$(git log --pretty="format:%h" -1)
echo "new commit $NEWHASH"
echo "checkout $BRANCH"
git checkout -q $BRANCH || exit 1
echo "rebase to $NEWHASH"
git rebase --onto $NEWHASH $HASH || exit 1
echo "success $(git log --pretty='format:%h' -1)"
rm $TMP
