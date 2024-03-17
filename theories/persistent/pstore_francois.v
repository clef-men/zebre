From iris Require Import
  ghost_map
  gmap.
From zebre Require Import
  prelude.
From zebre.iris.base_logic Require Import
  lib.mono_set
  lib.mono_list
.
From zebre.language Require Import
  notations
  diaframe.
From zebre.std Require Import
  assert
  lst.
From zebre.persistent Require Export
  base
  pstore_1.
From zebre Require Import
  options.

Section Go.

Notation timestamp := nat.

Context `{pstore_G : PstoreG Σ}.
Context {IG1: ghost_mapG Σ (location*timestamp) val}.
Context {IG2: MonoListG Σ (gmap location val)%type}.


(*
Definition link (ρ:timestamp) (σ:gmap location val) (M:gmap location (timestamp * val)) :=
  dom σ = dom M /\ (forall l v1 v2 ρ', σ !! l = Some v1 -> M !! l = Some (ρ',v2) -> if (decide (ρ'=ρ)) then v1=v2 else True).
 *)

Record gnames := {γ1 : gname; γ2 : gname}.

(*
Definition remove_actual (ρ:timestamp) (M:gmap location (timestamp * val)) : gmap location (timestamp * val) :=
  filter (fun '(_,(ρ',_)) => ρ ≠ ρ') M.
*)

Definition auth_snap_auth γ xs :=
  mono_list_auth γ.(γ2) (DfracOwn 1%Qp) xs.

Definition auth_snap_frag γ ρ σ :=
  mono_list_elem γ ρ σ.

Definition coherent
  (ρ:timestamp) (σ:gmap location val) (M:gmap (location*timestamp) val) :=
   forall l v v', σ !! l = Some v -> M !! (l,ρ) = Some v' -> v = v'.

Record pureinv (ρ:timestamp) (σ:gmap location val) (M:gmap (location*timestamp) val) (xs:list (gmap location val)) :=
  { pu1: ρ = length xs;
    pu2: coherent ρ σ M;
    pu3: forall ρ' σ', xs !! ρ' = Some σ' -> coherent ρ' σ' M;
    pu4: forall l ρ', (l,ρ') ∈ dom M -> ρ' <= ρ
  }.


Definition isnow γ (s:val) (ρ:timestamp) : iProp Σ :=
  ∃ (σ:gmap location val) (M:gmap (location*timestamp) val) (xs:list (gmap location val)),
   ⌜pureinv ρ σ M xs⌝ ∗ pstore s σ ∗ ghost_map_auth γ.(γ1) 1%Qp M ∗
   mono_list_auth γ.(γ2) (DfracOwn 1%Qp) xs.

Definition pat_now := "[%σ [%M [%xs (%Hpure&Hstore&Hpointsto&Hsnap)]]]".

Definition snapshot γ t s ρ : iProp Σ :=
  ∃ σ, pstore_snapshot t s σ ∗ auth_snap_frag γ.(γ2) ρ σ .

Global Instance snapshot_persistent γ t s ρ : Persistent (snapshot γ t s ρ).
Proof. apply _. Qed.

Definition mapsto γ ρ l v :=
  ghost_map_elem γ.(γ1) (l,ρ) (DfracOwn 1) v.

Lemma lookup_insert_case `{Countable K} {V} (X:gmap K V) x y i :
  <[y:=i]> X !! x = if (decide (y=x)) then Some i else X !! x.
Proof. case_decide; subst. rewrite lookup_insert //. rewrite lookup_insert_ne //. Qed.


Lemma coherent_insert_same ρ σ M l v :
  σ !! l = Some v ->
  coherent ρ σ M ->
  coherent ρ σ (<[(l, S ρ):=v]> M).
Proof.
  intros ? Hcoh.
  intros l' ??? E.
  rewrite lookup_insert_case in E.
  case_decide. naive_solver. eauto.
Qed.

Lemma pstore_capture_spec γ s ρ l v :
    {{{
      isnow γ s ρ ∗ mapsto γ ρ l v
    }}}
      pstore_capture s
    {{{ t ρ',
      RET t;
      isnow γ s ρ' ∗ snapshot γ s t ρ ∗ mapsto γ ρ l v ∗ mapsto γ ρ' l v
    }}}.
Proof.
  iIntros (?) "(Hnow&Hmaps) Hpost".
  iDestruct "Hnow" as pat_now.
  iApply wp_fupd.
  wp_apply (pstore_capture_spec with "Hstore").
  iIntros (t) "(Hstore&#X)".
  iMod (mono_list_update_app [σ] with "Hsnap") as "Hsnap".
  iDestruct (mono_list_lb_get with "Hsnap") as "#HX".
  iDestruct (mono_list_elem_get (length xs) with "HX") as "#Hgo".
  { rewrite lookup_app_r // Nat.sub_diag //. }
  iClear "HX".

  iDestruct (ghost_map_lookup with "[$][$]") as "%".
  iMod (ghost_map_insert (l,(S ρ)) v with "Hpointsto") as "(?&?)".
  { destruct Hpure as [X1 X2 X3 X4]. apply not_elem_of_dom.
    intros F. apply X4 in F. lia. }

  iModIntro. iApply ("Hpost" $! t (S ρ)).
  iFrame.
  iSplitL.
  2:{ destruct Hpure. subst. iExists _. iFrame "#". }
  iExists _,_,_. iFrame. iPureIntro.
  { destruct Hpure as [X1 X2 X3 X4]. constructor.
    { rewrite app_length //. simpl. lia. }
    { intros l' ??? E.
      rewrite lookup_insert_case in E.
      case_decide. naive_solver. exfalso.
      apply elem_of_dom_2 in E. apply X4 in E. lia. }
    { intros ??. rewrite lookup_app_Some. intros [?|(?&?)].
      { assert (ρ' <= ρ).
        { apply lookup_lt_Some in H0. lia. }
        apply X3 in H0. intros ?????.
        rewrite lookup_insert_case in H3. case_decide; last naive_solver.
        naive_solver by lia. }
      { apply list_lookup_singleton_Some in H1. destruct H1 as (?&<-).
        assert (ρ' = ρ) as -> by lia.
        eapply coherent_insert_same; try done.
        admit. } }
    { intros ??. rewrite dom_insert_L elem_of_union elem_of_singleton.
      intros [|]; naive_solver by lia. } }
Abort.


Lemma pstore_restore_spec γ s t ρ l v :
    {{{
      isnow γ s ρ ∗ snapshot γ s t ρ ∗ mapsto γ ρ l v
    }}}
      pstore_restore s t
    {{{ ρ',
      RET ();
      isnow γ s ρ' ∗ mapsto γ ρ l v ∗ mapsto γ ρ' l v
    }}}.
Proof.
  iIntros (?) "(Hnow&Ht&E) Hpost".
  iDestruct "Hnow" as pat_now.
  iApply wp_fupd.

  iDestruct "Ht" as "[%σ' (Ht&?)]".
  wp_apply (pstore_restore_spec with "[$]").
  iIntros "Hstore".
  iApply ("Hpost" $! (S ρ)).
  iMod (mono_list_update_app [σ] with "Hsnap") as "Hsnap".

  iDestruct (ghost_map_lookup with "[$][$]") as "%".
  iMod (ghost_map_insert (l,(S ρ)) v with "Hpointsto") as "(?&?)".
  (* XXX lemma *)
  { destruct Hpure as [X1 X2 X3 X4]. apply not_elem_of_dom.
    intros F. apply X4 in F. lia. }
  iFrame.

  iExists _,_,_. iFrame.
  iPureIntro.
  destruct Hpure as [X1 X2 X3 X4].
  constructor.
  { rewrite app_length. simpl. lia. }
  { admit. }
  { admit. }
  { admit. }
Abort.

End .
