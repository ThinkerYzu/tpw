SAVED_FILE=$1
COVER_FILE=$2
. $SAVED_FILE
PROG=$(cat <<EOF
{
   sub("\\\\*\\\\*\\\\* SUBJECT HERE \\\\*\\\\*\\\\*", SUBJECT);
   sub("\\\\*\\\\*\\\\* SUBJECT HERE \\\\*\\\\*\\\\*", "\\\\&");
   sub("\\\\*\\\\*\\\\* BLURB HERE \\\\*\\\\*\\\\*", BODY)
   print \$0
}
EOF
)
awk -v SUBJECT="$SUBJECT" -v BODY="$BODY" -- "$PROG" $COVER_FILE > ${COVER_FILE}.tmp

mv ${COVER_FILE}.tmp $COVER_FILE
