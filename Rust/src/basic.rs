use std::time::Instant;

use miniegg_with_slots::*;
use crate::lean_expr::*;

#[repr(C)]
pub struct Config {
    optimize_expl:          bool,
    time_limit:             usize,
    node_limit:             usize,
    iter_limit:             usize, 
    gen_nat_lit_rws:        bool, 
    gen_eta_rw:             bool,
    gen_beta_rw:            bool,
    gen_level_rws:          bool,
    block_invalid_matches:  bool,
    shift_captured_bvars:   bool,
    allow_unsat_conditions: bool,
    trace_substitutions:    bool,
    trace_bvar_correction:  bool,
}

pub struct RewriteTemplate {
    pub name: String,
    pub lhs:  Pattern<LeanExpr>,
    pub rhs:  Pattern<LeanExpr>,
}

pub fn explain_congr(init: String, goal: String, rw_templates: Vec<RewriteTemplate>, cfg: Config, viz_path: Option<String>) -> bool {
    let mut egraph: EGraph<LeanExpr> = EGraph::new();

    let init_expr = RecExpr::parse(&init).unwrap();
    let goal_expr = RecExpr::parse(&goal).unwrap();
    let init_id = egraph.add_expr(init_expr);
    let goal_id = egraph.add_expr(goal_expr);

    let mut rws: Vec<Rewrite<LeanExpr>> = vec![];
    for template in rw_templates {
        rws.push(mk_rewrite(template.lhs, template.rhs));
    }

    let start_time = Instant::now();
    while start_time.elapsed().as_secs() < cfg.time_limit.try_into().unwrap() {
        do_rewrites(&mut egraph, &rws);
        if egraph.find_applied_id(&init_id) == egraph.find_applied_id(&goal_id) { return true }
    }
    return false
}