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
    | ChosenAnswer (Maybe Answer)
    | NextQuestion
    | Restart


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
        , { question = "Can I get even less answers?"
          , answers = []
          }
        ]
    }


init : ( Model, Cmd Msg )
init =
    { config = sampleConfig
    , game = createGame sampleConfig
    }
        ! []


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.game.state ) of
        ( ChosenAnswer maybeAnswer, AskingQuestionState question ) ->
            let
                game =
                    model.game

                answeredQuestion =
                    { question = question
                    , chosenAnswer = maybeAnswer
                    }

                newGame =
                    { game
                        | answerHistory = answeredQuestion :: model.game.answerHistory
                        , state = ReviewAnswerState question maybeAnswer
                    }
            in
                { model | game = newGame } ! []

        ( NextQuestion, ReviewAnswerState _ _ ) ->
            let
                game =
                    model.game

                newQuestionQueue =
                    List.tail game.questionQueue |> Maybe.withDefault []

                newGameState =
                    case List.head game.questionQueue of
                        Just question ->
                            AskingQuestionState question

                        Nothing ->
                            ConclusionState

                newGame =
                    { game
                        | questionQueue = newQuestionQueue
                        , state = newGameState
                    }
            in
                { model | game = newGame } ! []

        ( Restart, _ ) ->
            { model | game = createGame model.config } ! []

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
    let
        buttonList =
            case List.isEmpty question.answers of
                True ->
                    [ viewSkipButton ]

                False ->
                    List.map viewAnswerButton question.answers
    in
        div
            []
            [ h1 [] [ text question.question ]
            , div [] [ ul [] buttonList ]
            ]


viewSkipButton : Html Msg
viewSkipButton =
    li
        []
        [ button
            [ onClick (ChosenAnswer Nothing) ]
            [ text "Skip" ]
        ]


viewAnswerButton : Answer -> Html Msg
viewAnswerButton answer =
    li
        []
        [ button
            [ onClick (ChosenAnswer (Just answer)) ]
            [ text <| getAnswerText answer ]
        ]


viewReviewAnswerState : Model -> Question -> Maybe Answer -> Html Msg
viewReviewAnswerState model question maybeAnswer =
    let
        resultText =
            case maybeAnswer of
                Just (CorrectAnswer answer) ->
                    String.concat
                        [ "Your answer "
                        , "\""
                        , answer
                        , "\""
                        , " is correct!"
                        ]

                Just (InvalidAnswer answer) ->
                    String.concat
                        [ "We are so sorry but your answer "
                        , "\""
                        , answer
                        , "\""
                        , " is incorrect!"
                        ]

                Nothing ->
                    "You will not get points for skipping a question!"

        nextButtonText =
            case List.head model.game.questionQueue of
                Just _ ->
                    "Next question"

                Nothing ->
                    "Finish"
    in
        div
            []
            [ h1 [] [ text ("Review: " ++ question.question) ]
            , div [] [ text resultText ]
            , div
                []
                [ button [ onClick NextQuestion ] [ text nextButtonText ] ]
            ]


viewConclusionState : Model -> Html Msg
viewConclusionState model =
    let
        correct =
            List.filter
                (\answeredQuestion ->
                    case answeredQuestion.chosenAnswer of
                        Just (CorrectAnswer _) ->
                            True

                        _ ->
                            False
                )
                model.game.answerHistory
                |> List.length

        invalid =
            List.filter
                (\answeredQuestion ->
                    case answeredQuestion.chosenAnswer of
                        Just (InvalidAnswer _) ->
                            True

                        _ ->
                            False
                )
                model.game.answerHistory
                |> List.length

        skipped =
            List.filter
                (\answeredQuestion ->
                    case answeredQuestion.chosenAnswer of
                        Nothing ->
                            True

                        _ ->
                            False
                )
                model.game.answerHistory
                |> List.length
    in
        div
            []
            [ h1 [] [ text ("Report") ]
            , ul
                []
                [ li [] [ text <| "Correct: " ++ (toString correct) ]
                , li [] [ text <| "Invalid: " ++ (toString invalid) ]
                , li [] [ text <| "Skipped: " ++ (toString skipped) ]
                ]
            , div
                []
                [ button [ onClick Restart ] [ text "Try again!" ]
                ]
            ]



--- Answer helpers


getAnswerText : Answer -> String
getAnswerText answer =
    case answer of
        CorrectAnswer text ->
            text

        InvalidAnswer text ->
            text



--- Other helpers


createGame : Config -> Game
createGame config =
    let
        currentQuestion =
            List.head config.providedQuestions

        questionQueue =
            List.tail config.providedQuestions |> Maybe.withDefault []

        gameState =
            case currentQuestion of
                Just question ->
                    AskingQuestionState question

                Nothing ->
                    ConclusionState
    in
        { questionQueue = questionQueue
        , answerHistory = []
        , state = gameState
        }
