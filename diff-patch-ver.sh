V1=$1
V2=$2
PATCH_IDX=$3

P1=$(env OVERRIDE_VERSION=$V1 tpw.sh path)/*0${PATCH_IDX}-*patch
P2=$(env OVERRIDE_VERSION=$V2 tpw.sh path)/*0${PATCH_IDX}-*patch

cd tmp
mkdir a
mkdir b

onevdiff.py $P1 |awk -- '/^@@ / { gsub("^@@.*@@", "@@ @@"); print; } /^[^@]/ {print; }' > a/onevdiff-$V1
onevdiff.py $P2 |awk -- '/^@@ / { gsub("^@@.*@@", "@@ @@"); print; } /^[^@]/ {print; }' > b/onevdiff-$V2

diff -u a/onevdiff-$V1 b/onevdiff-$V2 > tmp.diff
erdiff.py tmp.diff > tmp2.diff || exit 1
if [ -z "$NO_TMP" ]; then
    mv tmp2.diff ../tmp.diff
else
    cat tmp2.diff
    rm tmp2.diff
fi
rm tmp.diff

rm -rf a b
