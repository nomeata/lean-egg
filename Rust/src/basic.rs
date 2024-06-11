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
    pub name:  String,
    pub lhs:   Pattern<LeanExpr>,
    pub rhs:   Pattern<LeanExpr>,
}

pub fn explain_congr(init: String, goal: String, rw_templates: Vec<RewriteTemplate>, cfg: Config, viz_path: Option<String>) -> (String, EGraph<LeanExpr>) {
    let mut egraph: EGraph<LeanExpr> = EGraph::new();

    let init_expr: RecExpr<LeanExpr> = todo!(); // init.parse();
    let goal_expr: RecExpr<LeanExpr> = todo!(); // goal.parse();
    let init_id = egraph.add_expr(init_expr);
    let goal_id = egraph.add_expr(goal_expr);

    let mut rws: Vec<Rewrite<LeanExpr>> = todo!();
    // TODO: From templates

    /*let mut runner = Runner::default()
        .with_egraph(egraph)
        .with_time_limit(Duration::from_secs(cfg.time_limit.try_into().unwrap()))
        .with_node_limit(cfg.node_limit)
        .with_iter_limit(cfg.iter_limit)
        .with_hook(move |runner| {
            if let Some(path) = &viz_path {
                runner.egraph.dot().to_dot(format!("{}/{}.dot", path, runner.iterations.len())).unwrap();
            }
            if runner.egraph.find(init_id) == runner.egraph.find(goal_id) {
                Err("search complete".to_string())
            } else {
                Ok(())
            }
        })
        .run(&rws);

    if runner.egraph.find(init_id) == runner.egraph.find(goal_id) {
        let mut expl = runner.explain_equivalence(&init_expr, &goal_expr);
        let expl_str = expl.get_flat_string();
        Ok((expl_str, runner.egraph))
    } else {
        Err(Error::Stopped(runner.stop_reason.unwrap()))
    }
    */
}