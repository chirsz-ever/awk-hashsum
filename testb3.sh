#!/bin/sh -e

repeat() {
    awk -v s="$1" -v n="$2" 'BEGIN { for (i = 0; i < n; i++) printf("%s", s); }'
}

streq() {
    case $1 in "$2") return; esac
    return 1
}

testb3() {
    std_output=$(printf '%s' "$1" | b3sum)
    output=$(printf '%s' "$1" | ./b3sum.sh)
    posix_output=$(printf '%s' "$1" | POSIXLY_CORRECT=1 ./b3sum.sh)

    if ! streq "$std_output" "$output"; then
        echo "Output mismatch for \"$1\":"
        echo "b3sum:    $std_output"
        echo "b3sum.sh: $output"
        return 1
    fi

    if ! streq "$std_output" "$posix_output"; then
        echo "POSIX output mismatch for \"$1\":"
        echo "b3sum:    $std_output"
        echo "b3sum.sh: $posix_output"
        return 1
    fi
}

testb3random() {
    random_data_file=$(mktemp)
    head -c "$1" /dev/urandom > "$random_data_file"
    std_output=$(b3sum "$random_data_file")
    output=$(./b3sum.sh "$random_data_file")
    posix_output=$(POSIXLY_CORRECT=1 ./b3sum.sh "$random_data_file")

    if [ "$std_output" != "$output" ]; then
        echo "Output mismatch for random data in $random_data_file:"
        echo "b3sum:    $std_output"
        echo "b3sum.sh: $output"
        return 1
    fi

    if [ "$std_output" != "$posix_output" ]; then
        echo "POSIX output mismatch for random data in $random_data_file:"
        echo "b3sum:    $std_output"
        echo "b3sum.sh: $posix_output"
        return 1
    fi

    rm -f "$random_data_file"
}

testb3len() {
    std_output=$(repeat "$1" "$2" | b3sum)
    output=$(repeat "$1" "$2" | ./b3sum.sh)
    posix_output=$(repeat "$1" "$2" | POSIXLY_CORRECT=1 ./b3sum.sh)

    if [ "$std_output" != "$output" ]; then
        echo "Output mismatch for random data in repeat \"$1\" $2 times:"
        echo "b3sum:    $std_output"
        echo "b3sum.sh: $output"
        return 1
    fi

    if [ "$std_output" != "$posix_output" ]; then
        echo "POSIX output mismatch for random data in repeat \"$1\" $2 times:"
        echo "b3sum:    $std_output"
        echo "b3sum.sh: $posix_output"
        return 1
    fi

    rm -f "$random_data_file"
}

testb3args() {
    stdin_content="$1"
    shift
    std_output=$(printf '%s' "$stdin_content" | b3sum "$@")
    output=$(printf '%s' "$stdin_content" | ./b3sum.sh "$@")
    posix_output=$(printf '%s' "$stdin_content" | POSIXLY_CORRECT=1 ./b3sum.sh "$@")

    if ! streq "$std_output" "$output"; then
        echo "Output mismatch for \"$stdin_content\" with args \"$*\":"
        echo "b3sum:    $std_output"
        echo "b3sum.sh: $output"
        return 1
    fi

    if ! streq "$std_output" "$posix_output"; then
        echo "POSIX output mismatch for \"$stdin_content\" with args \"$*\":"
        echo "b3sum:    $std_output"
        echo "b3sum.sh: $posix_output"
        return 1
    fi
}

cd "$(dirname "$0")" || exit 1

testb3 ""
testb3 "IETF"
testb3 "abc"
testb3 "The quick brown fox jumps over the lazy dog"
testb3len "a" 10
testb3len "a" 55
testb3len "a" 56
for l in 64 100 1000 1024 2048 4096 8192 10000 16384; do
    testb3len "a" "$((l-2))"
    testb3len "a" "$((l-1))"
    testb3len "a" "$l"
    testb3len "a" "$((l+1))"
    testb3len "a" "$((l+2))"
done
testb3random 10
testb3random 56
testb3random 64
testb3random 65
testb3random 100
testb3random 1000
testb3args '' -
testb3args 'abc' -
testb3args 'abc' - -
testb3args 'abc' --tag
testb3args 'abc' --tag -
testb3args 'abc' --tag - -

echo "All tests passed."
