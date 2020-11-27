use super::{Expr, LogicalPlan, Pair, PlanningContext, Result, Rule};
use crate::backend::Token;
use crate::frontend::expr::plan_expr;
use crate::frontend::{SetAction, Scope};

pub fn plan_set(
    pc: &mut PlanningContext,
    src: LogicalPlan,
    set_stmt: Pair<Rule>,
) -> Result<LogicalPlan> {
    let mut scope = pc.scope_mut();
    let mut actions = parse_set_clause(scope, set_stmt)?;
    return Ok(LogicalPlan::SetProperties { src: Box::new(src), actions })
}

pub fn parse_set_clause(
    scope: &mut Scope,
    set_stmt: Pair<Rule>,
) -> Result<Vec<SetAction>> {
    let mut actions = Vec::new();
    for assignment in set_stmt.into_inner() {
        match assignment.as_rule() {
            Rule::single_assignment => {
                let mut parts = assignment.into_inner();
                let entity = scope.tokenize(parts.next().unwrap().as_str());
                let key = scope.tokenize(parts.next().unwrap().as_str());

                let expr = plan_expr(scope, parts.next().unwrap())?;
                actions.push(SetAction::SingleAssign{
                    entity: scope.get_or_alloc_slot(entity),
                    key,
                    value: expr
                });
            }
            Rule::append_assignment => {
                let mut parts = assignment.into_inner();
                let entity = scope.tokenize(parts.next().unwrap().as_str());

                let expr = plan_expr(scope, parts.next().unwrap())?;
                actions.push(SetAction::Append{
                    entity: scope.get_or_alloc_slot(entity),
                    value: expr
                });
            }
            Rule::overwrite_assignment => {
                let mut parts = assignment.into_inner();
                let entity = scope.tokenize(parts.next().unwrap().as_str());

                let expr = plan_expr(scope, parts.next().unwrap())?;
                actions.push(SetAction::Overwrite{
                    entity: scope.get_or_alloc_slot(entity),
                    value: expr
                });
            }
            _ => unreachable!("{:?}", assignment),
        }
    }

    return Ok(actions)
}



#[cfg(test)]
mod tests {
    use crate::frontend::tests::plan;
    use crate::frontend::{Expr, LogicalPlan, SetAction, MapEntryExpr};
    use crate::Error;

    #[test]
    fn plan_set_single_property() -> Result<(), Error> {
        let mut p = plan("MATCH (a) SET a.name = 'bob'")?;

        let id_a = p.tokenize("a");
        let key_name = p.tokenize("name");

        assert_eq!(
            p.plan,
            LogicalPlan::SetProperties {
                src: Box::new(LogicalPlan::NodeScan {
                    src: Box::new(LogicalPlan::Argument),
                    slot: p.slot(id_a),
                    labels: None
                }),
                actions: vec![SetAction::SingleAssign{
                    entity: p.slot(id_a),
                    key: key_name,
                    value: Expr::String("bob".to_string())
                }] }
        );
        Ok(())
    }

    #[test]
    fn plan_set_overwrite_entity() -> Result<(), Error> {
        let mut p = plan("MATCH (a), (b) SET a = b")?;
        let id_a = p.tokenize("a");
        let id_b = p.tokenize("b");
        let key_name = p.tokenize("name");

        assert_eq!(
            p.plan,
            LogicalPlan::SetProperties {
                src: Box::new(LogicalPlan::NestLoop {
                    outer: Box::new(LogicalPlan::NodeScan {
                        src: Box::new(LogicalPlan::Argument),
                        slot: p.slot(id_a),
                        labels: None
                    }),
                    inner: Box::new(LogicalPlan::NodeScan {
                        src: Box::new(LogicalPlan::Argument),
                        slot: p.slot(id_b),
                        labels: None
                    }),
                    predicate: Expr::Bool(true),
                }),
                actions: vec![SetAction::Overwrite {
                    entity: p.slot(id_a),
                    value: Expr::Slot(p.slot(id_b)),
                }]
            }
        );
        Ok(())
    }

    #[test]
    fn plan_set_append_map() -> Result<(), Error> {
        let mut p = plan("MATCH (a) SET a += {name: 'baz'}")?;
        let id_a = p.tokenize("a");
        let key_name = p.tokenize("name");

        assert_eq!(
            p.plan,
            LogicalPlan::SetProperties {
                src: Box::new(LogicalPlan::NodeScan {
                    src: Box::new(LogicalPlan::Argument),
                    slot: p.slot(id_a),
                    labels: None
                }),
                actions: vec![SetAction::Append {
                    entity: p.slot(id_a),
                    value: Expr::Map(vec![
                        MapEntryExpr{ key: key_name, val: Expr::String("baz".to_string()) },
                    ]),
                }]
            }
        );
        Ok(())
    }
}