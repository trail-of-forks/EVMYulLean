import EvmYul.Yul.Interpreter

namespace EvmYul
namespace Yul
namespace ReasoningPrinciple

open Ast

def Spec (R : State → State → Prop) (s₀ s₉ : State) : Prop :=
  R s₀ s₉

def FuelSpec (R : Nat → State → State → Prop) (fuel : Nat) (s₀ s₉ : State) : Prop :=
  R fuel s₀ s₉

def State.isOk : State → Prop
  | .Ok _ _ => True
  | _ => False

def State.isBreak : State → Prop
  | .Checkpoint (.Break _ _) => True
  | _ => False

def State.isContinue : State → Prop
  | .Checkpoint (.Continue _ _) => True
  | _ => False

def State.isLeave : State → Prop
  | .Checkpoint (.Leave _ _) => True
  | _ => False

def State.isCheckpoint : State → Prop
  | .Checkpoint _ => True
  | _ => False

@[simp]
theorem State.isOk_ok (sharedState : EvmYul.SharedState .Yul) (store : VarStore) :
    State.isOk (.Ok sharedState store) := by
  trivial

@[simp]
theorem State.not_isOk_outOfFuel : ¬ State.isOk .OutOfFuel := by
  intro h
  cases h

@[simp]
theorem State.not_isOk_checkpoint (jump : Jump) : ¬ State.isOk (.Checkpoint jump) := by
  intro h
  cases h

@[simp]
theorem State.isBreak_break (sharedState : EvmYul.SharedState .Yul) (store : VarStore) :
    State.isBreak (.Checkpoint (.Break sharedState store)) := by
  trivial

@[simp]
theorem State.isContinue_continue (sharedState : EvmYul.SharedState .Yul) (store : VarStore) :
    State.isContinue (.Checkpoint (.Continue sharedState store)) := by
  trivial

@[simp]
theorem State.isLeave_leave (sharedState : EvmYul.SharedState .Yul) (store : VarStore) :
    State.isLeave (.Checkpoint (.Leave sharedState store)) := by
  trivial

def LoopExact
    (cond : Expr) (post body : List Stmt) (codeOverride : Option YulContract)
    (fuel : Nat) (s₀ s₉ : State) : Prop :=
  exec fuel (.For cond post body) codeOverride s₀ = .ok s₉

def FunctionBodyExact
    (f : FunctionDefinition) (codeOverride : Option YulContract)
    (fuel : Nat) (s₀ s₉ : State) : Prop :=
  exec fuel (.Block f.body) codeOverride s₀ = .ok s₉

def FunctionCallSummary
    (AFunc : Nat → State → State → Prop) (f : FunctionDefinition)
    (args : List Ast.Literal) (vars : List Identifier) (s₀ s₉ : State) : Prop :=
  ∃ bodyFuel sBody,
    AFunc bodyFuel (👌 s₀.initcall f.params args) sBody ∧
    s₉ = (sBody.reviveJump.overwrite? s₀ |>.setStore s₀).multifill vars (List.map sBody.lookup! f.rets)

def ResolvedFunctionInCode
    (code : YulContract) (name : YulFunctionName) (f : FunctionDefinition) : Prop :=
  code.functions.lookup name = some f

def ResolvedFunction
    (codeOverride : Option YulContract) (s : State)
    (name : YulFunctionName) (f : FunctionDefinition) : Prop :=
  match codeOverride with
  | some code => ResolvedFunctionInCode code name f
  | none =>
      ∃ account,
        s.sharedState.accountMap.find? s.executionEnv.codeOwner = some account ∧
        ResolvedFunctionInCode account.code name f

def PureFunctionCallVC
    (AFunc : Nat → State → State → Prop) (f : FunctionDefinition)
    (args : List Ast.Literal) (vars : List Identifier) (s₀ s₉ : State) : Prop :=
  FunctionCallSummary AFunc f args vars s₀ s₉

theorem pureFunctionCallVC_intro
    {AFunc : Nat → State → State → Prop} {f : FunctionDefinition}
    {args : List Ast.Literal} {vars : List Identifier}
    {bodyFuel : Nat} {s₀ sBody s₉ : State} :
    AFunc bodyFuel (👌 s₀.initcall f.params args) sBody →
    s₉ = (sBody.reviveJump.overwrite? s₀ |>.setStore s₀).multifill vars (List.map sBody.lookup! f.rets) →
    PureFunctionCallVC AFunc f args vars s₀ s₉ := by
  intro hFunc hRet
  exact ⟨bodyFuel, sBody, hFunc, hRet⟩

theorem functionCallSummary_of_call
    {AFunc : Nat → State → State → Prop} {f : FunctionDefinition}
    {name : YulFunctionName} {args rets : List Ast.Literal} {vars : List Identifier}
    {fuel : Nat} {codeOverride : Option YulContract} {s₀ sCall : State}
    (hresolve : ResolvedFunction codeOverride s₀ name f)
    (habs :
      ∀ {bodyFuel : Nat} {sBody : State},
        FunctionBodyExact f codeOverride bodyFuel (👌 s₀.initcall f.params args) sBody →
          AFunc bodyFuel (👌 s₀.initcall f.params args) sBody) :
    call fuel args (some name) codeOverride s₀ = .ok (sCall, rets) →
    FunctionCallSummary AFunc f args vars s₀ (sCall.multifill vars rets) := by
  intro hcall
  cases fuel with
  | zero =>
      simp [call] at hcall
  | succ bodyFuel =>
      simp [call, ResolvedFunction, ResolvedFunctionInCode] at hcall hresolve
      split at hcall
      · contradiction
      next account haccount =>
        cases codeOverride with
        | none =>
            rcases hresolve with ⟨account', haccount', hlookup⟩
            rw [haccount] at haccount'
            cases haccount'
            simp [hlookup] at hcall
            split at hcall
            · contradiction
            next sBody hbody =>
              cases hcall
              exact ⟨bodyFuel, sBody, habs hbody, rfl⟩
        | some code =>
            simp [hresolve] at hcall
            split at hcall
            · contradiction
            next sBody hbody =>
              cases hcall
              exact ⟨bodyFuel, sBody, habs hbody, rfl⟩

theorem functionCallSummary_of_execCall_ok
    {AFunc : Nat → State → State → Prop} {f : FunctionDefinition}
    {name : YulFunctionName} {args : List Ast.Literal} {vars : List Identifier}
    {fuel : Nat} {codeOverride : Option YulContract} {s₀ s₉ : State}
    (hresolve : ResolvedFunction codeOverride s₀ name f)
    (habs :
      ∀ {bodyFuel : Nat} {sBody : State},
        FunctionBodyExact f codeOverride bodyFuel (👌 s₀.initcall f.params args) sBody →
          AFunc bodyFuel (👌 s₀.initcall f.params args) sBody) :
    execCall fuel name vars codeOverride (.ok (s₀, args)) = .ok s₉ →
    FunctionCallSummary AFunc f args vars s₀ s₉ := by
  intro hexec
  cases fuel with
  | zero =>
      simp [execCall] at hexec
  | succ callFuel =>
      simp [execCall, multifill'] at hexec
      generalize hcall : call callFuel args (some name) codeOverride s₀ = callResult at hexec
      cases callResult with
      | error e =>
          simp at hexec
      | ok result =>
          cases result with
          | mk sCall rets =>
              simp at hexec
              cases hexec
              exact functionCallSummary_of_call hresolve habs hcall

theorem functionCallSummary_of_exec_let_call
    {AFunc : Nat → State → State → Prop} {f : FunctionDefinition}
    {name : YulFunctionName} {argExprs : List Expr} {args : List Ast.Literal}
    {vars : List Identifier} {fuel : Nat} {codeOverride : Option YulContract}
    {s₀ sCall s₉ : State}
    (hresolve : ResolvedFunction codeOverride sCall name f)
    (habs :
      ∀ {bodyFuel : Nat} {sBody : State},
        FunctionBodyExact f codeOverride bodyFuel (👌 sCall.initcall f.params args) sBody →
          AFunc bodyFuel (👌 sCall.initcall f.params args) sBody)
    (heval : reverse' (evalArgs fuel argExprs.reverse codeOverride s₀) = .ok (sCall, args)) :
    exec (.succ fuel) (.Let vars (some (.Call (Sum.inr name) argExprs))) codeOverride s₀ = .ok s₉ →
    FunctionCallSummary AFunc f args vars sCall s₉ := by
  intro hexec
  simp [exec, heval] at hexec
  exact functionCallSummary_of_execCall_ok hresolve habs hexec

theorem functionCallSummary_of_exec_block_prefix_let_call
    {AFunc : Nat → State → State → Prop} {f : FunctionDefinition}
    {name : YulFunctionName} {pref : Stmt} {argExprs : List Expr}
    {args : List Ast.Literal} {vars : List Identifier}
    {argFuel : Nat} {codeOverride : Option YulContract} {s₀ sPrefix sCall s₉ : State}
    (hprefix : exec (.succ (.succ argFuel)) pref codeOverride s₀ = .ok sPrefix)
    (hresolve : ResolvedFunction codeOverride sCall name f)
    (habs :
      ∀ {bodyFuel : Nat} {sBody : State},
        FunctionBodyExact f codeOverride bodyFuel (👌 sCall.initcall f.params args) sBody →
          AFunc bodyFuel (👌 sCall.initcall f.params args) sBody)
    (heval : reverse' (evalArgs argFuel argExprs.reverse codeOverride sPrefix) = .ok (sCall, args)) :
    exec (.succ (.succ (.succ argFuel))) (.Block [pref, .Let vars (some (.Call (Sum.inr name) argExprs))]) codeOverride s₀ = .ok s₉ →
    FunctionCallSummary AFunc f args vars sCall s₉ := by
  intro hexec
  simp [exec, hprefix, heval] at hexec
  generalize hcall : execCall argFuel name vars codeOverride (.ok (sCall, args)) = result at hexec
  cases result with
  | error e =>
      simp at hexec
  | ok sResult =>
      simp at hexec
      cases hexec
      exact functionCallSummary_of_execCall_ok hresolve habs hcall

theorem function_exec_implies_bodyExact
    {f : FunctionDefinition} {codeOverride : Option YulContract}
    {fuel : Nat} {s₀ s₉ : State} :
    exec fuel (.Block f.body) codeOverride s₀ = .ok s₉ →
    FunctionBodyExact f codeOverride fuel s₀ s₉ := by
  intro h
  exact h

theorem functionBodyExact_implies_fuelSpec
    {f : FunctionDefinition} {codeOverride : Option YulContract}
    {fuel : Nat} {s₀ s₉ : State} {AFunc : Nat → State → State → Prop}
    (habs :
      ∀ {fuel : Nat} {s₀ s₉ : State},
        FunctionBodyExact f codeOverride fuel s₀ s₉ → AFunc fuel s₀ s₉) :
    FunctionBodyExact f codeOverride fuel s₀ s₉ →
    FuelSpec AFunc fuel s₀ s₉ := by
  intro h
  exact habs h

theorem function_exec_implies_fuelSpec
    {f : FunctionDefinition} {codeOverride : Option YulContract}
    {fuel : Nat} {s₀ s₉ : State} {AFunc : Nat → State → State → Prop}
    (habs :
      ∀ {fuel : Nat} {s₀ s₉ : State},
        FunctionBodyExact f codeOverride fuel s₀ s₉ → AFunc fuel s₀ s₉) :
    exec fuel (.Block f.body) codeOverride s₀ = .ok s₉ →
    FuelSpec AFunc fuel s₀ s₉ := by
  intro h
  exact functionBodyExact_implies_fuelSpec habs (function_exec_implies_bodyExact h)

theorem for_exec_implies_loopExact
    {cond : Expr} {post body : List Stmt} {codeOverride : Option YulContract}
    {fuel : Nat} {s₀ s₉ : State} :
    exec fuel (.For cond post body) codeOverride s₀ = .ok s₉ →
    LoopExact cond post body codeOverride fuel s₀ s₉ := by
  intro h
  exact h

theorem loopExact_implies_spec
    {cond : Expr} {post body : List Stmt} {codeOverride : Option YulContract}
    {fuel : Nat} {s₀ s₉ : State} {AFor : State → State → Prop}
    (habs :
      ∀ {fuel : Nat} {s₀ s₉ : State},
        LoopExact cond post body codeOverride fuel s₀ s₉ → AFor s₀ s₉) :
    LoopExact cond post body codeOverride fuel s₀ s₉ →
    Spec AFor s₀ s₉ := by
  intro h
  exact habs h

theorem for_exec_implies_spec
    {cond : Expr} {post body : List Stmt} {codeOverride : Option YulContract}
    {fuel : Nat} {s₀ s₉ : State} {AFor : State → State → Prop}
    (habs :
      ∀ {fuel : Nat} {s₀ s₉ : State},
        LoopExact cond post body codeOverride fuel s₀ s₉ → AFor s₀ s₉) :
    exec fuel (.For cond post body) codeOverride s₀ = .ok s₉ →
    Spec AFor s₀ s₉ := by
  intro h
  exact loopExact_implies_spec habs (for_exec_implies_loopExact h)

theorem loopExact_implies_fuelSpec
    {cond : Expr} {post body : List Stmt} {codeOverride : Option YulContract}
    {fuel : Nat} {s₀ s₉ : State} {AFor : Nat → State → State → Prop}
    (habs :
      ∀ {fuel : Nat} {s₀ s₉ : State},
        LoopExact cond post body codeOverride fuel s₀ s₉ → AFor fuel s₀ s₉) :
    LoopExact cond post body codeOverride fuel s₀ s₉ →
    FuelSpec AFor fuel s₀ s₉ := by
  intro h
  exact habs h

theorem for_exec_implies_fuelSpec
    {cond : Expr} {post body : List Stmt} {codeOverride : Option YulContract}
    {fuel : Nat} {s₀ s₉ : State} {AFor : Nat → State → State → Prop}
    (habs :
      ∀ {fuel : Nat} {s₀ s₉ : State},
        LoopExact cond post body codeOverride fuel s₀ s₉ → AFor fuel s₀ s₉) :
    exec fuel (.For cond post body) codeOverride s₀ = .ok s₉ →
    FuelSpec AFor fuel s₀ s₉ := by
  intro h
  exact loopExact_implies_fuelSpec habs (for_exec_implies_loopExact h)

end ReasoningPrinciple
end Yul
end EvmYul
