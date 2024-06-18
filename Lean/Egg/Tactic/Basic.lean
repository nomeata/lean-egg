import Egg.Core.Request.Basic
import Egg.Tactic.Config.Option
import Egg.Tactic.Config.Modifier
import Egg.Tactic.Base
import Egg.Tactic.Guides
import Egg.Tactic.Premises.Gen
import Egg.Tactic.Trace
import Lean

open Lean Meta Elab Tactic

namespace Egg

-- Note: If `base? ≠ none`, the goal is an auxiliary goal and needs to be handled specially after
--       proof reconstruction.
private structure Goal extends Congr where
  id    : MVarId
  base? : Option FVarId

private def parseGoal (goal : MVarId) (base? : Option (TSyntax `egg_base)) : MetaM Goal := do
  let base? ← base?.mapM parseBase
  let cgr ← getCongr (← goal.getType') base?
  return { cgr with id := goal, base? }
where
  getCongr (goalType : Expr) (base? : Option FVarId) : MetaM Congr := do
    if let some base := base? then
      Congr.from! (← mkEq (← base.getType) goalType)
    else if let some c ← Congr.from? goalType then
      return c
    else
      throwError "expected goal to be of type '=' or '↔', but found:\n{← ppExpr goalType}"

-- TODO: We should also consider the level mvars of all `Fact`s.
private def collectAmbientMVars (goal : Goal) (guides : Guides) : MetaM MVars.Ambient := do
  let expr ← MVars.Ambient.Expr.get
  let goalLvl := (← MVars.collect (← goal.expr)).lvl
  let guidesLvl ← guides.foldlM (init := ∅) fun res g => return res.merge (← MVars.collect g.expr).lvl
  return { expr, lvl := goalLvl.merge guidesLvl }


open Config.Modifier (egg_cfg_mod)

private axiom egg {α : Prop} : α

protected def eval
    (mod : TSyntax ``egg_cfg_mod) (prems : TSyntax `egg_premises)
    (base : Option (TSyntax `egg_base)) (guides : Option (TSyntax `egg_guides)) : TacticM Unit := do
  let goal ← getMainGoal
  let mod  ← Config.Modifier.parse mod
  let cfg := (← Config.fromOptions).modify mod
  cfg.trace `egg.config
  goal.withContext do
    let goal ← parseGoal goal base
    let guides := (← guides.mapM Guides.parseGuides).getD #[]
    let amb ← collectAmbientMVars goal guides
    amb.trace `egg.ambient
    -- We increase the mvar context depth, so that ambient mvars aren't unified during proof
    -- reconstruction. Note that this also means that we can't assign the `goal` mvar within this
    -- do-block.
    let proof? ← withNewMCtxDepth do
      let (rws, facts) ← Premises.gen goal.toCongr prems guides cfg amb
      let req ← Request.encoding goal.toCongr rws facts guides cfg amb
      withTraceNode `egg.encoded (fun _ => return "Encoded") do req.trace `egg.encoded
      if let .beforeEqSat := cfg.exitPoint then return none
      let success := req.run
      if success
      then return some <| ← mkAppM ``egg #[(← goal.type)]
      else throwError "egg failed to prove the goal"
    if let some proof := proof?
    then goal.id.assignIfDefeq' proof
    else goal.id.admit

syntax &"egg" egg_cfg_mod egg_premises (egg_base)? (egg_guides)? : tactic
elab_rules : tactic
  | `(tactic| egg $mod $prems $[$base]? $[$guides]?) => Egg.eval mod prems base guides

-- WORKAROUND: This fixes `Tests/EndOfInput *`.
macro "egg" mod:egg_cfg_mod : tactic => `(tactic| egg $mod)
