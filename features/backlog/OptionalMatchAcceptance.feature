#
# Copyright (c) 2015-2019 "Neo Technology,"
# Network Engine for Objects in Lund AB [http://neotechnology.com]
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Attribution Notice under the terms of the Apache License 2.0
#
# This work was created by the collective efforts of the openCypher community.
# Without limiting the terms of Section 6, any Derivative Work that is not
# approved by the public consensus process of the openCypher Implementers Group
# should not be described as “Cypher” (and Cypher® is a registered trademark of
# Neo4j Inc.) or as "openCypher". Extensions by implementers or prototypes or
# proposals for change that have been documented or implemented should only be
# described as "implementation extensions to Cypher" or as "proposed changes to
# Cypher that are not yet approved by the openCypher community".
#

#encoding: utf-8

Feature: OptionalMatchAcceptance

  Background:
    Given an empty graph
    And having executed:
      """
      CREATE (s:Single), (a:A {num: 42}),
             (b:B {num: 46}), (c:C)
      CREATE (s)-[:REL]->(a),
             (s)-[:REL]->(b),
             (a)-[:REL]->(c),
             (b)-[:LOOP]->(b)
      """

  Scenario: Return null when no matches due to inline label predicate
    When executing query:
      """
      MATCH (n:Single)
      OPTIONAL MATCH (n)-[r]-(m:NonExistent)
      RETURN r
      """
    Then the result should be, in any order:
      | r    |
      | null |
    And no side effects

  Scenario: Return null when no matches due to label predicate in WHERE
    When executing query:
      """
      MATCH (n:Single)
      OPTIONAL MATCH (n)-[r]-(m)
      WHERE m:NonExistent
      RETURN r
      """
    Then the result should be, in any order:
      | r    |
      | null |
    And no side effects

  Scenario: Respect predicates on the OPTIONAL MATCH
    When executing query:
      """
      MATCH (n:Single)
      OPTIONAL MATCH (n)-[r]-(m)
      WHERE m.num = 42
      RETURN m
      """
    Then the result should be, in any order:
      | m              |
      | (:A {num: 42}) |
    And no side effects

  Scenario: Returning label predicate on null node
    When executing query:
      """
      MATCH (n:Single)
      OPTIONAL MATCH (n)-[r:TYPE]-(m)
      RETURN m:TYPE
      """
    Then the result should be, in any order:
      | m:TYPE |
      | null   |
    And no side effects

  Scenario: MATCH after OPTIONAL MATCH
    When executing query:
      """
      MATCH (a:Single)
      OPTIONAL MATCH (a)-->(b:NonExistent)
      OPTIONAL MATCH (a)-->(c:NonExistent)
      WITH coalesce(b, c) AS x
      MATCH (x)-->(d)
      RETURN d
      """
    Then the result should be, in any order:
      | d |
    And no side effects

  Scenario: WITH after OPTIONAL MATCH
    When executing query:
      """
      OPTIONAL MATCH (a:A)
      WITH a AS a
      MATCH (b:B)
      RETURN a, b
      """
    Then the result should be, in any order:
      | a              | b              |
      | (:A {num: 42}) | (:B {num: 46}) |
    And no side effects

  Scenario: Named paths in optional matches
    When executing query:
      """
      MATCH (a:A)
      OPTIONAL MATCH p = (a)-[:X]->(b)
      RETURN p
      """
    Then the result should be, in any order:
      | p    |
      | null |
    And no side effects

  Scenario: OPTIONAL MATCH and bound nodes
    When executing query:
      """
      MATCH (a:A), (b:C)
      OPTIONAL MATCH (x)-->(b)
      RETURN x
      """
    Then the result should be, in any order:
      | x              |
      | (:A {num: 42}) |
    And no side effects

  Scenario: OPTIONAL MATCH with labels on the optional end node
    Given having executed:
      """
      CREATE (:X), (x:X), (y1:Y), (y2:Y:Z)
      CREATE (x)-[:REL]->(y1),
             (x)-[:REL]->(y2)
      """
    When executing query:
      """
      MATCH (a:X)
      OPTIONAL MATCH (a)-->(b:Y)
      RETURN b
      """
    Then the result should be, in any order:
      | b      |
      | null   |
      | (:Y)   |
      | (:Y:Z) |
    And no side effects

  Scenario: Named paths inside optional matches with node predicates
    When executing query:
      """
      MATCH (a:A), (b:B)
      OPTIONAL MATCH p = (a)-[:X]->(b)
      RETURN p
      """
    Then the result should be, in any order:
      | p    |
      | null |
    And no side effects

  Scenario: Variable length optional relationships
    When executing query:
      """
      MATCH (a:Single)
      OPTIONAL MATCH (a)-[*]->(b)
      RETURN b
      """
    Then the result should be, in any order:
      | b              |
      | (:A {num: 42}) |
      | (:B {num: 46}) |
      | (:B {num: 46}) |
      | (:C)           |
    And no side effects

  Scenario: Variable length optional relationships with length predicates
    When executing query:
      """
      MATCH (a:Single)
      OPTIONAL MATCH (a)-[*3..]-(b)
      RETURN b
      """
    Then the result should be, in any order:
      | b    |
      | null |
    And no side effects

  Scenario: Optionally matching self-loops
    When executing query:
      """
      MATCH (a:B)
      OPTIONAL MATCH (a)-[r]-(a)
      RETURN r
      """
    Then the result should be, in any order:
      | r       |
      | [:LOOP] |
    And no side effects

  Scenario: Optionally matching self-loops without matches
    When executing query:
      """
      MATCH (a)
      WHERE NOT (a:B)
      OPTIONAL MATCH (a)-[r]->(a)
      RETURN r
      """
    Then the result should be, in any order:
      | r    |
      | null |
      | null |
      | null |
    And no side effects

  Scenario: Variable length optional relationships with bound nodes
    When executing query:
      """
      MATCH (a:Single), (x:C)
      OPTIONAL MATCH (a)-[*]->(x)
      RETURN x
      """
    Then the result should be, in any order:
      | x    |
      | (:C) |
    And no side effects

  Scenario: Variable length optional relationships with bound nodes, no matches
    When executing query:
      """
      MATCH (a:A), (b:B)
      OPTIONAL MATCH p = (a)-[*]->(b)
      RETURN p
      """
    Then the result should be, in any order:
      | p    |
      | null |
    And no side effects

  Scenario: Longer pattern with bound nodes
    When executing query:
      """
      MATCH (a:Single), (c:C)
      OPTIONAL MATCH (a)-->(b)-->(c)
      RETURN b
      """
    Then the result should be, in any order:
      | b              |
      | (:A {num: 42}) |
    And no side effects

  Scenario: Longer pattern with bound nodes without matches
    When executing query:
      """
      MATCH (a:A), (c:C)
      OPTIONAL MATCH (a)-->(b)-->(c)
      RETURN b
      """
    Then the result should be, in any order:
      | b    |
      | null |
    And no side effects

  Scenario: Handling correlated optional matches; first does not match implies second does not match
    When executing query:
      """
      MATCH (a:A), (b:B)
      OPTIONAL MATCH (a)-->(x)
      OPTIONAL MATCH (x)-[r]->(b)
      RETURN x, r
      """
    Then the result should be, in any order:
      | x    | r    |
      | (:C) | null |
    And no side effects

  Scenario: Handling optional matches between optionally matched entities
    When executing query:
      """
      OPTIONAL MATCH (a:NotThere)
      WITH a
      MATCH (b:B)
      WITH a, b
      OPTIONAL MATCH (b)-[r:NOR_THIS]->(a)
      RETURN a, b, r
      """
    Then the result should be, in any order:
      | a    | b              | r    |
      | null | (:B {num: 46}) | null |
    And no side effects

  Scenario: Handling optional matches between nulls
    When executing query:
      """
      OPTIONAL MATCH (a:NotThere)
      OPTIONAL MATCH (b:NotThere)
      WITH a, b
      OPTIONAL MATCH (b)-[r:NOR_THIS]->(a)
      RETURN a, b, r
      """
    Then the result should be, in any order:
      | a    | b    | r    |
      | null | null | null |
    And no side effects

  Scenario: OPTIONAL MATCH and `collect()`
    Given having executed:
      """
      CREATE (:DoesExist {num: 42})
      CREATE (:DoesExist {num: 43})
      CREATE (:DoesExist {num: 44})
      """
    When executing query:
      """
      OPTIONAL MATCH (f:DoesExist)
      OPTIONAL MATCH (n:DoesNotExist)
      RETURN collect(DISTINCT n.num) AS a, collect(DISTINCT f.num) AS b
      """
    Then the result should be, in any order:
      | a  | b            |
      | [] | [42, 43, 44] |
    And no side effects

  Scenario: OPTIONAL MATCH and WHERE
    Given having executed:
      """
      CREATE
        (:X {val: 1})-[:E1]->(:Y {val: 2})-[:E2]->(:Z {val: 3}),
        (:X {val: 4})-[:E1]->(:Y {val: 5}),
        (:X {val: 6})
      """
    When executing query:
      """
      MATCH (x:X)
      OPTIONAL MATCH (x)-[:E1]->(y:Y)
      WHERE x.val < y.val
      RETURN x, y
      """
    Then the result should be, in any order:
      | x             | y             |
      | (:X {val: 1}) | (:Y {val: 2}) |
      | (:X {val: 4}) | (:Y {val: 5}) |
      | (:X {val: 6}) | null          |
    And no side effects

  Scenario: OPTIONAL MATCH on two relationships and WHERE
    Given having executed:
      """
      CREATE
        (:X {val: 1})-[:E1]->(:Y {val: 2})-[:E2]->(:Z {val: 3}),
        (:X {val: 4})-[:E1]->(:Y {val: 5}),
        (:X {val: 6})
      """
    When executing query:
      """
      MATCH (x:X)
      OPTIONAL MATCH (x)-[:E1]->(y:Y)-[:E2]->(z:Z)
      WHERE x.val < z.val
      RETURN x, y, z
      """
    Then the result should be, in any order:
      | x             | y             | z             |
      | (:X {val: 1}) | (:Y {val: 2}) | (:Z {val: 3}) |
      | (:X {val: 4}) | null          | null          |
      | (:X {val: 6}) | null          | null          |
    And no side effects

  Scenario: Two OPTIONAL MATCH clauses and WHERE
    Given having executed:
      """
      CREATE
        (:X {val: 1})-[:E1]->(:Y {val: 2})-[:E2]->(:Z {val: 3}),
        (:X {val: 4})-[:E1]->(:Y {val: 5}),
        (:X {val: 6})
      """
    When executing query:
      """
      MATCH (x:X)
      OPTIONAL MATCH (x)-[:E1]->(y:Y)
      OPTIONAL MATCH (y)-[:E2]->(z:Z)
      WHERE x.val < z.val
      RETURN x, y, z
      """
    Then the result should be, in any order:
      | x             | y             | z             |
      | (:X {val: 1}) | (:Y {val: 2}) | (:Z {val: 3}) |
      | (:X {val: 4}) | (:Y {val: 5}) | null          |
      | (:X {val: 6}) | null          | null          |
    And no side effects
