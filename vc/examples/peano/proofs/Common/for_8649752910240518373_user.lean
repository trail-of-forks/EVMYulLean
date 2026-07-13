import EvmYul.Yul.Interpreter
import EvmYul.Yul.ReasoningPrinciple
import EvmYul.Yul.YulNotation

import GeneratedEvmYul.peano.Peano.Common.if_6583678682212848292
import GeneratedEvmYul.peano.Peano.addk

import GeneratedEvmYul.peano.Peano.Common.for_8649752910240518373_gen


namespace Peano.Common

open EvmYul
open EvmYul.Yul
open EvmYul.Yul.Ast
open EvmYul.Yul.Notation
open EvmYul.Yul.ReasoningPrinciple

theorem peano_mul_step (y x k : UInt256) :
    UInt256.add (UInt256.add y x)
        (UInt256.mul x (UInt256.sub k (UInt256.ofNat 1))) =
      UInt256.add y (UInt256.mul x k) := by
  apply UInt256.ext
  change y.val + x.val + x.val * (k.val - (1 : Fin UInt256.size)) = y.val + x.val * k.val
  rw [mul_sub, mul_one]
  abel

def Resolutions_for_8649752910240518373 (codeOverride : Option YulContract) : Prop :=
  ∀ s, State.isOk s →
    ResolvedFunction codeOverride s "addk" GeneratedEvmYul.peano.Peano.addk

def AFor_for_8649752910240518373 (codeOverride : Option YulContract) (fuel : Nat) (s₀ s₉ : State) : Prop :=
  Resolutions_for_8649752910240518373 codeOverride →
    State.isOk s₀ →
      s₉ = .OutOfFuel ∨
        (lookupVar s₉ "y" =
            UInt256.add (lookupVar s₀ "y")
              (UInt256.mul (lookupVar s₀ "x") (lookupVar s₀ "k")) ∧
          lookupVar s₉ "x" = lookupVar s₀ "x")

def Spec_for_8649752910240518373 (fuel : Nat) (codeOverride : Option YulContract) (s₀ s₉ : State) : Prop :=
  FuelSpec (AFor_for_8649752910240518373 codeOverride) fuel s₀ s₉

theorem for_8649752910240518373_loopExact_implies_afor
    {fuel : Nat} {codeOverride : Option YulContract} {s₀ s₉ : State} :
    LoopExact for_8649752910240518373_cond for_8649752910240518373_post for_8649752910240518373_body codeOverride fuel s₀ s₉ →
    AFor_for_8649752910240518373 codeOverride fuel s₀ s₉ := by
  intro hloop
  refine loop_exec_implies_spec
    for_8649752910240518373_cond
    for_8649752910240518373_post
    for_8649752910240518373_body
    codeOverride
    (fun _ => UInt256.ofNat 1)
    (fun s₀ s₉ => ∃ fuel, VC_for_8649752910240518373_post fuel codeOverride s₀ s₉)
    (fun s₀ s₉ => ∃ fuel, VC_for_8649752910240518373_body fuel codeOverride s₀ s₉)
    (AFor_for_8649752910240518373 codeOverride fuel)
    ?_ ?_ ?_ ?_ ?_ ?_ ?_ ?_ ?_ hloop
  · intro fuel s₀ s₁ condLit h
    cases fuel <;> simp [for_8649752910240518373_cond, eval] at h ⊢
    exact ⟨h.1.symm, h.2.symm⟩
  · intro fuel s₀ s₉ h
    exact ⟨fuel, for_8649752910240518373_post_exec_implies_vc h⟩
  · intro fuel s₀ s₉ h
    exact ⟨fuel, for_8649752910240518373_body_exec_implies_vc h⟩
  · intro s₀ s₉ hzero hs₉ hresolve hsok
    have hone : UInt256.ofNat 1 ≠ UInt256.ofNat 0 := by
      decide
    exact False.elim (hone hzero)
  · intro s₀ hnonzero hbody hresolve hsok
    cases s₀ <;> simp [State.overwrite?] at hsok ⊢
  · intro s₀ sharedState store hnonzero hbody hresolve hsok
    rcases hbody with ⟨bodyFuel, hbody⟩
    rcases hbody with ⟨hbreak, hfall⟩
    cases s₀ with
    | OutOfFuel =>
        cases hsok
    | Checkpoint jump =>
        cases hsok
    | Ok sstate vstore =>
        have hbranch :
            UInt256.eq (lookupVar (👌 State.Ok sstate vstore) "k") (UInt256.ofNat 0) ≠
              UInt256.ofNat 0 := by
          intro hzero
          have hfall' := hfall hzero trivial (hresolve _ trivial)
          rcases hfall' with ⟨bodyFuel', sBody, hfunc, hret⟩
          cases sBody with
          | OutOfFuel =>
              simp [GeneratedEvmYul.peano.Peano.addk, Ast.FunctionDefinition.rets, State.mkOk,
                State.reviveJump, State.overwrite?, State.setStore, State.multifill] at hret
          | Ok callShared callStore =>
              simp [GeneratedEvmYul.peano.Peano.addk, Ast.FunctionDefinition.rets, State.mkOk,
                State.reviveJump, State.overwrite?, State.setStore, State.multifill] at hret
              cases hret
          | Checkpoint jump =>
              cases jump <;> simp [GeneratedEvmYul.peano.Peano.addk, Ast.FunctionDefinition.rets, State.mkOk,
                State.reviveJump, State.revive, State.overwrite?,
                State.setStore, State.multifill] at hret
              all_goals cases hret
        have hk : lookupVar (State.Ok sstate vstore) "k" = UInt256.ofNat 0 := by
          simpa [State.mkOk] using UInt256.eq_ne_zero hbranch
        have hbreak' := hbreak hbranch
        simp [State.mkOk, State.setBreak] at hbreak'
        rcases hbreak' with ⟨rfl, rfl⟩
        simp [State.reviveJump, State.revive, State.overwrite?]
        rw [hk]
        simp [UInt256.mul_zero, UInt256.add_zero]
  · intro s₀ sharedState store hnonzero hbody hresolve hsok
    rcases hbody with ⟨bodyFuel, hbody⟩
    rcases hbody with ⟨hbreak, hfall⟩
    cases s₀ with
    | OutOfFuel =>
        cases hsok
    | Checkpoint jump =>
        cases hsok
    | Ok sstate vstore =>
        by_cases hbranch :
            UInt256.eq (lookupVar (👌 State.Ok sstate vstore) "k") (UInt256.ofNat 0) =
              UInt256.ofNat 0
        · have hfall' := hfall hbranch trivial (hresolve _ trivial)
          rcases hfall' with ⟨bodyFuel', sBody, hfunc, hret⟩
          cases sBody with
          | OutOfFuel =>
              simp [GeneratedEvmYul.peano.Peano.addk, Ast.FunctionDefinition.rets, State.mkOk,
                State.reviveJump, State.overwrite?, State.setStore, State.multifill] at hret
          | Ok callShared callStore =>
              simp [GeneratedEvmYul.peano.Peano.addk, Ast.FunctionDefinition.rets, State.mkOk,
                State.reviveJump, State.overwrite?, State.setStore, State.multifill] at hret
              cases hret
          | Checkpoint jump =>
              cases jump <;> simp [GeneratedEvmYul.peano.Peano.addk, Ast.FunctionDefinition.rets, State.mkOk,
                State.reviveJump, State.revive, State.overwrite?,
                State.setStore, State.multifill] at hret
              all_goals cases hret
        · have hbreak' := hbreak hbranch
          simp [State.mkOk, State.setBreak] at hbreak'
  · intro s₀ s₃ s₅ sharedState store hnonzero hbody hpost hfor hresolve hsok
    rcases hbody with ⟨bodyFuel, hbody⟩
    rcases hbody with ⟨hbreak, hfall⟩
    cases s₀ with
    | OutOfFuel =>
        cases hsok
    | Checkpoint jump =>
        cases hsok
    | Ok sstate vstore =>
        by_cases hbranch :
            UInt256.eq (lookupVar (👌 State.Ok sstate vstore) "k") (UInt256.ofNat 0) =
              UInt256.ofNat 0
        · have hfall' := hfall hbranch trivial (hresolve _ trivial)
          rcases hfall' with ⟨bodyFuel', sBody, hfunc, hret⟩
          cases sBody with
          | OutOfFuel =>
              simp [GeneratedEvmYul.peano.Peano.addk, Ast.FunctionDefinition.rets, State.mkOk,
                State.reviveJump, State.overwrite?, State.setStore, State.multifill] at hret
          | Ok callShared callStore =>
              simp [GeneratedEvmYul.peano.Peano.addk, Ast.FunctionDefinition.rets, State.mkOk,
                State.reviveJump, State.overwrite?, State.setStore, State.multifill] at hret
              cases hret
          | Checkpoint jump =>
              cases jump <;> simp [GeneratedEvmYul.peano.Peano.addk, Ast.FunctionDefinition.rets, State.mkOk,
                State.reviveJump, State.revive, State.overwrite?,
                State.setStore, State.multifill] at hret
              all_goals cases hret
        · have hbreak' := hbreak hbranch
          simp [State.mkOk, State.setBreak] at hbreak'
  · intro s₀ s₃ s₅ sharedState store hnonzero hbody hpost hfor hresolve hsok
    rcases hbody with ⟨bodyFuel, hbody⟩
    rcases hbody with ⟨hbreak, hfall⟩
    rcases hpost with ⟨postFuel, hpost⟩
    cases s₀ with
    | OutOfFuel =>
        cases hsok
    | Checkpoint jump =>
        cases hsok
    | Ok sstate vstore =>
        have hbranch :
            UInt256.eq (lookupVar (👌 State.Ok sstate vstore) "k") (UInt256.ofNat 0) =
              UInt256.ofNat 0 := by
          by_contra hbranch
          have hbreak' := hbreak hbranch
          simp [State.mkOk, State.setBreak] at hbreak'
        have hbodyOk := hfall hbranch trivial (hresolve _ trivial)
        rcases hbodyOk with ⟨bodyFuel', sBody, hfunc, hret⟩
        have hargOk : State.isOk (👌 (State.Ok sstate vstore).initcall
            GeneratedEvmYul.peano.Peano.addk.params
            [lookupVar (State.Ok sstate vstore) "y", lookupVar (State.Ok sstate vstore) "x"]) := by
          change State.isOk (State.Ok _ _)
          trivial
        cases sBody with
        | OutOfFuel =>
            have hfunc' := hfunc hargOk
            cases hfunc' with
            | inl hout =>
                simp [GeneratedEvmYul.peano.Peano.addk, Ast.FunctionDefinition.rets,
                  State.mkOk, State.reviveJump, State.overwrite?, State.setStore,
                  State.multifill] at hret
            | inr hy =>
                simp [GeneratedEvmYul.peano.Peano.addk, Ast.FunctionDefinition.rets,
                  State.mkOk, State.reviveJump, State.overwrite?, State.setStore,
                  State.multifill] at hret
        | Checkpoint jump =>
            cases jump with
            | Continue callShared callStore =>
                have hfunc' := hfunc hargOk
                cases hfunc' with
                | inl hout =>
                    cases hout
                | inr hy =>
                    cases hy.1
            | Break callShared callStore =>
                have hfunc' := hfunc hargOk
                cases hfunc' with
                | inl hout =>
                    cases hout
                | inr hy =>
                    cases hy.1
            | Leave callShared callStore =>
                have hfunc' := hfunc hargOk
                cases hfunc' with
                | inl hout =>
                    cases hout
                | inr hy =>
                    cases hy.1
        | Ok callShared callStore =>
            have hfunc' := hfunc hargOk
            cases hfunc' with
            | inl hout =>
                cases hout
            | inr hy =>
                simp [GeneratedEvmYul.peano.Peano.addk, Ast.FunctionDefinition.rets,
                  State.mkOk, State.reviveJump, State.overwrite?, State.setStore,
                  State.multifill] at hret
                rcases hret with ⟨rfl, rfl⟩
                rcases hy with ⟨hyOk, hy⟩
                simp [GeneratedEvmYul.peano.Peano.addk, Ast.FunctionDefinition.params,
                  State.mkOk, State.initcall, State.setStore, State.multifill] at hy
                simp [State.reviveJump, State.overwrite?, State.setStore, State.multifill] at hpost hfor ⊢
                subst s₃
                have hrec := hfor hresolve trivial
                have hyx : "y" ≠ "x" := by decide
                have hxy : "x" ≠ "y" := by decide
                have hxk : "x" ≠ "k" := by decide
                have hky : "k" ≠ "y" := by decide
                have hyk : "y" ≠ "k" := by decide
                have hkx : "k" ≠ "x" := by decide
                cases hrec with
                | inl hout =>
                    left
                    exact hout
                | inr hrec =>
                    right
                    rcases hrec with ⟨hyrec, hxrec⟩
                    constructor
                    · simp [State.insert, lookupVar, Finmap.lookup_insert,
                        Finmap.lookup_insert_of_ne, hyx, hxy, hxk, hky, hyk, hkx] at hy hyrec hxrec
                      rw [← lookupVar_ok_eq_lookup! sharedState callStore "y"] at hyrec
                      simp only [lookupVar] at hyrec
                      rw [hy] at hyrec
                      rw [getElem!_ok_sharedState_irrelevant sharedState sstate vstore "x"] at hyrec
                      rw [getElem!_ok_sharedState_irrelevant sharedState sstate vstore "k"] at hyrec
                      simpa [State.insert, lookupVar, Finmap.lookup_insert,
                        Finmap.lookup_insert_of_ne, hyx, hxy, hxk, hky, hyk, hkx, hy,
                        GetElem?.getElem!, decidableGetElem?, State.store,
                        State.instGetElemIdentifierLiteralMemVarStoreStore,
                        peano_mul_step] using hyrec
                    · simp [State.insert, lookupVar, Finmap.lookup_insert,
                        Finmap.lookup_insert_of_ne, hyx, hxy, hxk, hky, hyk, hkx] at hxrec ⊢
                      exact hxrec

theorem for_8649752910240518373_vc_implies_spec {fuel : Nat} {codeOverride : Option YulContract} {s₀ s₉ : State} :
    VC_for_8649752910240518373 fuel codeOverride s₀ s₉ →
    Spec_for_8649752910240518373 fuel codeOverride s₀ s₉ := by
  intro h
  exact for_exec_implies_fuelSpec
    (AFor := AFor_for_8649752910240518373 codeOverride)
    for_8649752910240518373_loopExact_implies_afor
    h

end Peano.Common
