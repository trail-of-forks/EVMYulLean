#!/usr/bin/env sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
corpus_dir="$repo_root/solidity/test/libyul/yulInterpreterTests"

if [ ! -d "$corpus_dir" ]; then
  echo "missing Solidity yulInterpreterTests corpus: $corpus_dir" >&2
  echo "initialize the solidity submodule first" >&2
  exit 1
fi

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT INT TERM

is_expected_pass() {
  case "$1" in
    access_large_memory_offsets.yul|\
    ambiguous_vars.yul|\
    and_create.yul|\
    and_create2.yul|\
    blobbasefee.yul|\
    blobhash.yul|\
    clz.yul|\
    create2.yul|\
    datacopy.yul|\
    dataoffset.yul|\
    datasize.yul|\
    difficulty.yul|\
    exp.yul|\
    external_call_to_self.yul|\
    external_call_unexecuted.yul|\
    external_callcode_unexecuted.yul|\
    external_delegatecall_unexecuted.yul|\
    external_staticcall_unexecuted.yul|\
    hex_literals.yul|\
    loop.yul|\
    long_object_name.yul|\
    mcopy.yul|\
    mcopy_memory_access_out_of_range.yul|\
    mcopy_memory_expansion_on_read.yul|\
    mcopy_memory_expansion_on_write.yul|\
    mcopy_memory_expansion_zero_size.yul|\
    mcopy_overlap.yul|\
    pop_byte_shr_call.yul|\
    prevrandao.yul|\
    self_balance.yul|\
    side_effect_free.yul|\
    simple_mstore.yul|\
    smoke.yul|\
    switch_statement.yul|\
    transient_storage.yul|\
    zero_length_reads.yul|\
    zero_length_reads_and_revert.yul|\
    zero_range.yul)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

fixture_id() {
  basename "$1" .yul | tr -c 'A-Za-z0-9_' '_'
}

strip_expectations() {
  awk '/^\/\/ (----|====)/{exit} {print}' "$1"
}

extract_first_code_block() {
  awk '
    function emit_code(s,    i, ch, start, piece) {
      start = 1
      for (i = 1; i <= length(s); i++) {
        ch = substr(s, i, 1)
        if (ch == "{") {
          depth++
        } else if (ch == "}") {
          if (depth == 1) {
            piece = substr(s, start, i - start)
            if (piece != "") print piece
            done = 1
            exit
          }
          depth--
        }
      }
      piece = substr(s, start)
      if (piece != "") print piece
    }

    !in_code {
      if (match($0, /code[[:space:]]*\{/)) {
        in_code = 1
        depth = 1
        emit_code(substr($0, RSTART + RLENGTH))
      }
      next
    }

    in_code {
      emit_code($0)
    }
  ' "$1"
}

normalize_fixture() {
  input="$1"
  output="$2"
  name=$(fixture_id "$input")

  first_token=$(
    strip_expectations "$input" |
      sed -n 's/^[[:space:]]*\([^[:space:]]\{1,\}\).*$/\1/p' |
      sed -n '1p'
  )

  stripped="$tmp_dir/stripped-$name.yul"
  strip_expectations "$input" > "$stripped"

  if [ "$first_token" = "object" ]; then
    body_source="$tmp_dir/body-$name.yul"
    extract_first_code_block "$stripped" > "$body_source"
    body_is_block=0
  else
    body_source="$stripped"
    body_is_block=1
  fi

  {
    printf 'object "SolidityYulInterpreterTest_%s" {\n' "$name"
    printf '  code {}\n'
    printf '  object "SolidityYulInterpreterTest_%s_deployed" {\n' "$name"
    printf '    code {\n'
    printf '      function main() '
    if [ "$body_is_block" -eq 1 ]; then
      cat "$body_source"
    else
      printf '{\n'
      cat "$body_source"
      printf '      }\n'
    fi
    printf '    }\n'
    printf '    data ".metadata" hex"00"\n'
    printf '  }\n'
    printf '}\n'
  } > "$output"
}

total=0
passed=0
failed=0
expected_pass_failed=0
known_unsupported_passed=0

for yul_file in "$corpus_dir"/*.yul; do
  total=$((total + 1))
  base=$(basename "$yul_file")
  normalized="$tmp_dir/$base"
  stdout="$tmp_dir/$base.stdout"
  stderr="$tmp_dir/$base.stderr"

  normalize_fixture "$yul_file" "$normalized"

  if (cd "$script_dir" && stack run vc "$normalized") > "$stdout" 2> "$stderr"; then
    passed=$((passed + 1))
    if is_expected_pass "$base"; then
      printf 'PASS     %s\n' "$base"
    else
      known_unsupported_passed=$((known_unsupported_passed + 1))
      printf 'IMPROVED %s\n' "$base"
    fi
  else
    failed=$((failed + 1))
    reason=$(sed -n '1p' "$stderr")
    if is_expected_pass "$base"; then
      expected_pass_failed=$((expected_pass_failed + 1))
      printf 'REGRESS  %s :: %s\n' "$base" "$reason"
    else
      printf 'UNSUP    %s :: %s\n' "$base" "$reason"
    fi
  fi
done

printf '\n'
printf 'Solidity yulInterpreterTests VC-generation baseline:\n'
printf '  total:                  %s\n' "$total"
printf '  generated:              %s\n' "$passed"
printf '  unsupported/failing:    %s\n' "$failed"
printf '  expected-pass failures: %s\n' "$expected_pass_failed"
printf '  newly passing:          %s\n' "$known_unsupported_passed"

if [ "$expected_pass_failed" -ne 0 ]; then
  exit 1
fi
