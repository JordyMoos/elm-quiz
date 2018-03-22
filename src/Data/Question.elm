module Data.Question exposing (..)


type alias Question =
    { title : String
    , correctAnswer : String
    , invalidAnswers : List String
    }