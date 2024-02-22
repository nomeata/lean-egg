import Egg

example : (fun x => x) = (fun x => 0 + 0 + x) := by
  egg (config := { eraseLambdaDomains := false }) [Nat.zero_add]

-- BUG: proof reconstruction
example : (fun x => x) = (fun x => 0 + 0 + x) := by
  egg (config := { eraseLambdaDomains := true }) [Nat.zero_add]

example : (fun x => x) = (fun x => 0 + x) := by
  egg (config := { eraseLambdaDomains := false }) [Nat.zero_add]

example : (fun x => x) = (fun x => 0 + x) := by
  egg (config := { eraseLambdaDomains := true }) [Nat.zero_add]

-- BUG: This crashes when `eraseLambdaDomains := true`, as the rewrite is actually bidirectional,
--      but the domain is the only reference to the mvar for `α` on the rhs.
example (h : ∀ α : Type, (fun (l : List α) => 0) = (fun _ => ([] : List α).length)) : True = True := by
  egg (config := { eraseLambdaDomains := false }) [h]
