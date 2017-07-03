module Test.DSL (dslSuite) where

import Prelude
import Control.Monad.Free (Free)

import Data.Either (Either(..))
import Data.Euterpea.DSL.Parser (parse)

import Data.Euterpea.Music
import Data.Euterpea.Music1
import Data.Euterpea.Transform (line) as Transform
import Data.Rational ((%))
import Data.List (List(..), (:))

import Test.Unit (Test, TestF, suite, test, success, failure)
import Test.Unit.Assert as Assert

assertMusic :: forall e. String -> Music1 -> Test e
assertMusic s target =
  case parse s of
    Right music ->
      Assert.equal (show target) (show music)

    Left err ->
      failure ("parse failed: " <> (show err))

dslSuite :: forall t. Free (TestF t) Unit
dslSuite = do
  noteSuite

noteSuite :: forall t. Free (TestF t) Unit
noteSuite =
  suite "notes" do
    test "note" do
      assertMusic  "Note qn C 1 100" cq
    test "rest" do
      assertMusic  "Rest qn" rq
    test "line" do
      assertMusic  "Line Note qn C 1 100, Note qn D 1 100, Rest qn" line
    test "chord" do
      assertMusic  "Chord Note qn C 1 100, Note qn D 1 100" chord


cq :: Music1
cq = Prim (Note (1 % 4) (Note1 (Pitch C 1) ((Volume 100) : Nil)))

dq :: Music1
dq = Prim (Note (1 % 4) (Note1 (Pitch D 1) ((Volume 100) : Nil)))

rq :: Music1
rq = Prim (Rest (1 % 4))

eol :: Music1
eol = Prim (Rest (0 % 1))

line :: Music1
line = Seq cq (Seq dq rq)

chord :: Music1
chord = Par cq dq