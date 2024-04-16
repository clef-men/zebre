From zebre Require Import
  prelude.
From zebre.language Require Import
  notations
  diaframe.
From zebre.std Require Export
  base.
From zebre Require Import
  options.

Implicit Types v t : val.

Notation "'ClstClosed'" := (
  in_type "clst" 0
)(in custom zebre_tag
).
Notation "'ClstOpen'" := (
  in_type "clst" 1
)(in custom zebre_tag
).
Notation "'ClstCons'" := (
  in_type "clst" 2
)(in custom zebre_tag
).

Inductive clist :=
  | ClistClosed
  | ClistOpen
  | ClistCons v (cls : clist).
Implicit Types cls : clist.

Fixpoint clist_to_val cls :=
  match cls with
  | ClistClosed =>
      §ClstClosed
  | ClistOpen =>
      §ClstOpen
  | ClistCons v cls =>
      ’ClstCons{ v, clist_to_val cls }
  end.
Coercion clist_to_val : clist >-> val.

#[global] Instance clist_to_val_inj :
  Inj (=) val_eq clist_to_val.
Proof.
  intros cls1. induction cls1 as [| | v1 cls1 IH]; intros [| | v2 cls2]; [naive_solver.. |].
  intros (_ & [= -> ->%eq_val_eq%IH]). done.
Qed.
#[global] Instance clist_to_val_physical cls :
  ValPhysical (clist_to_val cls).
Proof.
  destruct cls; done.
Qed.

Fixpoint list_to_clist_open ls :=
  match ls with
  | [] =>
      ClistOpen
  | v :: ls =>
      ClistCons v (list_to_clist_open ls)
  end.
Fixpoint list_to_clist_closed ls :=
  match ls with
  | [] =>
      ClistClosed
  | v :: ls =>
      ClistCons v (list_to_clist_closed ls)
  end.

#[global] Instance list_to_clist_open_inj :
  Inj (=) (=) list_to_clist_open.
Proof.
  intros ls1. induction ls1 as [| v1 ls1 IH]; intros [| v2 ls2]; naive_solver.
Qed.
#[global] Instance list_to_clist_closed_inj :
  Inj (=) (=) list_to_clist_closed.
Proof.
  intros ls1. induction ls1 as [| v1 ls1 IH]; intros [| v2 ls2]; naive_solver.
Qed.
Lemma list_to_clist_open_closed ls1 ls2 :
  list_to_clist_open ls1 ≠ list_to_clist_closed ls2.
Proof.
  move: ls2. induction ls1; destruct ls2; naive_solver.
Qed.
Lemma list_to_clist_open_not_closed ls :
  list_to_clist_open ls ≠ ClistClosed.
Proof.
  apply (list_to_clist_open_closed ls []).
Qed.

Fixpoint clist_app ls1 cls2 :=
  match ls1 with
  | [] =>
      cls2
  | v :: ls1 =>
      ClistCons v (clist_app ls1 cls2)
  end.

Lemma clist_app_open {ls1 cls2} ls2 :
  cls2 = list_to_clist_open ls2 →
  clist_app ls1 cls2 = list_to_clist_open (ls1 ++ ls2).
Proof.
  move: cls2 ls2. induction ls1; first done.
  intros * ->. f_equal/=. naive_solver.
Qed.
Lemma clist_app_ClistOpen ls :
  clist_app ls ClistOpen = list_to_clist_open ls.
Proof.
  rewrite (clist_app_open []) // right_id //.
Qed.
Lemma clist_app_closed {ls1 cls2} ls2 :
  cls2 = list_to_clist_closed ls2 →
  clist_app ls1 cls2 = list_to_clist_closed (ls1 ++ ls2).
Proof.
  move: cls2 ls2. induction ls1; first done.
  intros * ->. f_equal/=. naive_solver.
Qed.
Lemma clist_app_ClistClosed ls :
  clist_app ls ClistClosed = list_to_clist_closed ls.
Proof.
  rewrite (clist_app_closed []) // right_id //.
Qed.
Lemma clist_app_assoc ls1 ls2 cls :
  clist_app (ls1 ++ ls2) cls = clist_app ls1 (clist_app ls2 cls).
Proof.
  induction ls1; f_equal/=; done.
Qed.

Definition clst_app : val :=
  rec: "clst_app" "t1" "t2" :=
    match: "t1" with
    | ClstOpen =>
        "t2"
    | ClstCons "v" "t1" =>
        ‘ClstCons{ "v", "clst_app" "t1" "t2" }
    end.

Definition clst_rev_app : val :=
  rec: "clst_rev_app" "t1" "t2" :=
    match: "t1" with
    | ClstOpen =>
        "t2"
    | ClstCons "v" "t1" =>
        "clst_rev_app" "t1" ‘ClstCons{ "v", "t2" }
    end.

Section zebre_G.
  Context `{zebre_G : !ZebreG Σ}.

  Lemma wp_match_clist_open ls e1 x2 e2 Φ :
    WP subst' x2 (list_to_clist_open ls) e2 {{ Φ }} ⊢
    WP match: list_to_clist_open ls with ClstClosed => e1 |_ as: x2 => e2 end {{ Φ }}.
  Proof.
    destruct ls; iSteps.
  Qed.

  Lemma clst_app_spec {t1} ls1 {t2} cls2 :
    t1 = list_to_clist_open ls1 →
    t2 = cls2 →
    {{{ True }}}
      clst_app t1 t2
    {{{
      RET clist_app ls1 cls2 : val; True
    }}}.
  Proof.
    iInduction ls1 as [| v1 ls1] "IH" forall (t1 t2 cls2).
    all: iIntros (-> ->) "%Φ _ HΦ".
    all: wp_rec.
    - iSteps.
    - wp_smart_apply ("IH" with "[//]"); iSteps.
  Qed.

  Lemma clst_rev_app_spec {t1} ls1 {t2} cls2 :
    t1 = list_to_clist_open ls1 →
    t2 = cls2 →
    {{{ True }}}
      clst_rev_app t1 t2
    {{{
      RET clist_app (reverse ls1) cls2 : val; True
    }}}.
  Proof.
    iInduction ls1 as [| v1 ls1] "IH" forall (t1 t2 cls2).
    all: iIntros (-> ->) "%Φ _ HΦ".
    all: wp_rec.
    - iSteps.
    - wp_pures.
      wp_smart_apply ("IH" $! _ _ (ClistCons v1 cls2) with "[//]"); iSteps.
      rewrite reverse_cons clist_app_assoc. iSteps.
  Qed.
End zebre_G.

#[global] Opaque clst_app.
#[global] Opaque clst_rev_app.
