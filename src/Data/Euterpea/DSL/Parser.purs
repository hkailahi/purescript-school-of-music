module Data.Euterpea.DSL.Parser
        ( PositionedParseError(..)
        , parse
        ) where

import Prelude (class Show, show, ($), (<$>), (<$), (<*>), (<*), (*>), (<<<), (<>))
import Control.Alt ((<|>))
-- import Control.Lazy (fix)
import Data.String as S
import Data.Maybe (fromMaybe)
import Data.Bifunctor (bimap)
import Data.Int (fromString)
import Data.Either (Either(..))
import Data.List (singleton)
import Data.Array (fromFoldable)
import Data.Foldable (class Foldable)
import Text.Parsing.StringParser (Parser(..), ParseError(..), Pos)
import Text.Parsing.StringParser.String (anyChar, anyDigit, char, string, regex, skipSpaces, eof)
import Text.Parsing.StringParser.Combinators (choice, sepBy1, many1, (<?>))
import Data.Euterpea.DSL.ParserExtensins (many1Nel, sepBy1Nel)
import Data.Euterpea.Music (Dur, Octave, Pitch(..), PitchClass(..), Primitive(..), Music (..), NoteAttribute(..)) as Eut
import Data.Euterpea.Music1 as Eut1
import Data.Euterpea.Notes as Eutn
import Data.Euterpea.Transform as Eutt

polyphony :: Parser Eut1.Music1
polyphony =
  ( music <|> voices ) <* eof

voices :: Parser Eut1.Music1
voices =
  Eutt.line  <$> ((keyWord "Par") *> sepBy1 music separator)

music :: Parser Eut1.Music1
music =
  choice
    [
      prim
    , line
    , lines
    , chord
    ]

lines :: Parser Eut1.Music1
lines =
  Eutt.line <$> ((keyWord "Seq") *> sepBy1 line separator)



line :: Parser Eut1.Music1
line =
  Eutt.line1 <$> ((keyWord "Line") *> sepBy1Nel chordOrPrim separator)

chordOrPrim :: Parser (Eut1.Music1)
chordOrPrim = chord <|> prim

chord :: Parser (Eut1.Music1)
chord =
  Eutt.chord1 <$> ((keyWord "Chord") *> sepBy1Nel primNote1 separator)

prim :: Parser (Eut1.Music1)
prim =  Eut.Prim <$> (note1 <|> rest)

primNote1 :: Parser Eut1.Music1
primNote1 = Eut.Prim <$> note1

note1 :: Parser (Eut.Primitive Eut1.Note1)
note1 =
  buildNote1 <$> keyWord "Note" <*> duration <*> pitch <*> volume

rest :: ∀ a. Parser (Eut.Primitive a)
rest =
  Eut.Rest <$> (keyWord "Rest" *> duration)

pitch :: Parser Eut.Pitch
pitch =
  Eut.Pitch <$> pitchClass <*> octave

duration :: Parser Eut.Dur
duration =
  (choice
    [
      bn   -- brevis note
    , wn   -- whole note
    , hn   -- half note
    , qn   -- quarter note
    , sn   -- sixteenth note
    , tn   -- thirtysecond note etc.
    ]
   ) <* skipSpaces

bn :: Parser Eut.Dur
bn = Eutn.bn <$ string "bn"

wn :: Parser Eut.Dur
wn = Eutn.wn <$ string "wn"

hn :: Parser Eut.Dur
hn = Eutn.hn <$ string "hn"

qn :: Parser Eut.Dur
qn = Eutn.qn <$ string "qn"

sn :: Parser Eut.Dur
sn = Eutn.sn <$ string "sn"

tn :: Parser Eut.Dur
tn = Eutn.tn <$ string "tn"

pitchClass :: Parser Eut.PitchClass
pitchClass =
  (choice
    [
      css
    , cs
    , c
    , cf
    , cff
    , dss
    , ds
    , d
    , df
    , dff  -- etc.
    ]
   ) <* skipSpaces
     <?> "pitch class"


css :: Parser Eut.PitchClass
css = Eut.Css <$ string "Css"

cs :: Parser Eut.PitchClass
cs = Eut.Cs <$ string "Cs"

c :: Parser Eut.PitchClass
c = Eut.C <$ string "C"

cf :: Parser Eut.PitchClass
cf = Eut.Cf <$ string "Cf"

cff :: Parser Eut.PitchClass
cff = Eut.Cff <$ string "Cff"

dss :: Parser Eut.PitchClass
dss = Eut.Dss <$ string "Dss"

ds :: Parser Eut.PitchClass
ds = Eut.Ds <$ string "Ds"

d :: Parser Eut.PitchClass
d = Eut.D <$ string "D"

df :: Parser Eut.PitchClass
df = Eut.Df <$ string "Df"

dff :: Parser Eut.PitchClass
dff = Eut.Dff <$ string "Dff"

octave :: Parser Eut.Octave
octave =
  (digit <|> ten) <* skipSpaces

volume :: Parser Int
volume = int <* skipSpaces

separator :: Parser Char
separator =
  (char ',') <* skipSpaces

-- | Parse a positive integer (with no sign).
int :: Parser Int
int =
  (fromMaybe 0 <<< fromString) <$> anyInt
    <?> "expected a positive integer"

anyInt :: Parser String
anyInt =
  regex "0|[1-9][0-9]*"

anyString :: Parser String
anyString = fromCharList <$> many1 anyChar

fromCharList :: forall f. Foldable f => f Char -> String
fromCharList = S.fromCharArray <<< fromFoldable

keyWord :: String -> Parser String
keyWord target =
  (string target) <* skipSpaces

digit :: Parser Int
digit = (fromMaybe 0 <<< fromString <<< S.singleton) <$> anyDigit

ten :: Parser Int
ten = 10 <$ string "10"

buildNote1 :: String -> Eut.Dur -> Eut.Pitch -> Int -> Eut.Primitive Eut1.Note1
buildNote1 _ dur p vol =
  Eut.Note dur $ Eut1.Note1 p $ singleton (Eut.Volume vol)

-- | a parse error and its accompanying position in the text
newtype PositionedParseError = PositionedParseError
  { pos :: Int
  , error :: String
  }

instance showKeyPositionedParseError :: Show PositionedParseError where
  show (PositionedParseError e) = e.error <> " at position " <> show e.pos

-- | Run a parser for an input string, returning either a positioned error or a result.
runParser1 :: forall a. Parser a -> String -> Either PositionedParseError a
runParser1 (Parser p) s =
  let
    formatErr :: { pos :: Pos, error :: ParseError } -> PositionedParseError
    formatErr { pos : pos, error : ParseError e } =
      PositionedParseError { pos : pos, error : e}
  in
    bimap formatErr _.result (p { str: s, pos: 0 })

-- | Entry point - Parse an ABC tune image.
parse :: String -> Either PositionedParseError Eut1.Music1
parse s =
  case runParser1 polyphony s of
    Right n ->
      Right n

    Left e ->
      Left e
