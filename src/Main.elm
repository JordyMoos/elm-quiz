module Main exposing (main)

import Html exposing (..)
import Html.Events exposing (onClick)


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
    { question : Question
    , chosenAnswer : Maybe Answer -- You could skip the question
    }


type GameState
    = AskingQuestionState Question
    | ReviewAnswerState Question (Maybe Answer)
    | ConclusionState


type Msg
    = NoOp
    | ChosenAnswer Answer


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
    let
        currentQuestion =
            List.head sampleConfig.providedQuestions

        questionQueue =
            List.tail sampleConfig.providedQuestions |> Maybe.withDefault []

        gameState =
            case currentQuestion of
                Just question ->
                    AskingQuestionState question

                Nothing ->
                    ConclusionState
    in
        { config = sampleConfig
        , game =
            { questionQueue = questionQueue
            , answerHistory = []
            , state = gameState
            }
        }
            ! []


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.game.state ) of
        ( ChosenAnswer answer, AskingQuestionState question ) ->
            let
                answeredQuestion =
                    { question = question
                    , chosenAnswer = Just answer
                    }

                game =
                    model.game

                newGame =
                    { game
                        | answerHistory = answeredQuestion :: model.game.answerHistory
                        , state = ReviewAnswerState question (Just answer)
                    }
            in
                { model | game = newGame } ! []

        ( _, _ ) ->
            -- Void on bibs
            model ! []


view : Model -> Html Msg
view model =
    case model.game.state of
        AskingQuestionState question ->
            viewAskingQuestionState model question

        ReviewAnswerState question maybeAnswer ->
            viewReviewAnswerState model question maybeAnswer

        ConclusionState ->
            viewConclusionState model


viewAskingQuestionState : Model -> Question -> Html Msg
viewAskingQuestionState model question =
    div
        []
        [ h1 [] [ text question.question ]
        , div
            []
            [ ul
                []
                (List.map viewAnswerButton question.answers)
            ]
        ]


viewAnswerButton : Answer -> Html Msg
viewAnswerButton answer =
    li
        []
        [ button
            [ onClick (ChosenAnswer answer) ]
            [ text <| getAnswerText answer ]
        ]


viewReviewAnswerState : Model -> Question -> Maybe Answer -> Html Msg
viewReviewAnswerState model question maybeAnswer =
    text "View review answer state"


viewConclusionState : Model -> Html Msg
viewConclusionState model =
    text "View conclusion state"



--- Answer helpers


getAnswerText : Answer -> String
getAnswerText answer =
    case answer of
        CorrectAnswer text ->
            text

        InvalidAnswer text ->
            text
