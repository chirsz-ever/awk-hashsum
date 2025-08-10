#!/bin/sh -e

repeat() {
    awk -v s="$1" -v n="$2" 'BEGIN { for (i = 0; i < n; i++) printf("%s", s); }'
}

streq() {
    case $1 in "$2") return; esac
    return 1
}

testmd5() {
    std_output=$(printf '%s' "$1" | md5sum /dev/stdin | awk '{print $1}')
    output=$(printf '%s' "$1" | ./md5sum.sh /dev/stdin | awk '{print $1}')
    posix_output=$(printf '%s' "$1" | POSIXLY_CORRECT=1 ./md5sum.sh /dev/stdin | awk '{print $1}')

    if ! streq "$std_output" "$output"; then
        echo "Output mismatch for \"$1\":"
        echo "md5sum:    $std_output"
        echo "md5sum.sh: $output"
        return 1
    fi

    if ! streq "$std_output" "$posix_output"; then
        echo "POSIX output mismatch for \"$1\":"
        echo "md5sum:    $std_output"
        echo "md5sum.sh: $posix_output"
        return 1
    fi
}

testmd5random() {
    random_data_file=$(mktemp)
    head -c "$1" /dev/urandom > "$random_data_file"
    std_output=$(md5sum "$random_data_file" | awk '{print $1}')
    output=$(./md5sum.sh "$random_data_file" | awk '{print $1}')
    posix_output=$(POSIXLY_CORRECT=1 ./md5sum.sh "$random_data_file" | awk '{print $1}')

    if [ "$std_output" != "$output" ]; then
        echo "Output mismatch for random data in $random_data_file:"
        echo "md5sum:    $std_output"
        echo "md5sum.sh: $output"
        return 1
    fi

    if [ "$std_output" != "$posix_output" ]; then
        echo "POSIX output mismatch for random data in $random_data_file:"
        echo "md5sum:    $std_output"
        echo "md5sum.sh: $posix_output"
        return 1
    fi

    rm -f "$random_data_file"
}

cd "$(dirname "$0")" || exit 1

testmd5 ""
testmd5 "abc"
testmd5 "The quick brown fox jumps over the lazy dog"
testmd5 "$(repeat "a" 10)"
testmd5 "$(repeat "a" 56)"
testmd5 "$(repeat "a" 64)"
testmd5 "$(repeat "a" 65)"
testmd5 "$(repeat "a" 100)"
testmd5 "$(repeat "a" 1000)"
testmd5random 10
testmd5random 56
testmd5random 64
testmd5random 65
testmd5random 100
testmd5random 1000

echo "All tests passed."
