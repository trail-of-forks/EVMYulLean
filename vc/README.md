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
