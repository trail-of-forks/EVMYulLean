# Peano proof snapshots

These files preserve the completed user proofs for `vc/examples/peano.yul`.

The VC generator writes corresponding files under `GeneratedEvmYul/`, which is
ignored and may be deleted by `vc/test.sh`. After regenerating Peano, copy these
snapshots back to the matching generated paths if you want to restore the
completed proofs:

- `addk_user.lean` -> `GeneratedEvmYul/peano/Peano/addk_user.lean`
- `mulk_user.lean` -> `GeneratedEvmYul/peano/Peano/mulk_user.lean`
- `Common/for_1843992510614721784_user.lean` -> `GeneratedEvmYul/peano/Peano/Common/for_1843992510614721784_user.lean`
- `Common/for_8649752910240518373_user.lean` -> `GeneratedEvmYul/peano/Peano/Common/for_8649752910240518373_user.lean`
