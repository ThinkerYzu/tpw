#!/bin/bash

shopt -s extglob

if [ x"$1" == x"init" ]; then
    if [ x"$2" == x"" ]; then
	echo "$0 init <dirname>"
	exit 255
    fi
    echo "$2" > .tpw-patch-dir
    echo "default" > .tpw-current
fi

COMMAND="$1"
PATCH_DIR=$(cat .tpw-patch-dir)
ORIGIN_DIR=$(pwd)
CURRENT_PROJECT=$(cat "$ORIGIN_DIR/.tpw-current")

DEFAULT_SEND_TO="${PATCH_DIR}.tpw-default-send-to"
DEFAULT_TARGET_TREE="${PATCH_DIR}.tpw-default-target-tree"
PWS="${PATCH_DIR}.tpw-aspell.en.pws"
LAST_VISITS="${PATCH_DIR}.tpw-last-visits"
VISIT_HISTORY_SIZE=10

PROJ_DIR="$PATCH_DIR$CURRENT_PROJECT/"
EXTRACTED_COVER="${PROJ_DIR}.tpw-extracted-cover"
VER="${PROJ_DIR}.tpw-ver"
SEND_TO="${PROJ_DIR}.tpw-send-to"
BRANCH="${PROJ_DIR}.tpw-branch"

CURRENT_VERSION=$(cat "${PROJ_DIR}.tpw-ver" 2> /dev/null)

if [ -n "$OVERRIDE_VERSION" ]; then
    CURRENT_VERSION="$OVERRIDE_VERSION"
fi

CURRENT_PATCH_DIR="$PROJ_DIR$CURRENT_VERSION/"
COVER_LETTER="$CURRENT_PATCH_DIR/0000-cover-letter.patch"
TARGET_TREE=$(cat "$PROJ_DIR/.tpw-target-tree")

if [ x"$PATCH_DIR" == x"" ]; then
    echo "Can not read .tpw-patch-dir"
    exit 255
fi

function init_patch_dir () {
    DIR="$(readlink -f $1)/"
    if [ ! -e "$DIR/.tpw-default-send-to" ]; then
	mkdir -p "$DIR"
	echo "" > "${DIR}/.tpw-default-send-to"
	echo "personal_ws-1.1 en 0" > "${DIR}/.tpw-aspell.en.pws"
	echo "$DIR" > ".tpw-patch-dir"
	create_project "default"
	echo "default" > ".tpw-current"
    fi
}

function create_project () {
    echo "Create a new project: $1"
    mkdir -p "$PATCH_DIR$1/v1"
    echo "v1" > "$PATCH_DIR$1/.tpw-ver"
    if [ -e "$DEFAULT_SEND_TO" ]; then
	cp "$DEFAULT_SEND_TO" "$PATCH_DIR$1/.tpw-send-to"
    fi
    if [ -e "$DEFAULT_TARGET_TREE" ]; then
	cp "$DEFAULT_TARGET_TREE" "$PATCH_DIR$1/.tpw-target-tree"
    fi
}

function list_projects () {
    names=$(ls "$PATCH_DIR")
    if [ -e "$LAST_VISITS" ]; then
        for name in $(cat $LAST_VISITS); do
            echo "   $name"
        done
        echo ""
    fi
    for name in $names; do
        if [ -e "$LAST_VISITS" ]; then
            if ! grep -q "^$name$" "$LAST_VISITS"; then
                echo "   $name"
            fi
        else
            echo "   $name"
        fi
    done
}

function replace_pattern () {
    W1="$1"
    W2="$2"
    UPSTREAM=$(git log -n 1  --pretty="%H" "@{upstream}")
    if [ -z $UPSTREAM ]; then
        echo "No upstream branch found"
        exit 1
    fi

    echo "Replace $W1 with $W2 in all patches from $CURRENT_PATCH_DIR"
    FILES=$(ls $CURRENT_PATCH_DIR/*.patch|grep -v 0000-|sort)
    for f in $FILES; do
        sed "/^---\$/,\$s/$W1/$W2/" $f > $f.tmp
        mv $f.tmp $f
    done

    echo "Apply modified patches to $UPSTREAM"
    git checkout -q $UPSTREAM
    git am $FILES
    NEW_COMMIT=$(git log -n 1  --pretty="%H")

    echo "Reset the branch: $NEW_COMMIT"
    git switch -q -
    git reset --hard $NEW_COMMIT
}

function new_version () {
    echo "v$((${CURRENT_VERSION:1}+1))"
}

function extract () {
    if [ -e "$COVER_LETTER" ]; then
	cover-extract.sh "$COVER_LETTER" "$EXTRACTED_COVER"
    fi
}

function show_help () {
    cat <<EOF
$0: (list|ver|ex-cover|....)
    list	list all projects.
    ver		show the current version of the patchset.
    ed-cover	edit the cover-letter.
    ed-patch	edit a given patch.
    update	update the current version of the patchset.
    update-nocover	update the current version of the patchset.
    update-rfc	update the current version of the patchset.
    update-rfc-nocover	update the current version of the patchset.
    swproj	switch to a project.
    checkout    checkout the branch of the current project.
    stick-branch   stick this project to the current GIT branch.
    mkbranch    create a new branch and project and switch to it.
    adv		advance to the next/new version of the patchset.
    check	check patchset.
    send	send the patchset out to the mailing list.
    rcvrs	show receivers of the patchset.
    path	show the path of the current version of the patchset.
    addword	add a new word to the dictionary.
    diff        compare the current patchset with the previous one.
    init	initialize the current working directory with a patch-dir.
    fix		fix a patch with the changes in the working directory.
    fix-cont    continue the failed previous fix.
    lsfix|ls	list commits in the working directory.
    replace     replace a pattern in the patchset.
EOF
}

function visit () {
    echo "$1" > $LAST_VISITS.tmp
    cat $LAST_VISITS | grep -v "^$1$" >> $LAST_VISITS.tmp
    head -n $VISIT_HISTORY_SIZE $LAST_VISITS.tmp > $LAST_VISITS
    rm $LAST_VISITS.tmp
}

shopt -s extglob

case "$COMMAND" in
    help)
	show_help;;
    list)
	list_projects;;
    ver)
	echo "$CURRENT_PROJECT $CURRENT_VERSION";;
    ex-cover)
	extract
	;;
    ed-cover)
	$EDITOR "$COVER_LETTER"
	extract
	rm "${COVER_LETTER}~"
	;;
    ed-patch)
	$EDITOR $CURRENT_PATCH_DIR/*(0)$2-*.patch
	rm $CURRENT_PATCH_DIR/*(0)$2-*.patch~
	;;
    update)
	echo "Update $CURRENT_PROJECT $CURRENT_VERSION"
	if [ x"$CURRENT_VERSION" == x"v1" ]; then
	    PREFIX="PATCH $TARGET_TREE"
	else
	    PREFIX="PATCH $TARGET_TREE $CURRENT_VERSION"
	fi
	rm "$CURRENT_PATCH_DIR"*.patch > /dev/null 2&>1
	git format-patch --cover-letter --subject-prefix="$PREFIX" @{upstream}.. -o "$CURRENT_PATCH_DIR"
	if [ -e "$EXTRACTED_COVER" ]; then
	    cover-fill.sh "$EXTRACTED_COVER" "$COVER_LETTER"
	fi
	;;
    update-nocover)
	echo "Update $CURRENT_PROJECT $CURRENT_VERSION"
	if [ x"$CURRENT_VERSION" == x"v1" ]; then
	    PREFIX="PATCH $TARGET_TREE"
	else
	    PREFIX="PATCH $TARGET_TREE $CURRENT_VERSION"
	fi
	rm "$CURRENT_PATCH_DIR"*.patch > /dev/null 2&>1
	git format-patch --subject-prefix="$PREFIX" @{upstream}.. -o "$CURRENT_PATCH_DIR"
	;;
    update-rfc)
	echo "Update $CURRENT_PROJECT $CURRENT_VERSION"
	if [ x"$CURRENT_VERSION" == x"v1" ]; then
	    PREFIX="RFC $TARGET_TREE"
	else
	    PREFIX="RFC $TARGET_TREE $CURRENT_VERSION"
	fi
	rm "$CURRENT_PATCH_DIR"*.patch > /dev/null 2&>1
	git format-patch --cover-letter --subject-prefix="$PREFIX" @{upstream}.. -o "$CURRENT_PATCH_DIR"
	if [ -e "$EXTRACTED_COVER" ]; then
	    cover-fill.sh "$EXTRACTED_COVER" "$COVER_LETTER"
	fi
	;;
    update-rfc-nocover)
	echo "Update $CURRENT_PROJECT $CURRENT_VERSION"
	if [ x"$CURRENT_VERSION" == x"v1" ]; then
	    PREFIX="RFC $TARGET_TREE"
	else
	    PREFIX="RFC $TARGET_TREE $CURRENT_VERSION"
	fi
	rm "$CURRENT_PATCH_DIR"*.patch > /dev/null 2&>1
	git format-patch --rfc --subject-prefix="$PREFIX" @{upstream}.. -o "$CURRENT_PATCH_DIR"
	;;
    swproj)
	echo "Switch from $CURRENT_PROJECT to $2"
	if [ ! -d "$PATCH_DIR$2" ]; then
	    create_project $2
	fi
	echo "$2" > "$ORIGIN_DIR/.tpw-current"
        NEXT_PROJ_DIR="$PATCH_DIR$2/"
        NEXT_BRANCH="$NEXT_PROJ_DIR/.tpw-branch"
        if [ -e "$NEXT_BRANCH" ]; then
            git checkout $(cat "$NEXT_BRANCH")
        fi
        visit $2
	;;
    checkout)
        BRANCH="$(cat $PROJ_DIR/.tpw-branch)"
        echo "Checkout $BRANCH"
        git checkout "$BRANCH"
        ;;
    stick-branch)
        BR=$(git branch --show-current)
        if [ -n "$BR" ]; then
            echo "Stick to branch \"$BR\""
            echo "$BR" > "$BRANCH"
        else
            echo "No branch to stick to"
        fi
        ;;
    mkbranch)
        BR=$2
        UPSTREAM=$(git branch --show-current)
        NEXT_PROJ_DIR="$PATCH_DIR$BR/"
        NEXT_BRANCH="$NEXT_PROJ_DIR/.tpw-branch"
        if [ ! -d "$NEXT_PROJ_DIR" ]; then
            create_project "$BR"
        else
            echo "Project \"$BR\" already exists"
            return 1
        fi
        git checkout -b "$BR"
        git branch --set-upstream-to="$UPSTREAM"
        echo "$BR" > "$ORIGIN_DIR/.tpw-current"
        echo "$BR" > "$NEXT_BRANCH"
        visit "$BR"
        ;;
    adv)
	NEW_VER=$(new_version)
	mkdir -p "$PROJ_DIR$NEW_VER"
	extract
	echo "$NEW_VER" > "$VER"
	echo "Advance $CURRENT_VERSION to $NEW_VER"
	;;
    check)
	echo "checkpatch.pl"
	echo "--------------------------------------------------"
	./scripts/checkpatch.pl --strict -v "${CURRENT_PATCH_DIR}"*.patch
	echo
	echo "aspell"
	echo "--------------------------------------------------"
	if [ x"$PWS" != x"" ]; then
	    ASPELL_OPTS="--personal=$PWS"
	fi
	cat "${CURRENT_PATCH_DIR}"*.patch | aspell $ASPELL_OPTS list|sort|uniq
	echo "Check make errors"
	echo "--------------------------------------------------"
	make C=1 clean > /dev/null; make olddefconfig > /dev/null; chrt -i 0 make -j$(nproc) W=1 > /dev/null 2> err.log; wc err.log
        make headers &> /dev/null
        make -C tools/testing/selftests/bpf C=1 clean > /dev/null; chrt -i 0 make -C tools/testing/selftests/bpf -j$(nproc) W=1 > /dev/null 2> err-selftests-bpf.log; wc err-selftests-bpf.log
        make -C tools/testing/selftests/net C=1 clean > /dev/null; chrt -i 0 make -C tools/testing/selftests/net -j$(nproc) W=1 > /dev/null 2> err-selftests-net.log; wc err-selftests-net.log
	;;
    send)
	TO=$(cat "$SEND_TO")
	echo "Send $CURRENT_PROJECT"
	echo "To: $TO"
	echo
	if [ x"$TO" == x"" ]; then
	    echo "Please set email addresses: $SEND_TO"
	else
	    rm "$CURRENT_PATCH_DIR"*~ > /dev/null 2&>1
	    git send-email --to="$TO" "$CURRENT_PATCH_DIR"
	fi
	;;
    rcvrs)
	cat "$SEND_TO"
	;;
    auto-rcvrs)
        ./scripts/get_maintainer.pl $CURRENT_PATCH_DIR/*.patch \
            | grep -v linux-kernel@vger.kernel.org | sort \
            | uniq \
            | awk -- '/^[^\>\<]+$/ { gsub(" .*", ""); printf "%s,",$0; } /^.*<.*>.*$/ { gsub("^.*<", ""); gsub(">.*$", ""); printf "%s,", $0; }' \
            | awk -- '{gsub(",$", ""); print $0;}' > "$SEND_TO"
        ;;
    path)
	echo "$CURRENT_PATCH_DIR"
	;;
    path-prev)
	echo "${PROJ_DIR}v$((${CURRENT_VERSION:1}-1))/"
	;;
    addword)
	echo "$2" >> "$PWS"
	cp "$PWS" "${PWS}.bak"
	echo "personal_ws-1.1 en 0" > "$PWS"
	cat "${PWS}.bak"|grep -v personal_ws|sort -f|uniq >> "$PWS"
	echo "DONE"
	;;
    diff)
        diff-patchset.sh
        ;;
    init)
	init_patch_dir $2
	;;
    fix)
	fixup.sh $2 || exit 1
	tpw.sh update
	;;
    fix-cont)
        fixup-cont.sh || exit 1
        tpw.sh update
        ;;
    lsfix|ls)
	git log --oneline "@{upstream}.."|tac|cat -n|tac
	;;
    replace)
        W1="$2"
        W2="$3"
        if [ -z "$W1" ] || [ -z "$W2" ]; then
            echo "Usage: $0 replace <word1> <word2>"
            exit 1
        fi
        replace_pattern "$W1" "$W2"
        ;;
    *)
	show_help
	;;
esac
