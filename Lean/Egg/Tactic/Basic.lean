import Egg.Core.Request
import Egg.Core.Explanation.Proof
import Egg.Core.Gen.TcProjs
import Egg.Tactic.Config
import Egg.Tactic.Explanation
import Egg.Tactic.Base
import Egg.Tactic.Rewrites
import Egg.Tactic.Trace
import Lean

open Lean Meta Elab Tactic

namespace Egg

-- Note: If `base? ≠ none`, the goal is an auxiliary goal and needs to be handled specially after
--       proof reconstruction.
private structure Goal where
  id    : MVarId
  type  : Congr
  base? : Option FVarId

private def parseGoal (goal : MVarId) (base? : Option (TSyntax `egg_base)) : MetaM Goal := do
  let goalType ← normalize (← goal.getType')
  let base? ← base?.mapM parseBase
  let cgr ← getCongr goalType base?
  return { id := goal, type := cgr, base? }
where
  getCongr (goalType : Expr) (base? : Option FVarId) : MetaM Congr := do
    if let some base := base? then
      return { lhs := ← base.getType, rhs := goalType, rel := .eq : Congr }
    else if let some c ← Congr.from? goalType then
      return c
    else
      throwError "expected goal to be of type '=' or '↔', but found:\n{← ppExpr goalType}"

private def genRewrites (goal : Goal) (rws : TSyntax `egg_rws) (cfg : Config) :
    TacticM (Rewrites × ExplosionVars) := do
  let mut rws ← Rewrites.parse rws
  let mut explode : ExplosionVars := {}
  if cfg.genTcProjRws then
    let tcProjTargets := #[(goal.type, Source.goal)] ++ (rws.map fun rw => (rw.toCongr, rw.src))
    rws := rws ++ (← genTcProjReductions tcProjTargets)
  if cfg.explode then
    let (explosionRws, vars) ← rws.explode
    rws := rws ++ explosionRws
    explode := vars
  return (rws, explode)

private def traceFrontend (goal : Goal) (rws : Rewrites) (cfg : Config) (explode : ExplosionVars) : TacticM Unit := do
  let goalType ← goal.type.expr
  withTraceNode `egg.frontend (fun _ => return m!"Goal: {← ppExpr goalType}") do
    withTraceNode `egg.frontend (fun _ => return "LHS") do
      trace[egg.frontend] ← encode goal.type.lhs .goal cfg.toEncoding explode
    withTraceNode `egg.frontend (fun _ => return "RHS") do
      trace[egg.frontend] ← encode goal.type.rhs .goal cfg.toEncoding explode
    let rwsTitle := (if rws.isEmpty && !cfg.genNatLitRws then "No " else "") ++ "Rewrites"
    withTraceNode `egg.frontend (fun _ => return rwsTitle) (collapsed := false) do
      for rw in rws do
        withTraceNode `egg.frontend (fun _ => return m!"{rw.src}") do
          withTraceNode `egg.frontend (fun _ => return "LHS") do
            trace[egg.frontend] ← encode rw.lhs rw.src cfg.toEncoding explode
          withTraceNode `egg.frontend (fun _ => return "RHS") do
            trace[egg.frontend] ← encode rw.rhs rw.src cfg.toEncoding explode
          trace[egg.frontend] "Directions: {rw.validDirs}"
      if cfg.genNatLitRws then
        trace[egg.frontend] "Nat Literal Conversions"

private def processRawExpl (rawExpl : Explanation.Raw) (goal : Goal) (rws : Rewrites) (cfg : Config.Debug) : TacticM Unit := do
  if rawExpl.isEmpty then throwError "egg failed to prove goal"
  withTraceNode `egg.reconstruction (fun _ => return "Result") do trace[egg.reconstruction] rawExpl
  if cfg.exitPoint == .beforeProof then
    goal.id.admit
  else
    let expl ← rawExpl.parse
    let mut proof ← expl.proof goal.type rws
    -- When `goal.base? = some base`, then `proof` is a proof of `base = <goal type>`. We turn this
    -- into a proof of `<goal type>` here.
    if let some base := goal.base? then proof ← mkEqMP proof (.fvar base)
    goal.id.assign proof

elab "egg " cfg:egg_cfg rws:egg_rws base:(egg_base)? : tactic => do
  let goal ← getMainGoal
  let cfg ← Config.parse cfg
  goal.withContext do
    let goal           ← parseGoal goal base
    let (rws, explode) ← genRewrites goal rws cfg
    let request        ← Request.encoding goal.type rws cfg explode
    traceFrontend goal rws cfg explode
    if cfg.exitPoint == .beforeEqSat then goal.id.admit; return
    let rawExpl := request.run
    processRawExpl rawExpl goal rws cfg.toDebug
