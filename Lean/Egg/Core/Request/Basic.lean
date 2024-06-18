import Egg.Core.Encode.Rewrites
import Egg.Core.Encode.Guides
import Egg.Core.Encode.Facts
import Egg.Core.Config
open Lean

namespace Egg.Request

-- IMPORTANT: The C interface to egg depends on the order of these fields.
protected structure Config where
  optimizeExpl         : Bool
  timeLimit            : Nat
  nodeLimit            : Nat
  iterLimit            : Nat
  genNatLitRws         : Bool
  genEtaRw             : Bool
  genBetaRw            : Bool
  genLevelRws          : Bool
  blockInvalidMatches  : Bool
  shiftCapturedBVars   : Bool
  allowUnsatConditions : Bool
  traceSubstitutions   : Bool
  traceBVarCorrection  : Bool

instance : Coe Config Request.Config where
  coe cfg := {
    optimizeExpl         := cfg.optimizeExpl
    timeLimit            := cfg.timeLimit
    nodeLimit            := cfg.nodeLimit
    iterLimit            := cfg.iterLimit
    genNatLitRws         := cfg.genNatLitRws
    genEtaRw             := cfg.genEtaRw
    genBetaRw            := cfg.genBetaRw
    genLevelRws          := cfg.genLevelRws
    blockInvalidMatches  := cfg.blockInvalidMatches
    shiftCapturedBVars   := cfg.shiftCapturedBVars
    allowUnsatConditions := cfg.conditionSubgoals
    traceSubstitutions   := cfg.traceSubstitutions
    traceBVarCorrection  := cfg.traceBVarCorrection
  }

-- IMPORTANT: The C interface to egg depends on the order of these fields.
structure _root_.Egg.Request where
  private mk ::
  lhs     : Expression
  rhs     : Expression
  rws     : Rewrites.Encoded
  facts   : Facts.Encoded
  guides  : Guides.Encoded
  vizPath : String
  cfg     : Request.Config

def encoding
    (goal : Congr) (rws : Rewrites) (facts : Facts) (guides : Guides) (cfg : Config)
    (amb : MVars.Ambient) : MetaM Request :=
  let ctx := { cfg, amb }
  return {
    lhs     := ← encode goal.lhs ctx
    rhs     := ← encode goal.rhs ctx
    rws     := ← rws.encode ctx
    facts   := ← do if rws.any (·.isConditional) then facts.encode ctx else return #[]
    guides  := ← guides.encode ctx
    vizPath := cfg.vizPath.getD ""
    cfg
  }

@[extern "run_egg_request"]
opaque run (req : Request) : Bool
