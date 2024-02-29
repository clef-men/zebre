## Building

Assuming that you have [opam](https://opam.ocaml.org/) (>= 2.0) installed, run the following commands, which create a local opam switch, install dependencies and compile Coq proofs:

```
opam update --all --repositories
opam switch create . --yes --deps-only --repos default,coq-released=https://coq.inria.fr/opam/released,iris-dev=git+https://gitlab.mpi-sws.org/iris/opam.git
eval $(opam env)
make
```

## Evaluating

The main file of interest is `theories/store.v` containing:

| Rule    | Lemma                |
|---------|----------------------|
| Create  | `store_create_spec`  |
| Ref     | `store_ref_spec`     |
| Get     | `store_get_spec`     |
| Set     | `store_set_spec`     |
| Capture | `store_capture_spec` |
| Restore | `store_restore_spec` |
