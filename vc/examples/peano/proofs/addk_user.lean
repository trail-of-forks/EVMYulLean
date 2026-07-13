import EvmYul.Yul.Interpreter
import EvmYul.Yul.ReasoningPrinciple
import EvmYul.Yul.YulNotation

import GeneratedEvmYul.peano.Peano.Common.for_1843992510614721784

import GeneratedEvmYul.peano.Peano.addk_gen


namespace GeneratedEvmYul.peano.Peano

open EvmYul
open EvmYul.Yul
open EvmYul.Yul.Ast
open EvmYul.Yul.Notation
open EvmYul.Yul.ReasoningPrinciple

def AFunc_addk (codeOverride : Option YulContract) (fuel : Nat) (s₀ s₉ : State) : Prop :=
  State.isOk s₀ →
    s₉ = .OutOfFuel ∨
      State.isOk s₉ ∧
        lookupVar s₉ "y" =
          UInt256.add (lookupVar s₀ "x") (lookupVar s₀ "k")

def Spec_addk (fuel : Nat) (codeOverride : Option YulContract) (s₀ s₉ : State) : Prop :=
  FuelSpec (AFunc_addk codeOverride) fuel s₀ s₉

theorem addk_bodyExact_implies_afunc
    {fuel : Nat} {codeOverride : Option YulContract} {s₀ s₉ : State} :
    FunctionBodyExact addk codeOverride fuel s₀ s₉ →
    AFunc_addk codeOverride fuel s₀ s₉ := by
  intro hbody hs₀
  cases fuel with
  | zero =>
      cases s₀ <;> simp [FunctionBodyExact, addk, Ast.FunctionDefinition.body, exec] at hbody hs₀
  | succ fuel₁ =>
      cases fuel₁ with
      | zero =>
          cases s₀ <;> simp [FunctionBodyExact, addk, Ast.FunctionDefinition.body, exec, loop] at hbody hs₀
      | succ fuel₂ =>
          simp [FunctionBodyExact, addk, Ast.FunctionDefinition.body, exec] at hbody
          generalize hloop :
            loop fuel₂ (Expr.Lit (UInt256.ofNat 1))
              [Stmt.Let ["k"]
                (some (Expr.Call (Sum.inl (Operation.StopArith Operation.SAOp.SUB))
                  [Expr.Var "k", Expr.Lit (UInt256.ofNat 1)]))]
              [Stmt.If
                  (Expr.Call (Sum.inl (Operation.CompBit Operation.CBLOp.EQ))
                    [Expr.Var "k", Expr.Lit (UInt256.ofNat 0)])
                  [Stmt.Break],
                Stmt.Let ["x"]
                  (some (Expr.Call (Sum.inl (Operation.StopArith Operation.SAOp.ADD))
                    [Expr.Var "x", Expr.Lit (UInt256.ofNat 1)]))]
              codeOverride s₀ = sLoop at hbody
          cases sLoop with
          | error e =>
              simp at hbody
          | ok sLoop =>
              cases sLoop with
              | Ok loopShared loopStore =>
                  have hfor :
                      Peano.Common.AFor_for_1843992510614721784 codeOverride fuel₂.succ s₀
                        (State.Ok loopShared loopStore) :=
                    Peano.Common.for_1843992510614721784_loopExact_implies_afor
                      (by
                        simpa [LoopExact, exec, Peano.Common.for_1843992510614721784_cond,
                          Peano.Common.for_1843992510614721784_post,
                          Peano.Common.for_1843992510614721784_body] using hloop)
                  cases fuel₂ with
                  | zero =>
                      simp [exec] at hbody
                  | succ fuelY =>
                      simp [addk, exec, State.insert, lookupVar] at hbody ⊢
                      have hx := hfor hs₀
                      symm at hbody
                      cases hbody
                      cases hx with
                      | inl hout =>
                          cases hout
                      | inr hx =>
                          right
                          rcases hx with ⟨hxOk, hx⟩
                          exact ⟨trivial, by simpa [lookupVar] using hx⟩
              | OutOfFuel =>
                  simp [exec] at hbody
                  left
                  exact hbody.symm
              | Checkpoint jump =>
                  simp [exec] at hbody
                  cases hbody
                  have hfor :
                      Peano.Common.AFor_for_1843992510614721784 codeOverride fuel₂.succ s₀
                        (State.Checkpoint jump) :=
                    Peano.Common.for_1843992510614721784_loopExact_implies_afor
                      (by
                        simpa [LoopExact, exec, Peano.Common.for_1843992510614721784_cond,
                          Peano.Common.for_1843992510614721784_post,
                          Peano.Common.for_1843992510614721784_body] using hloop)
                  have hx := hfor hs₀
                  cases hx with
                  | inl hout =>
                      cases hout
                  | inr hx =>
                      rcases hx with ⟨hxOk, hx⟩
                      cases hxOk

theorem addk_vc_implies_spec {fuel : Nat} {codeOverride : Option YulContract} {s₀ s₉ : State} :
    VC_addk fuel codeOverride s₀ s₉ →
    Spec_addk fuel codeOverride s₀ s₉ := by
  intro h
  exact function_exec_implies_fuelSpec
    (AFunc := AFunc_addk codeOverride)
    addk_bodyExact_implies_afunc
    h

end GeneratedEvmYul.peano.Peano
