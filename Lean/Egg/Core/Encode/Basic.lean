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

private def encodeLevel : Level → Source → Expression
  | .zero,       _     => "0"
  | .succ l,     k     => s!"(succ {encodeLevel l k})"
  | .max l₁ l₂,  k     => s!"(max {encodeLevel l₁ k} {encodeLevel l₂ k})"
  | .imax l₁ l₂, k     => s!"(imax {encodeLevel l₁ k} {encodeLevel l₂ k})"
  | .mvar id,    .goal => s!"(uvar {id.uniqueIdx!})"
  | .mvar id,    _     => s!"?{id.uniqueIdx!}"
  | .param name, _     => s!"(param {name})"

open EncodeM

-- Note: This function expects its input expression to be normalized (cf. `Egg.normalize`).
partial def encode (e : Expr) (src : Source) (cfg : Config) : MetaM Expression :=
  Prod.fst <$> (go e).run { exprSrc := src, config := cfg.toEncoding }
where
  go (e : Expr) : EncodeM Expression := do
    if ← needsProofErasure e then return Expression.erased else core e

  core : Expr → EncodeM Expression
    | .bvar idx         => return s!"(bvar {idx})"
    | .fvar id          => encodeFVar id
    | .mvar id          => encodeMVar id
    | .sort lvl         => return s!"(sort {encodeLevel lvl (← exprSrc)})"
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
    match ← exprSrc with
    | .goal => return s!"(mvar {id.uniqueIdx!})"
    | _     => return s!"?{id.uniqueIdx!}"

  encodeConstLvls (lvls : List Level) : EncodeM Expression := do
    if (← config).eraseConstLevels
    then return s!" {Expression.erased}"
    else return lvls.foldl (init := "") (s!"{·} {encodeLevel · (← exprSrc)}")

  encodeLam (ty b : Expr) : EncodeM Expression :=
    withInstantiatedBVar ty b fun body => do
      let dom ← if (← config).eraseLambdaDomains then return Expression.erased else go ty
      return s!"(λ {dom} {← go body})"

  encodeForall (ty b : Expr) : EncodeM Expression :=
    withInstantiatedBVar ty b fun body => do
      let dom ← if (← config).eraseForallDomains then return Expression.erased else go ty
      return s!"(∀ {dom} {← go body})"
