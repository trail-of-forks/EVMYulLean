#!/usr/bin/env sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)

clean_generated() {
  rm -rf "$repo_root/GeneratedEvmYul" "$repo_root/GeneratedEvmYul.lean"
}

clean_generated

cd "$script_dir"
stack run vc examples/peano.yul

cd "$repo_root"
lake build GeneratedEvmYul

clean_generated

cd "$script_dir"
stack run vc ../EvmYul/Yul/YulSemanticsTests/Caller.yul

cd "$repo_root"
lake build \
  GeneratedEvmYul.Caller.CallerContract.update_byte_slice_shift_user \
  GeneratedEvmYul.Caller.CallerContract.update_byte_slice_shift
