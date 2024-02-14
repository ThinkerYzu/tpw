COVER_FILE=$1
SAVED_FILE=$2

PROG=$(cat <<EOF
BEGIN { main = 0; }
/^Kui-Feng Lee \\(.*\\):\$/ {
	print "EOF"
	print ")"
	exit 0
}
main == 2 {
     	print LAST
}
main >= 1 {
        gsub(/\\\\/, "\\\\\\\\")
        gsub(/\\\\/, "\\\\\\\\")
        gsub(/\\\\$/, "\\\\\\\\n\\\\")
        gsub(/&/, "\\\\\\\\&")
        gsub(/&/, "\\\\\\\\&")
        gsub(/&/, "\\\\\\\\&")
        gsub(/&/, "\\\\\\\\&")
	LAST=\$0;
	main=2
}
match(\$0, /^Subject: \\[[^\\]]*\\] (.*)/,a) {
	print "SUBJECT='" a[1] "'";
}
/^\$/ && main ==0 {
	main = 1
	print "BODY=\$(cat <<EOF"
}
EOF
    )

awk -- "$PROG" "$COVER_FILE" > "$SAVED_FILE"
