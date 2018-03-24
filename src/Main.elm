module Main exposing (main)

import Html exposing (..)


type alias Model =
    { config : Config
    , game : Game
    }


type Answer
    = CorrectAnswer String
    | InvalidAnswer String


type alias Question =
    { question : String
    , answers : List Answer
    }


type alias Config =
    { providedQuestions : List Question
    }


type alias Game =
    { questionQueue : List Question
    , answerHistory : List AnsweredQuestion
    , state : GameState
    }


type alias AnsweredQuestion =
    { question : String
    , chosenAnswer : Maybe Answer -- You could skip the question
    }


type GameState
    = AskingQuestionState Question
    | ReviewAnswerState Question (Maybe Answer)
    | ConclusionState


type Msg
    = NoOp


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , update = update
        , view = view
        , subscriptions = always Sub.none
        }


sampleConfig : Config
sampleConfig =
    { providedQuestions =
        [ { question = "Which nephew has a red hat?"
          , answers =
                [ CorrectAnswer "Huey"
                , InvalidAnswer "Dewey"
                , InvalidAnswer "Louie"
                , InvalidAnswer "Donald"
                ]
          }
        , { question = "Who is the richest of them all?"
          , answers =
                [ CorrectAnswer "Scrooge McDuck"
                , InvalidAnswer "Jeff Bezos"
                , InvalidAnswer "Bill Gates"
                , InvalidAnswer "Warren Buffett"
                ]
          }
        , { question = "Is this a trick question?"
          , answers =
                [ CorrectAnswer "Yes"
                , CorrectAnswer "Yes"
                , CorrectAnswer "Yes"
                , CorrectAnswer "Yes"
                ]
          }
        , { question = "Can I get this question right?"
          , answers =
                [ InvalidAnswer "No"
                , InvalidAnswer "No"
                , InvalidAnswer "No"
                , InvalidAnswer "No"
                ]
          }
        , { question = "Can I get less answers?"
          , answers =
                [ CorrectAnswer "Yes"
                ]
          }
        ]
    }


init : ( Model, Cmd Msg )
init =
    { config = sampleConfig
    , game = ""
    }
        ! []


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    model ! []


view : Model -> Html Msg
view model =
    text <| toString model
