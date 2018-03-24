module Data.Question exposing (..)

import Data.Answer exposing (Answer)


type alias Question =
    { question : String
    , answers : List Answer
    }
