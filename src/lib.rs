extern crate pest;
#[macro_use]
extern crate pest_derive;

mod backend;
mod frontend;

use std::fmt::{Display, Formatter};
use std::fmt;

use backend::Backend;
use crate::frontend::Frontend;
use crate::backend::PreparedStatement;

#[derive(Debug)]
pub struct Database {
    backend: Box<dyn Backend>,
    frontend: Frontend,
}

impl Database {
    pub fn open(path: &str) -> Result<Database, Error> {
        let backend = backend::gram::GramBackend::open(path)?;
        let frontend = Frontend{ tokenizer: backend.tokenizer() };
        return Ok(Database {
            backend: Box::new(backend),
            frontend,
        })
    }

    // TODO obviously the query string shouldn't be static
    pub fn run(&mut self, query_str: &'static str, cursor: &mut Cursor) -> Result<(), Error> {
        let plan = self.frontend.plan(query_str)?;

        println!("plan: {:?}", plan);

        let mut row = Row{ slots: vec![] };
        let mut prepped = self.backend.prepare(plan)?;

        // The API then allows us to modify this to reuse existing CursorState if we like
        cursor.state = Some(CursorState{
            prep: prepped,
            row
        });

        return Ok(())
    }
}

// Not sure if this is sensible; idea being that users can allocate cursors up front, and they
// can retain allocation-heavy state (like rows) across queries, giving users control of allocation.
#[derive(Debug)]
struct CursorState {
    prep: Box<dyn PreparedStatement>,
    row: Row,
}

#[derive(Debug)]
pub struct Cursor {
    state: Option<CursorState>,
}

impl Cursor {
    pub fn new() -> Cursor {
        return Cursor {
            state: None,
        }
    }
    pub fn next(&mut self) -> Result<bool, Error> {
        match &mut self.state {
            Some(state) => {
                return state.prep.next(&mut state.row)
            }
            None => {
                panic!("Use of uninitialized cursor")
            }
        }
    }
}

pub type Token = usize;

#[derive(Debug)]
pub enum Dir {
    Out, In
}

#[derive(Clone, Debug, Eq, Hash, PartialEq)]
pub struct Error {
    msg: String,
}

impl std::convert::From<std::io::Error> for Error {
    fn from(e: std::io::Error) -> Self {
        Error{ msg: format!("from io.error: {:?}", e) }
    }
}

#[derive(Debug)]
pub struct Row {
    slots: Vec<Val>
}

// Pointer to a Val in a row
pub type Slot = usize;

#[derive(Debug,Clone)]
pub enum Val {
    Null,
    String(String),
    Node(usize),
    Rel{ node: usize, rel_index: usize },
}

impl Val {
    fn as_node_id(&self) -> usize {
        match self {
            Val::Node(id) => *id,
            _ => panic!("invalid execution plan, non-node value feeds into thing expecting node value")
        }
    }
}

impl Display for Val {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        match self {
            Val::Null=> f.write_str("NULL"),
            Val::String(s) => f.write_str(&s),
            Val::Node(id) => f.write_str(&format!("Node({})", id)),
            Val::Rel{node, rel_index} => f.write_str(&format!("Rel({}/{})", node, rel_index))
        }
    }
}
