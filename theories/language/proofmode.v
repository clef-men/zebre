From iris.proofmode Require Import
  coq_tactics
  reduction
  spec_patterns.

From zebra Require Import
  prelude.
From zebra.iris Require Import
  diaframe.
From zebra.iris.program_logic Require Import
  atomic.
From zebra.language Require Export
  tactics
  rules.
From zebra.language Require Import
  notations.
From zebra Require Import
  options.

Implicit Types l : loc.
Implicit Types e : expr.
Implicit Types v : val.
Implicit Types K : ectx.

Section zebra_G.
  Context `{zebra_G : !ZebraG Σ}.

  Implicit Types Φ : val → iProp Σ.

  Lemma tac_wp_expr_eval Δ e e' E Φ :
    (∀ (e'' := e'), e = e'') →
    envs_entails Δ (WP e' @ E {{ Φ }}) →
    envs_entails Δ (WP e @ E {{ Φ }}).
  Proof.
    intros ->. done.
  Qed.

  Lemma tac_wp_pure Δ Δ' K e1 e2 ϕ n E Φ :
    PureExec ϕ n e1 e2 →
    ϕ →
    MaybeIntoLaterNEnvs n Δ Δ' →
    envs_entails Δ' (WP (fill K e2) @ E {{ Φ }}) →
    envs_entails Δ (WP (fill K e1) @ E {{ Φ }}).
  Proof.
    rewrite envs_entails_unseal => Hexec Hϕ HΔ HΔ'.
    pose proof @pure_exec_fill. rewrite -lifting.wp_pure_step_later //.
    rewrite into_laterN_env_sound HΔ'.
    iSteps.
  Qed.
  Lemma tac_wp_pure_credit Δ Δ' id K e1 e2 ϕ E Φ :
    PureExec ϕ 1 e1 e2 →
    ϕ →
    MaybeIntoLaterNEnvs 1 Δ Δ' →
    match envs_app false (Esnoc Enil id (£ 1)) Δ' with
    | Some Δ'' =>
        envs_entails Δ'' (WP fill K e2 @ E {{ Φ }})
    | None =>
        False
    end →
    envs_entails Δ (WP (fill K e1) @ E {{ Φ }}).
  Proof.
    rewrite envs_entails_unseal => Hexec Hϕ HΔ HΔ''.
    destruct (envs_app _ _ _) as [Δ'' |] eqn:HΔ'; last done.
    pose proof @pure_exec_fill. rewrite -lifting.wp_pure_step_later //=.
    rewrite into_laterN_env_sound envs_app_sound //= HΔ''.
    iSteps.
  Qed.

  Lemma tac_wp_value_nofupd Δ v E Φ :
    envs_entails Δ (Φ v) →
    envs_entails Δ (WP (Val v) @ E {{ Φ }}).
  Proof.
    rewrite envs_entails_unseal => ->.
    apply: wp_value.
  Qed.
  Lemma tac_wp_value Δ v E Φ :
    envs_entails Δ (|={E}=> Φ v) →
    envs_entails Δ (WP (Val v) @ E {{ Φ }}).
  Proof.
    rewrite envs_entails_unseal => ->.
    rewrite wp_value_fupd //.
  Qed.

  Lemma tac_wp_bind K Δ e (f : expr → expr) E Φ :
    f = (λ e, fill K e) →
    envs_entails Δ (WP e @ E {{ v, WP f (Val v) @ E {{ Φ }} }})%I →
    envs_entails Δ (WP fill K e @ E {{ Φ }}).
  Proof.
    rewrite envs_entails_unseal => -> ->.
    apply: wp_bind.
  Qed.

  Lemma tac_wp_alloc Δ Δ' id K n v E Φ :
    (0 < n)%Z →
    MaybeIntoLaterNEnvs 1 Δ Δ' →
    ( ∀ l,
      match envs_app false (Esnoc Enil id (l ↦∗ replicate (Z.to_nat n) v)) Δ' with
      | Some Δ'' =>
          envs_entails Δ'' (WP fill K #l @ E {{ Φ }})
      | None =>
          False
      end
    ) →
    envs_entails Δ (WP fill K (Alloc #n v) @ E {{ Φ }}).
  Proof.
    rewrite envs_entails_unseal => Hn HΔ HΔ''.
    rewrite into_laterN_env_sound.
    iIntros "HΔ'".
    iApply wp_bind.
    iApply (wp_alloc with "[//]"); first done. iIntros "!> %l (_ & Hl)".
    specialize (HΔ'' l). destruct (envs_app _ _ _) as [Δ'' |] eqn:HΔ'; last done.
    rewrite -HΔ'' envs_app_sound //= right_id.
    iApply ("HΔ'" with "Hl").
  Qed.
  Lemma tac_wp_ref Δ Δ' id K v E Φ :
    MaybeIntoLaterNEnvs 1 Δ Δ' →
    ( ∀ l,
      match envs_app false (Esnoc Enil id (l ↦ v)) Δ' with
      | Some Δ'' =>
          envs_entails Δ'' (WP fill K #l @ E {{ Φ }})
      | None =>
          False
      end
    ) →
    envs_entails Δ (WP fill K (ref v) @ E {{ Φ }}).
  Proof.
    rewrite envs_entails_unseal => HΔ HΔ''.
    rewrite into_laterN_env_sound -wp_bind.
    iIntros "HΔ'".
    iApply (wp_alloc with "[//]"); first done. iIntros "!> %l (_ & Hl)".
    specialize (HΔ'' l). destruct (envs_app _ _ _) as [Δ'' |] eqn:HΔ'; last done.
    rewrite -HΔ'' envs_app_sound //= !right_id loc_add_0.
    iApply ("HΔ'" with "Hl").
  Qed.

  Lemma tac_wp_load Δ Δ' id K l dq v E Φ :
    MaybeIntoLaterNEnvs 1 Δ Δ' →
    envs_lookup id Δ' = Some (false, l ↦{dq} v)%I →
    envs_entails Δ' (WP fill K v @ E {{ Φ }}) →
    envs_entails Δ (WP fill K !#l @ E {{ Φ }}).
  Proof.
    rewrite envs_entails_unseal => HΔ Hlookup HΔ'.
    rewrite into_laterN_env_sound -wp_bind envs_lookup_split //= HΔ'.
    iIntros "(Hl & H)".
    iApply (wp_load with "Hl").
    iSteps.
  Qed.

  Lemma tac_wp_store Δ Δ' id K l v w E Φ :
    MaybeIntoLaterNEnvs 1 Δ Δ' →
    envs_lookup id Δ' = Some (false, l ↦ w)%I →
    match envs_simple_replace id false (Esnoc Enil id (l ↦ v)) Δ' with
    | Some Δ'' =>
        envs_entails Δ'' (WP fill K #() @ E {{ Φ }})
    | None =>
        False
    end →
    envs_entails Δ (WP fill K (#l <- v) @ E {{ Φ }}).
  Proof.
    rewrite envs_entails_unseal => HΔ Hlookup HΔ'.
    destruct (envs_simple_replace _ _ _ _) as [Δ'' |] eqn:HΔ''; last done.
    rewrite into_laterN_env_sound -wp_bind envs_simple_replace_sound //= HΔ'.
    iIntros "(Hl & H)".
    iApply (wp_store with "Hl").
    iSteps.
  Qed.

  Lemma tac_wp_cas Δ Δ' id K l v v1 v2 E Φ :
    MaybeIntoLaterNEnvs 1 Δ Δ' →
    envs_lookup id Δ' = Some (false, l ↦ v)%I →
    val_comparable v v1 →
    match envs_simple_replace id false (Esnoc Enil id (l ↦ v2)) Δ' with
    | Some Δ'' =>
        v = v1 →
        envs_entails Δ'' (WP fill K #true @ E {{ Φ }})
    | None =>
        False
    end →
    ( v ≠ v1 →
      envs_entails Δ' (WP fill K #false @ E {{ Φ }})
    ) →
    envs_entails Δ (WP fill K (Cas #l v1 v2) @ E {{ Φ }}).
  Proof.
    rewrite envs_entails_unseal => HΔ Hlookup Hcomparable Hsuc Hfail.
    destruct (envs_simple_replace _ _ _ _) as [Δ'' |] eqn:HΔ''; last done.
    rewrite into_laterN_env_sound -wp_bind.
    destruct (decide (v = v1)) as [-> | Hne].
    - rewrite envs_simple_replace_sound //= Hsuc //.
      iIntros "(Hl & H)".
      iApply (wp_cas_suc with "Hl"); [done.. |].
      iSteps.
    - rewrite envs_lookup_split //= Hfail //.
      iIntros "(Hl & H)".
      iApply (wp_cas_fail with "Hl"); [done.. |].
      iSteps.
  Qed.
  Lemma tac_wp_cas_fail Δ Δ' id K l v v1 v2 E Φ :
    MaybeIntoLaterNEnvs 1 Δ Δ' →
    envs_lookup id Δ' = Some (false, l ↦ v)%I →
    v ≠ v1 →
    val_comparable v v1 →
    envs_entails Δ' (WP fill K #false @ E {{ Φ }}) →
    envs_entails Δ (WP fill K (Cas #l v1 v2) @ E {{ Φ }}).
  Proof.
    rewrite envs_entails_unseal => HΔ Hlookup Hne Hcomparable HΔ'.
    rewrite into_laterN_env_sound -wp_bind envs_lookup_split //= HΔ' //.
    iIntros "(Hl & H)".
    iApply (wp_cas_fail with "Hl"); [done.. |].
    iSteps.
  Qed.
  Lemma tac_wp_cas_suc Δ Δ' id K l v v1 v2 E Φ :
    MaybeIntoLaterNEnvs 1 Δ Δ' →
    envs_lookup id Δ' = Some (false, l ↦ v)%I →
    v = v1 →
    val_comparable v v1 →
    match envs_simple_replace id false (Esnoc Enil id (l ↦ v2)) Δ' with
    | Some Δ'' =>
        envs_entails Δ'' (WP fill K #true @ E {{ Φ }})
    | None =>
        False
    end →
    envs_entails Δ (WP fill K (Cas #l v1 v2) @ E {{ Φ }}).
  Proof.
    rewrite envs_entails_unseal => HΔ Hlookup Heq Hcomparable HΔ''. subst.
    destruct (envs_simple_replace _ _ _ _) as [Δ'' |] eqn:HΔ'; last done.
    rewrite into_laterN_env_sound -wp_bind envs_simple_replace_sound //= HΔ'' //.
    iIntros "(Hl & H)".
    iApply (wp_cas_suc with "Hl"); [done.. |].
    iSteps.
  Qed.

  Lemma tac_wp_faa Δ Δ' id K l (i1 i2 : Z) E Φ :
    MaybeIntoLaterNEnvs 1 Δ Δ' →
    envs_lookup id Δ' = Some (false, l ↦ #i1)%I →
    match envs_simple_replace id false (Esnoc Enil id (l ↦ #(i1 + i2))) Δ' with
    | Some Δ'' =>
        envs_entails Δ'' (WP fill K #i1 @ E {{ Φ }})
    | None =>
        False
    end →
    envs_entails Δ (WP fill K (Faa #l #i2) @ E {{ Φ }}).
  Proof.
    rewrite envs_entails_unseal => HΔ Hlookup HΔ''.
    destruct (envs_simple_replace _ _ _) as [Δ'' |] eqn:HΔ'; last done.
    rewrite into_laterN_env_sound -wp_bind envs_simple_replace_sound //= HΔ''.
    iIntros "(Hl & H)".
    iApply (wp_faa with "Hl").
    iSteps.
  Qed.
End zebra_G.

#[local] Ltac wp_start tac :=
  iStartProof;
  lazymatch goal with
  | |- envs_entails _ (wp _ _ ?e ?Q) =>
      tac e
  | _ =>
      fail "not a 'wp'"
  end.

Tactic Notation "wp_expr_eval" tactic3(tac) :=
  wp_start ltac:(fun e =>
    notypeclasses refine (tac_wp_expr_eval _ e _ _ _ _ _);
    [ let x := fresh in
      intros x;
      tac;
      unfold x;
      notypeclasses refine eq_refl
    | idtac
    ]
  ).
Ltac wp_expr_simpl :=
  wp_expr_eval simpl.

#[local] Ltac wp_value_head :=
  lazymatch goal with
  | |- envs_entails _ (wp _ _ (Val _) (λ _, fupd _ _ _)) =>
      eapply tac_wp_value_nofupd
  | |- envs_entails _ (wp _ _ (Val _) (λ _, wp _ _ _ _)) =>
      eapply tac_wp_value_nofupd
  | |- envs_entails _ (wp _ _ (Val _) _) =>
      eapply tac_wp_value
  end.
#[local] Ltac wp_finish :=
  wp_expr_simpl;
  try wp_value_head;
  pm_prettify.

#[local] Ltac solve_val_comparable :=
  fast_done || (left; fast_done) || (right; fast_done).

Tactic Notation "wp_pure" open_constr(e_foc) :=
  wp_start ltac:(fun e =>
    let e := eval simpl in e in
    reshape_expr e ltac:(fun K e' =>
      unify e' e_foc;
      eapply (tac_wp_pure _ _ K e');
      [ tc_solve
      | try solve_val_comparable
      | tc_solve
      | wp_finish
      ]
    )
    || fail "wp_pure: cannot find" e_foc "in" e "or" e_foc "is not a redex"
  ).
Tactic Notation "wp_pure" :=
  wp_pure _.
Tactic Notation "wp_pure" open_constr(e_foc) "credit:" constr(H) :=
  wp_start ltac:(fun e =>
    let Htmp := iFresh in
    let e := eval simpl in e in
    reshape_expr e ltac:(fun K e' =>
      unify e' e_foc;
      eapply (tac_wp_pure_credit _ _ Htmp K e');
      [ tc_solve
      | try solve_val_comparable
      | tc_solve
      | pm_reduce;
        (iDestructHyp Htmp as H || fail 2 "wp_pure:" H "is not fresh");
        wp_finish
      ]
    )
    || fail "wp_pure: cannot find" e_foc "in" e "or" e_foc "is not a redex"
  ).
Tactic Notation "wp_pure" "credit:" constr(H) :=
  wp_pure _ credit: H.
Ltac wp_pures :=
  first
  [ progress repeat (wp_pure _; [])
  | wp_finish
  ].

Ltac wp_rec :=
  let H := fresh in
  assert (H := ValRec_as_ValRec);
  wp_pure (App _ _);
  clear H.

Ltac wp_bind_core K :=
  lazymatch eval hnf in K with
  | [] =>
      idtac
  | _ =>
      eapply (tac_wp_bind K);
      [ simpl; reflexivity
      | pm_prettify
      ]
  end.
Tactic Notation "wp_bind" open_constr(e_foc) :=
  wp_start ltac:(fun e =>
    first
    [ reshape_expr e ltac:(fun K e' => unify e' e_foc; wp_bind_core K)
    | fail 1 "wp_bind: cannot find" e_foc "in" e
    ]
  ).

Tactic Notation "wp_alloc" ident(l) "as" constr(H) :=
  let Htmp := iFresh in
  let finish _ :=
    first [intros l | fail 1 "wp_alloc:" l "not fresh"];
    pm_reduce;
    lazymatch goal with
    | |- False =>
        fail 1 "wp_alloc:" H "not fresh"
    | _ =>
        iDestructHyp Htmp as H;
        wp_finish
    end
  in
  wp_pures;
  wp_start ltac:(fun e =>
    let process_single _ :=
      first
      [ reshape_expr e ltac:(fun K e' => eapply (tac_wp_ref _ _ Htmp K))
      | fail 1 "wp_alloc: cannot find 'Alloc' in" e
      ];
      [ tc_solve
      | finish ()
      ]
    in
    let process_array _ :=
      first
      [ reshape_expr e ltac:(fun K e' => eapply (tac_wp_alloc _ _ Htmp K))
      | fail 1 "wp_alloc: cannot find 'Alloc' in" e
      ];
      [ idtac
      | tc_solve
      | finish ()
      ]
    in
    (process_single ()) || (process_array ())
  ).
Tactic Notation "wp_alloc" ident(l) :=
  wp_alloc l as "?".

Tactic Notation "wp_load" :=
  wp_pures;
  wp_start ltac:(fun e =>
    first
    [ reshape_expr e ltac:(fun K e' => eapply (tac_wp_load _ _ _ K))
    | fail 1 "wp_load: cannot find 'Load' in" e
    ];
    [ tc_solve
    | let l := match goal with |- _ = Some (_, (mapsto ?l _ _)) => l end in
      iAssumptionCore || fail "wp_load: cannot find" l "↦ ?"
    | wp_finish
    ]
  ).

Tactic Notation "wp_store" :=
  wp_pures;
  wp_start ltac:(fun e =>
    first
    [ reshape_expr e ltac:(fun K e' => eapply (tac_wp_store _ _ _ K))
    | fail 1 "wp_store: cannot find 'Store' in" e
    ];
    [ tc_solve
    | let l := match goal with |- _ = Some (_, (mapsto ?l _ _)) => l end in
      iAssumptionCore || fail "wp_store: cannot find" l "↦ ?"
    | pm_reduce;
      wp_finish
    ]
  ).

Tactic Notation "wp_cas" "as" simple_intropattern(H1) "|" simple_intropattern(H2) :=
  wp_pures;
  wp_start ltac:(fun e =>
    first
    [ reshape_expr e ltac:(fun K e' => eapply (tac_wp_cas _ _ _ K))
    | fail 1 "wp_cas: cannot find 'Cas' in" e
    ];
    [ tc_solve
    | let l := match goal with |- _ = Some (_, (mapsto ?l _ _)) => l end in
      iAssumptionCore || fail "wp_cas: cannot find" l "↦ ?"
    | try solve_val_comparable
    | pm_reduce;
      intros H1;
      wp_finish
    | intros H2;
      wp_finish
    ]
  ).
Ltac wp_cas_fail :=
  wp_pures;
  wp_start ltac:(fun e =>
    first
    [ reshape_expr e ltac:(fun K e' => eapply (tac_wp_cas_fail _ _ _ K))
    | fail 1 "wp_cas_fail: cannot find 'Cas' in" e
    ];
    [ tc_solve
    | let l := match goal with |- _ = Some (_, (mapsto ?l _ _)) => l end in
      iAssumptionCore || fail "wp_cas_fail: cannot find" l "↦ ?"
    | try (simpl; congruence)
    | try solve_val_comparable
    | wp_finish
    ]
  ).
Ltac wp_cas_suc :=
  wp_pures;
  wp_start ltac:(fun e =>
    first
    [ reshape_expr e ltac:(fun K e' => eapply (tac_wp_cas_suc _ _ _ K))
    | fail 1 "wp_cas_suc: cannot find 'Cas' in" e
    ];
    [ tc_solve
    | let l := match goal with |- _ = Some (_, (mapsto ?l _ _)) => l end in
      iAssumptionCore || fail "wp_cas_suc: cannot find" l "↦ ?"
    | try (simpl; congruence)
    | try solve_val_comparable
    | pm_reduce;
      wp_finish
    ]
  ).

Ltac wp_faa :=
  wp_pures;
  wp_start ltac:(fun e =>
    first
    [ reshape_expr e ltac:(fun K e' => eapply (tac_wp_faa _ _ _ K))
    | fail 1 "wp_faa: cannot find 'Faa' in" e
    ];
    [ tc_solve
    | let l := match goal with |- _ = Some (_, (mapsto ?l _ _)) => l end in
      iAssumptionCore || fail "wp_faa: cannot find" l "↦ ?"
    | pm_reduce;
      wp_finish
    ]
  ).

#[local] Ltac wp_apply_core lemma tac_suc tac_fail :=
  first
  [ iPoseProofCore lemma as false (fun H =>
      wp_start ltac:(fun e =>
       reshape_expr e ltac:(fun K e' =>
         wp_bind_core K;
         tac_suc H
       )
      )
    )
  | tac_fail ltac:(fun _ =>
      wp_apply_core lemma tac_suc tac_fail
    )
  | let P := type of lemma in
    fail "wp_apply: cannot apply" lemma ":" P
  ].

Tactic Notation "wp_apply" open_constr(lemma) :=
  wp_apply_core lemma
    ltac:(fun H => iApplyHyp H; try iNext; try wp_expr_simpl)
    ltac:(fun _ => fail).
Tactic Notation "wp_apply" open_constr(lemma) "as"
  constr(pat)
:=
  wp_apply lemma; last iIntros pat.
Tactic Notation "wp_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
  ")"
  constr(pat)
:=
  wp_apply lemma; last iIntros ( x1 ) pat.
Tactic Notation "wp_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
      simple_intropattern(x2)
  ")"
  constr(pat)
:=
  wp_apply lemma; last iIntros ( x1 x2 ) pat.
Tactic Notation "wp_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
      simple_intropattern(x2)
      simple_intropattern(x3)
  ")"
  constr(pat)
:=
  wp_apply lemma; last iIntros ( x1 x2 x3 ) pat.
Tactic Notation "wp_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
      simple_intropattern(x2)
      simple_intropattern(x3)
      simple_intropattern(x4)
  ")"
  constr(pat)
:=
  wp_apply lemma; last iIntros ( x1 x2 x3 x4 ) pat.
Tactic Notation "wp_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
      simple_intropattern(x2)
      simple_intropattern(x3)
      simple_intropattern(x4)
      simple_intropattern(x5)
  ")"
  constr(pat)
:=
  wp_apply lemma; last iIntros ( x1 x2 x3 x4 x5 ) pat.
Tactic Notation "wp_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
      simple_intropattern(x2)
      simple_intropattern(x3)
      simple_intropattern(x4)
      simple_intropattern(x5)
      simple_intropattern(x6)
  ")"
  constr(pat)
:=
  wp_apply lemma; last iIntros ( x1 x2 x3 x4 x5 x6 ) pat.
Tactic Notation "wp_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
      simple_intropattern(x2)
      simple_intropattern(x3)
      simple_intropattern(x4)
      simple_intropattern(x5)
      simple_intropattern(x6)
      simple_intropattern(x7)
  ")"
  constr(pat)
:=
  wp_apply lemma; last iIntros ( x1 x2 x3 x4 x5 x6 x7 ) pat.
Tactic Notation "wp_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
      simple_intropattern(x2)
      simple_intropattern(x3)
      simple_intropattern(x4)
      simple_intropattern(x5)
      simple_intropattern(x6)
      simple_intropattern(x7)
      simple_intropattern(x8)
  ")"
  constr(pat)
:=
  wp_apply lemma; last iIntros ( x1 x2 x3 x4 x5 x6 x7 x8 ) pat.
Tactic Notation "wp_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
      simple_intropattern(x2)
      simple_intropattern(x3)
      simple_intropattern(x4)
      simple_intropattern(x5)
      simple_intropattern(x6)
      simple_intropattern(x7)
      simple_intropattern(x8)
      simple_intropattern(x9)
  ")"
  constr(pat)
:=
  wp_apply lemma; last iIntros ( x1 x2 x3 x4 x5 x6 x7 x8 x9 ) pat.
Tactic Notation "wp_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
      simple_intropattern(x2)
      simple_intropattern(x3)
      simple_intropattern(x4)
      simple_intropattern(x5)
      simple_intropattern(x6)
      simple_intropattern(x7)
      simple_intropattern(x8)
      simple_intropattern(x9)
      simple_intropattern(x10)
  ")"
  constr(pat)
:=
  wp_apply lemma; last iIntros ( x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 ) pat.

Tactic Notation "wp_smart_apply" open_constr(lemma) :=
  wp_apply_core lemma
    ltac:(fun H =>
      iApplyHyp H;
      try iNext;
      try wp_expr_simpl
    )
    ltac:(fun retry =>
      wp_pure _; [];
      retry ()
    ).
Tactic Notation "wp_smart_apply" open_constr(lemma) "as"
  constr(pat)
:=
  wp_smart_apply lemma; last iIntros pat.
Tactic Notation "wp_smart_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
  ")"
  constr(pat)
:=
  wp_smart_apply lemma; last iIntros ( x1 ) pat.
Tactic Notation "wp_smart_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
      simple_intropattern(x2)
  ")"
  constr(pat)
:=
  wp_smart_apply lemma; last iIntros ( x1 x2 ) pat.
Tactic Notation "wp_smart_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
      simple_intropattern(x2)
      simple_intropattern(x3)
  ")"
  constr(pat)
:=
  wp_smart_apply lemma; last iIntros ( x1 x2 x3 ) pat.
Tactic Notation "wp_smart_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
      simple_intropattern(x2)
      simple_intropattern(x3)
      simple_intropattern(x4)
  ")"
  constr(pat)
:=
  wp_smart_apply lemma; last iIntros ( x1 x2 x3 x4 ) pat.
Tactic Notation "wp_smart_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
      simple_intropattern(x2)
      simple_intropattern(x3)
      simple_intropattern(x4)
      simple_intropattern(x5)
  ")"
  constr(pat)
:=
  wp_smart_apply lemma; last iIntros ( x1 x2 x3 x4 x5 ) pat.
Tactic Notation "wp_smart_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
      simple_intropattern(x2)
      simple_intropattern(x3)
      simple_intropattern(x4)
      simple_intropattern(x5)
      simple_intropattern(x6)
  ")"
  constr(pat)
:=
  wp_smart_apply lemma; last iIntros ( x1 x2 x3 x4 x5 x6 ) pat.
Tactic Notation "wp_smart_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
      simple_intropattern(x2)
      simple_intropattern(x3)
      simple_intropattern(x4)
      simple_intropattern(x5)
      simple_intropattern(x6)
      simple_intropattern(x7)
  ")"
  constr(pat)
:=
  wp_smart_apply lemma; last iIntros ( x1 x2 x3 x4 x5 x6 x7 ) pat.
Tactic Notation "wp_smart_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
      simple_intropattern(x2)
      simple_intropattern(x3)
      simple_intropattern(x4)
      simple_intropattern(x5)
      simple_intropattern(x6)
      simple_intropattern(x7)
      simple_intropattern(x8)
  ")"
  constr(pat)
:=
  wp_smart_apply lemma; last iIntros ( x1 x2 x3 x4 x5 x6 x7 x8 ) pat.
Tactic Notation "wp_smart_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
      simple_intropattern(x2)
      simple_intropattern(x3)
      simple_intropattern(x4)
      simple_intropattern(x5)
      simple_intropattern(x6)
      simple_intropattern(x7)
      simple_intropattern(x8)
      simple_intropattern(x9)
  ")"
  constr(pat)
:=
  wp_smart_apply lemma; last iIntros ( x1 x2 x3 x4 x5 x6 x7 x8 x9 ) pat.
Tactic Notation "wp_smart_apply" open_constr(lemma) "as"
  "(" simple_intropattern(x1)
      simple_intropattern(x2)
      simple_intropattern(x3)
      simple_intropattern(x4)
      simple_intropattern(x5)
      simple_intropattern(x6)
      simple_intropattern(x7)
      simple_intropattern(x8)
      simple_intropattern(x9)
      simple_intropattern(x10)
  ")"
  constr(pat)
:=
  wp_smart_apply lemma; last iIntros ( x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 ) pat.

Tactic Notation "awp_apply" open_constr(lemma) :=
  wp_apply_core lemma
    ltac:(fun H => iApplyHyp H; pm_prettify)
    ltac:(fun _ => fail);
  last iAuIntro.
Tactic Notation "awp_apply" open_constr(lemma) "without" constr(Hs) :=
  let Hs := words Hs in
  let Hs := eval vm_compute in (INamed <$> Hs) in
  wp_apply_core lemma
    ltac:(fun H =>
      iApply (wp_frame_wand with [SGoal $ SpecGoal GSpatial false [] Hs false]);
      [ iAccu
      | iApplyHyp H;
        pm_prettify
      ]
    )
    ltac:(fun _ =>
      fail
    );
  last iAuIntro.

Tactic Notation "awp_smart_apply" open_constr(lemma) :=
  wp_apply_core lemma
    ltac:(fun H =>
      iApplyHyp H
    )
    ltac:(fun retry =>
      wp_pure _; [];
      retry ()
    );
  last iAuIntro.
Tactic Notation "awp_smart_apply" open_constr(lemma) "without" constr(Hs) :=
  let Hs := words Hs in
  let Hs := eval vm_compute in (INamed <$> Hs) in
  wp_apply_core lemma
    ltac:(fun H =>
      iApply (wp_frame_wand with [SGoal $ SpecGoal GSpatial false [] Hs false]);
      [ iAccu
      | iApplyHyp H;
        pm_prettify
      ]
    )
    ltac:(fun retry =>
      wp_pure _; [];
      retry ()
    );
  last iAuIntro.
