import EvmYul.Yul.Interpreter
import EvmYul.Yul.ReasoningPrinciple
import EvmYul.Yul.YulNotation

import GeneratedEvmYul.peano.Peano.Common.for_8649752910240518373
import GeneratedEvmYul.peano.Peano.addk

import GeneratedEvmYul.peano.Peano.mulk_gen


namespace GeneratedEvmYul.peano.Peano

open EvmYul
open EvmYul.Yul
open EvmYul.Yul.Ast
open EvmYul.Yul.Notation
open EvmYul.Yul.ReasoningPrinciple

def Resolutions_mulk (codeOverride : Option YulContract) : Prop :=
  ∀ s, State.isOk s →
    ResolvedFunction codeOverride s "addk" GeneratedEvmYul.peano.Peano.addk

def AFunc_mulk (codeOverride : Option YulContract) (fuel : Nat) (s₀ s₉ : State) : Prop :=
  Resolutions_mulk codeOverride →
    State.isOk s₀ →
      ∀ sharedState store,
        s₉ = .Ok sharedState store →
          lookupVar s₉ "y" =
            UInt256.mul (lookupVar s₀ "x") (lookupVar s₀ "k")

def Spec_mulk (fuel : Nat) (codeOverride : Option YulContract) (s₀ s₉ : State) : Prop :=
  FuelSpec (AFunc_mulk codeOverride) fuel s₀ s₉

theorem mulk_bodyExact_implies_afunc
    {fuel : Nat} {codeOverride : Option YulContract} {s₀ s₉ : State} :
    FunctionBodyExact mulk codeOverride fuel s₀ s₉ →
    AFunc_mulk codeOverride fuel s₀ s₉ := by
  intro hbody hresolve hs₀ sharedState store hs₉
  cases s₀ with
  | OutOfFuel =>
      cases hs₀
  | Checkpoint jump =>
      cases hs₀
  | Ok sstate vstore =>
  cases fuel with
  | zero =>
      simp [FunctionBodyExact, mulk, Ast.FunctionDefinition.body, exec] at hbody
  | succ fuel₁ =>
      cases fuel₁ with
      | zero =>
          simp [FunctionBodyExact, mulk, Ast.FunctionDefinition.body, exec] at hbody
      | succ fuel₂ =>
          simp [FunctionBodyExact, mulk, Ast.FunctionDefinition.body, exec] at hbody
          cases fuel₂ with
          | zero =>
              simp [exec, State.insert] at hbody
          | succ fuelY =>
              generalize hloop :
                loop fuelY (Expr.Lit (UInt256.ofNat 1))
                  [Stmt.Let ["k"]
                    (some (Expr.Call (Sum.inl (Operation.StopArith Operation.SAOp.SUB))
                      [Expr.Var "k", Expr.Lit (UInt256.ofNat 1)]))]
                  [Stmt.If
                      (Expr.Call (Sum.inl (Operation.CompBit Operation.CBLOp.EQ))
                        [Expr.Var "k", Expr.Lit (UInt256.ofNat 0)])
                      [Stmt.Break],
                    Stmt.Let ["y"]
                  (some (Expr.Call (Sum.inr "addk")
                    [Expr.Var "y", Expr.Var "x"]))]
                  codeOverride (State.Ok sstate (Finmap.insert "y" (UInt256.ofNat 0) vstore)) = sLoop at hbody
              simp [State.insert, exec] at hbody
              rw [hloop] at hbody
              cases sLoop with
              | error e =>
                  cases hbody
              | ok sLoop =>
                  cases sLoop with
                  | Ok loopShared loopStore =>
                      have hfor :
                          Peano.Common.AFor_for_8649752910240518373 codeOverride fuelY.succ
                            (State.Ok sstate (Finmap.insert "y" (UInt256.ofNat 0) vstore))
                            (State.Ok loopShared loopStore) :=
                        Peano.Common.for_8649752910240518373_loopExact_implies_afor
                          (by
                            simpa [LoopExact, exec, Peano.Common.for_8649752910240518373_cond,
                              Peano.Common.for_8649752910240518373_post,
                              Peano.Common.for_8649752910240518373_body] using hloop)
                      have hfor' := hfor hresolve
                      have hfor'' :
                          State.isOk (State.Ok sstate (Finmap.insert "y" (UInt256.ofNat 0) vstore)) → _ :=
                        hfor'
                      symm at hbody
                      cases hbody
                      have hloopSpec := hfor'' trivial
                      cases hloopSpec with
                      | inl hout =>
                          cases hout
                      | inr hloopSpec =>
                          rcases hloopSpec with ⟨hy, hx⟩
                          rw [lookupVar_finmap_insert_same_ok sstate vstore "y" (UInt256.ofNat 0)] at hy
                          rw [lookupVar_finmap_insert_ne_ok sstate vstore
                            (var := "y") (other := "x") (val := UInt256.ofNat 0) (by decide)] at hy
                          rw [lookupVar_finmap_insert_ne_ok sstate vstore
                            (var := "y") (other := "k") (val := UInt256.ofNat 0) (by decide)] at hy
                          simpa [UInt256.zero_add] using hy
                  | OutOfFuel =>
                      symm at hbody
                      cases hbody
                      cases hs₉
                  | Checkpoint jump =>
                      symm at hbody
                      cases hbody
                      cases hs₉

theorem mulk_vc_implies_spec {fuel : Nat} {codeOverride : Option YulContract} {s₀ s₉ : State} :
    VC_mulk fuel codeOverride s₀ s₉ →
    Spec_mulk fuel codeOverride s₀ s₉ := by
  intro h
  exact function_exec_implies_fuelSpec
    (AFunc := AFunc_mulk codeOverride)
    mulk_bodyExact_implies_afunc
    h

end GeneratedEvmYul.peano.Peano
