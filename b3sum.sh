#!/bin/sh -e

null() { case $1 in '') return 0; esac; return 1; }

usage() {
    echo "Usage: $(basename "$0") [--tag] [FILE]..."
    echo "Calculate the BLAKE3 checksum of the given files."
    echo "If no files are given, or argument is -, read from standard input."
}

# process options
bsd_foramt=0
s=0
length=32
for arg in "$@"; do
    case $s in
    0)
        case $arg in
        -)  continue;;
        --) break;;
        --help|-h)
            usage
            exit 0;;
        --tag)
            bsd_foramt=1;;
        --length|-l)
            s=1;;
        -*)
            echo "Unknown option: $arg" >&2
            echo "Use --help for usage information." >&2
            exit 1;;
        esac
        ;;
    1)
        if echo "$arg" | grep -Eq '^[1-9][0-9]*$'; then
            length=$arg
        else
            echo "invalid length: $arg"
            exit 1
        fi
        s=0
        ;;
    esac
done

case $s in 0);;*)
    echo "-l/--length should follow a argument"
    exit 1
esac

# use built-in bitwise functions if available.
sed_cmd='1,/^#_AWK_BEGIN_$/s/^.*$//'
sed_cmd_buitin_bitwise='/^#_POSIX_BEGIN_$/,/^#_POSIX_END_$/s/^.*$//'
null "${DEBUG-}" && {
    sed_cmd_debug='/^#_DEBUG_BEGIN_$/,/^#_DEBUG_END_$/s/^.*$//'
    sed_cmd=$sed_cmd\;$sed_cmd_debug
}
ty=
case $(awk --version 2>&1 | cat) in
*'GNU Awk'*) ty=gnu;;
*BusyBox*) ty=busybox;;
esac
case $ty in
gnu)
    # if POSIXLY_CORRECT is not an environment variable, or is empty
    if ! { env | grep -q '^POSIXLY_CORRECT='; } || null "${POSIXLY_CORRECT-}"; then
        sed_cmd=$sed_cmd\;$sed_cmd_buitin_bitwise
    fi;;
busybox)
    # BusyBox awk always uses built-in bitwise functions.
    sed_cmd=$sed_cmd\;$sed_cmd_buitin_bitwise
esac

awk_script="$(sed "$sed_cmd" "$0")"
run_once=
run_once_on() {
    if [ "$1" != '-' ] && [ ! -r "$1" ]; then
        echo "Cannot read file: $1" >&2
        exit 1
    fi
    case $1 in -)
        od -v -A n -t u1 | awk -v fname="$1" -v bsd_foramt="$bsd_foramt" -v out_len="$length" "$awk_script";;
    *)
        od -v -A n -t u1 -- "$1" | awk -v fname="$1" -v bsd_foramt="$bsd_foramt" -v out_len="$length" "$awk_script";;
    esac
    run_once=1
}

options_end=
for arg do
    case $options_end in
    1)
        run_once_on "$arg"
        continue
    esac

    case $arg in
    -)  run_once_on -;;
    --) options_end=1;;
    -*) continue;;
    *)  run_once_on "$arg";;
    esac
done
case $run_once in '')
    # no files given, read from stdin.
    run_once_on -
esac
exit $?

# a trick to suppress shellcheck warnings.
# shellcheck disable=SC2317
: <<'#_AWK_END_'
#_AWK_BEGIN_

BEGIN {
#_POSIX_BEGIN_
    _bitwise_init();
#_POSIX_END_
    _b3_init();
}

# globals: IV, chunk_buffer, bytes_count, chunk_t, cv_stack, cv_stack_top

{
    # Every 1024 bytes, run a round.
    # This avoid memory issues with large files.
    for (i = 1; i <= NF; ++i) {
        push_byte($(i));
    }
}

END {
    hashstr = finalize();

    if (bsd_foramt) {
        printf("BLAKE3 (%s) = %s\n", fname, hashstr);
    } else {
        printf("%s  %s\n", hashstr, fname);
    }
}

function _b3_init() {
    IV[0] = 1779033703; # 0x6a09e667
    IV[1] = 3144134277; # 0xbb67ae85
    IV[2] = 1013904242; # 0x3c6ef372
    IV[3] = 2773480762; # 0xa54ff53a
    IV[4] = 1359893119; # 0x510e527f
    IV[5] = 2600822924; # 0x9b05688c
    IV[6] =  528734635; # 0x1f83d9ab
    IV[7] = 1541459225; # 0x5be0cd19

    CHUNK_START = 1;
    CHUNK_END   = 2;
    PARENT      = 4;
    ROOT        = 8;

    U32_MAX = 4294967296;

    bytes_count = 0;
    chunk_t = 0;
    cv_stack_top = 0;
}

function copy_array(dst, src, start, len,  d, s) {
    d = 0;
    s = start;
    while (d < len) {
        dst[d] = src[s];
        ++d;
        ++s;
    }
}

function cv_stack_pop(dst,  d, s) {
    cv_stack_top -= 8;
    d = 0;
    s = cv_stack_top;
    while (d < 8) {
        dst[d] = cv_stack[s];
        ++d;
        ++s;
    }
}

function cv_stack_push(cv,  d, s) {
    d = 0;
    s = cv_stack_top;
    while (d < 8) {
        cv_stack[s] = cv[d];
        ++d;
        ++s;
    }
    cv_stack_top += 8;
}

function merge_block(m, cv1, cv2,  i, j) {
    i = 0;
    j = 8;
    while (i < 8) {
        m[i] = cv1[i];
        m[j] = cv2[i];
        ++i;
        ++j;
    }
}

function extend_array(dst, src, dst_off, n,  d, s) {
    s = 0;
    d = dst_off;
    while (s < n) {
        dst[d] = src[s];
        ++d;
        ++s;
    }
}

function push_byte(b,  cv) {
    if (bytes_count >= 1024 && bytes_count % 1024 == 0) {
        make_new_leave_cv(cv);
        add_chunk_chaining_value(cv);
        ++chunk_t;
    }
    chunk_buffer[bytes_count % 1024] = b;
    ++bytes_count;
}

function make_new_leave_cv(cv,  i, block, d, m, h1) {
    copy_array(cv, IV, 0, 8);
    for (i = 0; i < 1024; i += 64) {
        d = i == 0 ? CHUNK_START : 0;
        d += i == 960 ? CHUNK_END : 0;
        split_message_block(m, i);
        copy_array(h1, cv, 0, 8);
        compress(cv, h1, m, chunk_t, 64, d);
    }
}

function split_message_block(m, off,  i, j) {
    for (i = 0; i < 16; ++i) {
        j = off + i * 4;
        m[i] = chunk_buffer[j] + chunk_buffer[j + 1] * 256 + chunk_buffer[j + 2] * 65536 + chunk_buffer[j + 3] * 16777216;
    }
}

function add_chunk_chaining_value(cv,  total_chunks, m, top_cv) {
    total_chunks = chunk_t + 1;
    while (total_chunks % 2 == 0) {
        cv_stack_pop(top_cv);
        merge_block(m, top_cv, cv);
        compress(cv, IV, m, 0, 64, PARENT)
        total_chunks = int(total_chunks / 2);
    }
    cv_stack_push(cv);
}

# NOTE: m would change
function compress(result, h, m, t, b, d, extend,  v, i) {
    v[0] = h[0];
    v[1] = h[1];
    v[2] = h[2];
    v[3] = h[3];
    v[4] = h[4];
    v[5] = h[5];
    v[6] = h[6];
    v[7] = h[7];
    v[8]  = IV[0];
    v[9]  = IV[1];
    v[10] = IV[2];
    v[11] = IV[3];
    # NOTE: only support 32-bit length, or 4GiB
    v[12] = t;
    v[13] = 0;
    v[14] = b;
    v[15] = d;

#_DEBUG_BEGIN_
    printf("compress: t=%d, b=%d, d=%02x\n", t, b, d);
    printf("  h:\n  ");
    for (i = 0; i < 8; ++i) {
        printf("%08x ", h[i]);
        if (i == 7) printf("\n");
    }
    printf("  m:\n  ");
    for (i = 0; i < 16; ++i) {
        printf("%08x ", m[i]);
        if (i == 7) printf("\n  ");
        if (i == 15) printf("\n");
    }
#_DEBUG_END_

    round_(m, v);
    permute(m);
    round_(m, v);
    permute(m);
    round_(m, v);
    permute(m);
    round_(m, v);
    permute(m);
    round_(m, v);
    permute(m);
    round_(m, v);
    permute(m);
    round_(m, v);

    for (i = 0; i < 8; ++i) {
        result[i] = xor(v[i], v[i+8]);
    }
    if (extend) {
        for (i = 8; i < 16; ++i) {
            result[i] = xor(v[i], h[i-8]);
        }
    }
}

function round_(m, v) {
    G(0, m, v, 0, 4,  8, 12);
    G(1, m, v, 1, 5,  9, 13);
    G(2, m, v, 2, 6, 10, 14);
    G(3, m, v, 3, 7, 11, 15);
    G(4, m, v, 0, 5, 10, 15);
    G(5, m, v, 1, 6, 11, 12);
    G(6, m, v, 2, 7,  8, 13);
    G(7, m, v, 3, 4,  9, 14);
}

function G(i, m, v, a, b, c, d) {
    v[a] = (v[a] + v[b] + m[2 * i]) % U32_MAX;
    v[d] = ROTATE_RIGHT(xor(v[d], v[a]), 16);
    v[c] = (v[c] + v[d]) % U32_MAX;
    v[b] = ROTATE_RIGHT(xor(v[b], v[c]), 12);
    v[a] = (v[a] + v[b] + m[2 * i + 1]) % U32_MAX;
    v[d] = ROTATE_RIGHT(xor(v[d], v[a]), 8);
    v[c] = (v[c] + v[d]) % U32_MAX;
    v[b] = ROTATE_RIGHT(xor(v[b], v[c]), 7);
}

function permute(m,  m0, m1) {
    m0 = m[0];
    m[0]  = m[2];
    m[2]  = m[3];
    m[3]  = m[10];
    m[10] = m[12];
    m[12] = m[9];
    m[9]  = m[11];
    m[11] = m[5];
    m[5]  = m0;

    m1 = m[1];
    m[1]  = m[6];
    m[6]  = m[4];
    m[4]  = m[7];
    m[7]  = m[13];
    m[13] = m[14];
    m[14] = m[15];
    m[15] = m[8];
    m[8]  = m1;
}

function finalize(  total_blocks, last_h, last_m, last_t, last_b, last_d, i, h, is_root, cv, m) {
    copy_array(last_h, IV, 0, 8);
    for (i = 0; i < 16; ++i)
        last_m[i] = 0;
    last_t = 0;
    last_b = 0;
    last_d = 0;

    if (bytes_count == 0) {
        last_d = CHUNK_START + CHUNK_END + ROOT;
        compress(h, IV, last_m, last_t, last_b, last_d, 1);
    } else if (bytes_count <= 1024) {
        get_last_block(last_m);
        last_b = bytes_count % 64;
        last_b = last_b == 0 ? 64 : last_b;
        last_d = ROOT + CHUNK_END + (bytes_count <= 64 ? CHUNK_START : 0);
        compress_last_chunk(h, last_h, 1)
    } else {
        compress_last_chunk(h, last_h, 0);

        last_b = 64;
        last_d = PARENT;
        copy_array(last_h, IV, 0, 8);
        while (cv_stack_top != 0) {
            cv_stack_pop(cv);
            is_root = cv_stack_top == 0;
            merge_block(m, cv, h);
            if (is_root) {
                last_d += ROOT;
                copy_array(last_m, m, 0, 16);
            }
            compress(h, IV, m, 0, 64, last_d, is_root);
        }
    }

    # Extendable output
    total_blocks = int((out_len + 63) / 64);
    h_len = 16;
    while (total_blocks > 1) {
        last_t += 1;
        copy_array(m, last_m, 0, 16);
        compress(h1, last_h, m, last_t, last_b, last_d, 1);
        extend_array(h, h1, h_len, 16);
        h_len += 16;
        total_blocks -= 1;
    }
    return format_output(h, out_len);
}

function compress_last_chunk(h, last_h, is_root,  m, i, l, block_extend, b, d) {
    l = bytes_count % 1024;
    l = l == 0 ? 1024 : l;
    block_extend = 0;
    copy_array(h, IV, 0, 8);
    for (i = 0; i < l; i += 64) {
        b = 64;
        d = i == 0 ? CHUNK_START : 0;
        if (i + 64 >= l) {
            b = l - i;
            d += CHUNK_END;
            d += is_root ? ROOT : 0;
            block_extend = is_root;
            for (j = l; j < i + 64; ++j) {
                chunk_buffer[j] = 0;
            }
        }
        split_message_block(m, i);
        copy_array(last_h, h, 0, 8);
        compress(h, last_h, m, chunk_t, b, d, block_extend);
    }
}

function get_last_block(m,  off, r) {
    # 0 < bytes_count <= 1024
    r = bytes_count % 64;
    r = r == 0 ? 64 : r;
    off = bytes_count - r;
    # no need to set zero padding, chunk_buffer is uninitialized.
    split_message_block(m, off);
}

function format_output(h, out_len,  i, r, hi) {
    r = "";
    for (i = 0; i < out_len;) {
        hi = h[i / 4];
        r = r sprintf("%02x", hi % 256);
        ++i;
        if (i < out_len)
            r = r sprintf("%02x", (hi / 256) % 256);
        ++i;
        if (i < out_len)
            r = r sprintf("%02x", (hi / 65536) % 256);
        ++i;
        if (i < out_len)
            r = r sprintf("%02x", (hi / 16777216) % 256);
        ++i;
    }
    return r;
}

function ROTATE_RIGHT(x, n,    l, r) {
    l = lshift(x, 32 - n) % U32_MAX;
    r = rshift(x, n);
    return (r + l);
}

# Busybox's built-in `compl` has a problem, so we use xor(x, 0xffffffff) instead.
# see https://lists.busybox.net/pipermail/busybox/2022-September/089902.html
function compl32(x) {
    return xor(x, 4294967295); # 0xffffffff
}

#_POSIX_BEGIN_

function lshift(x, n) {
    return x % (2 ^ (32 - n)) * (2 ^ n);
}

function rshift(x, n) {
    return int(x / (2 ^ n));
}

function and(x, y,    i, r) {
    for (i = 0; i < 32; i += 4) {
        r = r / (2 ^ 4) + lookup["and", x % 16, y % 16] * (2 ^ 28);
        x = int(x / (2 ^ 4));
        y = int(y / (2 ^ 4));
    }
    return r;
}

function or(x, y,    i, r) {
    for (i = 0; i < 32; i += 4) {
        r = r / (2 ^ 4) + lookup["or", x % 16, y % 16] * (2 ^ 28);
        x = int(x / (2 ^ 4));
        y = int(y / (2 ^ 4));
    }
    return r;
}

function xor(x, y) {
    return (x + y - 2 * and(x, y));
}

function _bitwise_init(    a, b, x, y, i) {
    # generate the lookup table used by and() and or().
    for (a = 0; a < 16; a++) {
        for (b = 0; b < 16; b++) {
            x = a;
            y = b;
            for (i = 0; i < 4; i++) {
                lookup["and", a, b] += ((x % 2) && (y % 2)) * (2 ^ i);
                lookup["or",  a, b] += ((x % 2) || (y % 2)) * (2 ^ i);
                x = int(x / 2);
                y = int(y / 2);
            }
        }
    }
}

#_POSIX_END_
#_AWK_END_
