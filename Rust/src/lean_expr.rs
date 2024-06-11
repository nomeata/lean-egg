use miniegg_with_slots::*;

#[derive(PartialEq, Eq, Hash, Clone, Debug)]
pub enum LeanExpr {
    // Primitives:
    Nat(u64),
    Str(String),

    // Encoding of universe levels:
    // Note, we don't encode `zero` explicitly, and use `Nat(0)` for that instead.
    UVar(AppliedId),            // (Nat)
    Param(AppliedId),           // (Str)
    Succ(AppliedId),            // (<level>)
    Max(AppliedId, AppliedId),  // (<level>, <level>)
    IMax(AppliedId, AppliedId), // (<level>, <level>)
    
    // Encoding of expressions:
    BVar(Slot),                         // (<var>)
    FVar(AppliedId),                    // (Nat)
    MVar(AppliedId),                    // (Nat)
    Sort(AppliedId),                    // (<level>)
    Const(Box<[AppliedId]>),            // (Str, <level>*)
    App(AppliedId, AppliedId),          // (<expr>, <expr>)
    Lam(Slot, AppliedId, AppliedId),    // (<var>, <expr>, <expr>)
    Forall(Slot, AppliedId, AppliedId), // (<var>, <expr>, <expr>)
    Lit(AppliedId),                     // (Nat | Str)

    // Constant for proof erasure:
    Proof(AppliedId),
}

impl Language for LeanExpr {

    fn all_slot_occurences_mut(&mut self) -> Vec<&mut Slot> { 
        let mut out = Vec::new();
        match self {
            LeanExpr::Lam(x, t, b) | LeanExpr::Forall(x, t, b) => {
                out.push(x);
                out.extend(t.slots_mut());
                out.extend(b.slots_mut());
            },
            LeanExpr::BVar(x) => {
                out.push(x);
            },
            LeanExpr::App(e1, e2) => {
                out.extend(e1.slots_mut());
                out.extend(e2.slots_mut());
            },
            LeanExpr::Proof(p) => {
                out.extend(p.slots_mut());
            }
            _ => {}
        }
        out
    }

    fn public_slot_occurences_mut(&mut self) -> Vec<&mut Slot> { 
        let mut out = Vec::new();
        match self {
            LeanExpr::Lam(x, t, b) | LeanExpr::Forall(x, t, b) => {
                out.extend(t.slots_mut());
                out.extend(b.slots_mut().into_iter().filter(|y| *y != x));
            },
            LeanExpr::BVar(x) => {
                out.push(x);
            },
            LeanExpr::App(e1, e2) => {
                out.extend(e1.slots_mut());
                out.extend(e2.slots_mut());
            },
            LeanExpr::Proof(p) => {
                out.extend(p.slots_mut());
            }
            _ => {}
        }
        out
    }

    fn applied_id_occurences_mut(&mut self) -> Vec<&mut AppliedId> { 
        match self {
            LeanExpr::UVar(i) | LeanExpr::Param(i) | LeanExpr::Succ(i) | 
            LeanExpr::FVar(i) | LeanExpr::MVar(i) | LeanExpr::Sort(i) | 
            LeanExpr::Lit(i) | LeanExpr::Proof(i) => vec![i],  

            LeanExpr::Max(i1, i2) | LeanExpr::IMax(i1, i2) | LeanExpr::App(i1, i2) | 
            LeanExpr::Lam(_, i1, i2) | LeanExpr::Forall(_, i1, i2) => vec![i1, i2],  
            
            LeanExpr::Const(is) => {
                let mut v = Vec::new();
                for i in &mut **is { v.push(i); }
                v
            },  
            
            _ => vec![],
        }
    }
}