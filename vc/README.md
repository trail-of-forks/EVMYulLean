# VC Generator

This directory contains the Clear-style verification condition generator ported to
emit EVMYulLean-compatible Lean files.

The generator writes Lean output to `GeneratedEvmYul.lean` and
`GeneratedEvmYul/` at the repository root. Those files are generated artifacts and
are intentionally ignored by git.

## Generate and Check VCs

From this directory, run the generator on the included Peano example:

```sh
stack run vc examples/peano.yul
```

Then return to the repository root and ask Lake to check the generated Lean
library:

```sh
cd ..
lake build GeneratedEvmYul
```

`GeneratedEvmYul` is a Lake library target, but it only exists after the
generator has produced `GeneratedEvmYul.lean` and `GeneratedEvmYul/`.

You can replace `examples/peano.yul` with another Yul file path to generate VCs
for a different input.

## Solidity Yul Interpreter Corpus

If the `solidity` submodule is initialized, the VC generator can be smoke-tested
against Solidity's `test/libyul/yulInterpreterTests` corpus:

```sh
sh vc/test-solidity-yul-interpreter.sh
```

The harness strips Solidity's `// ----` expected-output sections and `// ====`
configuration sections. It wraps standalone Yul blocks in a synthetic `main`
function inside a Yul object, and for object-shaped fixtures it extracts the
first `code { ... }` block before wrapping that code as `main`, because the VC
generator expects a narrow object-shaped compiler-output form.

This is a generation baseline, not a claim that the VC generator supports all of
Solidity's Yul corpus. At the time this harness was added, 38 of the 51 top-level
`yulInterpreterTests/*.yul` fixtures generated successfully; unsupported
fixtures are reported as `UNSUP`, while regressions in the expected-pass set are
reported as `REGRESS` and cause a nonzero exit.
