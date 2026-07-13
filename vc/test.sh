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
grep -q 'def Resolutions_mulk' GeneratedEvmYul/peano/Peano/mulk_user.lean
grep -q 'ResolvedFunction codeOverride s "addk"' GeneratedEvmYul/peano/Peano/mulk_user.lean
grep -q 'Resolutions_mulk codeOverride →' GeneratedEvmYul/peano/Peano/mulk_user.lean
lake build GeneratedEvmYul
lake build EvmYul.Yul.InterpreterTests

clean_generated

cd "$script_dir"
stack run vc ../EvmYul/Yul/YulSemanticsTests/Caller.yul

cd "$repo_root"
lake build \
  GeneratedEvmYul.Caller.CallerContract.update_byte_slice_shift_user \
  GeneratedEvmYul.Caller.CallerContract.update_byte_slice_shift
