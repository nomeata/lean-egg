import Egg.Lean
import Egg.Core.Encode.EncodeM
import Lean
open Lean

namespace Egg

abbrev Expression := String

private def Expression.erased : Expression :=
  "_"

-- Note: The encoding of expression mvars and universe level mvars in rewrites relies on the fact
--       that their indices are also unique between eachother.

open EncodeM

private def encodeLevel : Level → EncodeM Expression
  | .zero       => return "0"
  | .succ l     => return s!"(succ {← encodeLevel l})"
  | .max l₁ l₂  => return s!"(max {← encodeLevel l₁} {← encodeLevel l₂})"
  | .imax l₁ l₂ => return s!"(imax {← encodeLevel l₁} {← encodeLevel l₂})"
  | .param name => return s!"(param {name})"
  | .mvar id    => do
    if (← isAmbientLvl id)
    then return s!"(uvar {id.uniqueIdx!})"
    else return s!"?{id.uniqueIdx!}"

-- Note: This function expects its input expression to be normalized (cf. `Egg.normalize`).
partial def encode (e : Expr) (cfg : Config.Encoding) (amb : MVars.Ambient) : MetaM Expression :=
  Prod.fst <$> (go e).run { config := cfg, amb }
where
  go (e : Expr) : EncodeM Expression := do
    if ← needsProofErasure e then return Expression.erased else core e

  core : Expr → EncodeM Expression
    | .bvar idx         => return s!"(bvar {idx})"
    | .fvar id          => encodeFVar id
    | .mvar id          => encodeMVar id
    | .sort lvl         => return s!"(sort {← encodeLevel lvl})"
    | .const name lvls  => return s!"(const {name}{← encodeConstLvls lvls})"
    | .app fn arg       => return s!"(app {← go fn} {← go arg})"
    | .lam _ ty b _     => encodeLam ty b
    | .forallE _ ty b _ => encodeForall ty b
    | .lit (.strVal l)  => return s!"(lit \"{l}\")"
    | .lit (.natVal l)  => return s!"(lit {l})"
    | _                 => panic! "'Egg.encode.core' received non-normalized expression"

  encodeFVar (id : FVarId) : EncodeM Expression := do
    if let some bvarIdx ← bvarIdx? id
    then return s!"(bvar {bvarIdx})"
    else return s!"(fvar {id.uniqueIdx!})"

  encodeMVar (id : MVarId) : EncodeM Expression := do
    if (← isAmbientExpr id)
    then return s!"(mvar {id.uniqueIdx!})"
    else return s!"?{id.uniqueIdx!}"

  encodeConstLvls (lvls : List Level) : EncodeM Expression :=
    lvls.foldlM (init := "") (return s!"{·} {← encodeLevel ·}")

  encodeLam (ty b : Expr) : EncodeM Expression := do
    let dom ← if (← config).eraseLambdaDomains then pure Expression.erased else go ty
    withInstantiatedBVar ty b fun body => return s!"(λ {dom} {← go body})"

  encodeForall (ty b : Expr) : EncodeM Expression := do
    let dom ← if (← config).eraseForallDomains then pure Expression.erased else go ty
    withInstantiatedBVar ty b fun body => return s!"(∀ {dom} {← go body})"
