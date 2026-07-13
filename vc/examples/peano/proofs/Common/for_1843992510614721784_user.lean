import EvmYul.Yul.Interpreter
import EvmYul.Yul.ReasoningPrinciple
import EvmYul.Yul.YulNotation

import GeneratedEvmYul.peano.Peano.Common.if_6583678682212848292

import GeneratedEvmYul.peano.Peano.Common.for_1843992510614721784_gen


namespace Peano.Common

open EvmYul
open EvmYul.Yul
open EvmYul.Yul.Ast
open EvmYul.Yul.Notation
open EvmYul.Yul.ReasoningPrinciple

theorem peano_add_step (x k : UInt256) :
    UInt256.add (UInt256.add x (UInt256.ofNat 1))
        (UInt256.sub k (UInt256.ofNat 1)) =
      UInt256.add x k := by
  ext
  simp [UInt256.add, UInt256.sub, UInt256.ofNat]

def ACond_for_1843992510614721784 (s₀ : State) : Ast.Literal :=
  UInt256.ofNat 1

def APost_for_1843992510614721784
    (fuel : Nat) (codeOverride : Option YulContract) (s₀ s₉ : State) : Prop :=
  VC_for_1843992510614721784_post fuel codeOverride s₀ s₉

def ABody_for_1843992510614721784
    (fuel : Nat) (codeOverride : Option YulContract) (s₀ s₉ : State) : Prop :=
  VC_for_1843992510614721784_body fuel codeOverride s₀ s₉

def AFor_for_1843992510614721784 (codeOverride : Option YulContract) (fuel : Nat) (s₀ s₉ : State) : Prop :=
  State.isOk s₀ →
    s₉ = .OutOfFuel ∨
      State.isOk s₉ ∧
        lookupVar s₉ "x" =
          UInt256.add (lookupVar s₀ "x") (lookupVar s₀ "k")

def Spec_for_1843992510614721784 (fuel : Nat) (codeOverride : Option YulContract) (s₀ s₉ : State) : Prop :=
  FuelSpec (AFor_for_1843992510614721784 codeOverride) fuel s₀ s₉

theorem for_1843992510614721784_loopExact_implies_afor
    {fuel : Nat} {codeOverride : Option YulContract} {s₀ s₉ : State} :
    LoopExact for_1843992510614721784_cond for_1843992510614721784_post for_1843992510614721784_body codeOverride fuel s₀ s₉ →
    AFor_for_1843992510614721784 codeOverride fuel s₀ s₉ := by
  intro hloop
  refine loop_exec_implies_spec
    for_1843992510614721784_cond
    for_1843992510614721784_post
    for_1843992510614721784_body
    codeOverride
    ACond_for_1843992510614721784
    (fun s₀ s₉ => ∃ fuel, VC_for_1843992510614721784_post fuel codeOverride s₀ s₉)
    (fun s₀ s₉ => ∃ fuel, VC_for_1843992510614721784_body fuel codeOverride s₀ s₉)
    (AFor_for_1843992510614721784 codeOverride fuel)
    ?_ ?_ ?_ ?_ ?_ ?_ ?_ ?_ ?_ hloop
  · intro fuel s₀ s₁ condLit h
    cases fuel <;> simp [for_1843992510614721784_cond, ACond_for_1843992510614721784, eval] at h ⊢
    exact ⟨h.1.symm, h.2.symm⟩
  · intro fuel s₀ s₉ h
    exact ⟨fuel, for_1843992510614721784_post_exec_implies_vc h⟩
  · intro fuel s₀ s₉ h
    exact ⟨fuel, for_1843992510614721784_body_exec_implies_vc h⟩
  · intro s₀ s₉ hzero hs₉
    have hone : UInt256.ofNat 1 ≠ UInt256.ofNat 0 := by
      decide
    exact False.elim (hone hzero)
  · intro s₀ hnonzero hbody hok
    cases s₀ <;> simp [State.overwrite?] at hok ⊢
  · intro s₀ sharedState store hnonzero hbody hok
    rcases hbody with ⟨bodyFuel, hbody⟩
    rcases hbody with ⟨hbreak, hfall⟩
    cases s₀ with
    | OutOfFuel =>
        cases hok
    | Checkpoint jump =>
        cases hok
    | Ok sstate vstore =>
        have hbranch :
            UInt256.eq (lookupVar (👌 State.Ok sstate vstore) "k") (UInt256.ofNat 0) ≠
              UInt256.ofNat 0 := by
          intro hzero
          have hfall' := hfall hzero
          simp [State.mkOk, State.insert] at hfall'
        have hk : lookupVar (State.Ok sstate vstore) "k" = UInt256.ofNat 0 := by
          simpa [State.mkOk] using UInt256.eq_ne_zero hbranch
        have hbreak' := hbreak hbranch
        simp [State.mkOk, State.setBreak] at hbreak'
        rcases hbreak' with ⟨rfl, rfl⟩
        simp [State.reviveJump, State.revive, State.overwrite?]
        rw [hk]
        simp [UInt256.add_zero]
  · intro s₀ sharedState store hnonzero hbody hok
    rcases hbody with ⟨bodyFuel, hbody⟩
    rcases hbody with ⟨hbreak, hfall⟩
    cases s₀ with
    | OutOfFuel =>
        cases hok
    | Checkpoint jump =>
        cases hok
    | Ok sstate vstore =>
        by_cases hbranch :
            UInt256.eq (lookupVar (👌 State.Ok sstate vstore) "k") (UInt256.ofNat 0) =
              UInt256.ofNat 0
        · have hfall' := hfall hbranch
          simp [State.mkOk, State.insert] at hfall'
        · have hbreak' := hbreak hbranch
          simp [State.mkOk, State.setBreak] at hbreak'
  · intro s₀ s₃ s₅ sharedState store hnonzero hbody hpost hfor hok
    rcases hbody with ⟨bodyFuel, hbody⟩
    rcases hbody with ⟨hbreak, hfall⟩
    cases s₀ with
    | OutOfFuel =>
        cases hok
    | Checkpoint jump =>
        cases hok
    | Ok sstate vstore =>
        by_cases hbranch :
            UInt256.eq (lookupVar (👌 State.Ok sstate vstore) "k") (UInt256.ofNat 0) =
              UInt256.ofNat 0
        · have hfall' := hfall hbranch
          simp [State.mkOk, State.insert] at hfall'
        · have hbreak' := hbreak hbranch
          simp [State.mkOk, State.setBreak] at hbreak'
  · intro s₀ s₃ s₅ sharedState store hnonzero hbody hpost hfor hok
    rcases hbody with ⟨bodyFuel, hbody⟩
    rcases hbody with ⟨hbreak, hfall⟩
    rcases hpost with ⟨postFuel, hpost⟩
    cases s₀ with
    | OutOfFuel =>
        cases hok
    | Checkpoint jump =>
        cases hok
    | Ok sstate vstore =>
        have hbranch :
            UInt256.eq (lookupVar (👌 State.Ok sstate vstore) "k") (UInt256.ofNat 0) =
              UInt256.ofNat 0 := by
          by_contra hbranch
          have hbreak' := hbreak hbranch
          simp [State.mkOk, State.setBreak] at hbreak'
        have hbodyOk := hfall hbranch
        simp [State.mkOk, State.reviveJump, State.overwrite?] at hbodyOk hpost hfor ⊢
        rcases hbodyOk with ⟨rfl, rfl⟩
        subst s₃
        have hrec := hfor trivial
        have hxk : "x" ≠ "k" := by decide
        have hkx : "k" ≠ "x" := by decide
        cases hrec with
        | inl hout =>
            left
            exact hout
        | inr hrec =>
            right
            rcases hrec with ⟨hrecOk, hrec⟩
            constructor
            · exact hrecOk
            simp [State.insert, lookupVar, Finmap.lookup_insert,
              Finmap.lookup_insert_of_ne, hxk, hkx] at hrec
            simpa [State.insert, lookupVar, Finmap.lookup_insert,
              Finmap.lookup_insert_of_ne, hxk, hkx, peano_add_step] using hrec

theorem for_1843992510614721784_vc_implies_spec {fuel : Nat} {codeOverride : Option YulContract} {s₀ s₉ : State} :
    VC_for_1843992510614721784 fuel codeOverride s₀ s₉ →
    Spec_for_1843992510614721784 fuel codeOverride s₀ s₉ := by
  intro h
  exact for_exec_implies_fuelSpec
    (AFor := AFor_for_1843992510614721784 codeOverride)
    for_1843992510614721784_loopExact_implies_afor
    h

end Peano.Common
