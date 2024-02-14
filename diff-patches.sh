P1=$1
P2=$2

cd tmp
mkdir a
mkdir b

onevdiff.py $P1 |awk -- '/^@@ / { gsub("^@@.*@@", "@@ @@"); print; } /^[^@]/ {print; }' > a/onevdiff-p1
onevdiff.py $P2 |awk -- '/^@@ / { gsub("^@@.*@@", "@@ @@"); print; } /^[^@]/ {print; }' > b/onevdiff-p2

diff -u a/onevdiff-p1 b/onevdiff-p2 > tmp.diff
erdiff.py tmp.diff > tmp2.diff || exit 1
cat tmp2.diff
rm tmp2.diff
rm tmp.diff

rm -rf a b
