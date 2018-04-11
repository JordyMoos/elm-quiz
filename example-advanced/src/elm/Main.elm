module Main exposing (main)

import Quiz
import Html exposing (..)
import Html.Attributes as Attributes exposing (attribute)
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)


type alias PrepareModel =
    { difficulty : Quiz.Difficulty
    , maxQuestions : Maybe Int
    , shuffleQuestions : Bool
    }


type State
    = PrepareState PrepareModel
    | QuizState Quiz.Quiz


type alias Model =
    { state : State
    , flags : Decode.Value
    }


init : Decode.Value -> ( Model, Cmd Msg )
init flags =
    { state =
        PrepareState <|
            { difficulty = Quiz.Normal
            , maxQuestions = Nothing
            , shuffleQuestions = False
            }
    , flags = flags
    }
        ! []


type Msg
    = ToQuiz Quiz.Msg
    | SelectDifficulty Quiz.Difficulty
    | SelectShuffleQuestions Bool
    | StartQuiz


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ state, flags } as model) =
    case ( msg, state ) of
        ( ToQuiz quizMsg, QuizState quiz ) ->
            case Quiz.update quizMsg quiz of
                ( Quiz.Active newQuizModel, newQuizCmd ) ->
                    { model | state = QuizState (Quiz.Active newQuizModel) }
                        ! [ Cmd.map ToQuiz newQuizCmd ]

                ( Quiz.Stopped, _ ) ->
                    { state =
                        PrepareState <|
                            { difficulty = Quiz.Normal
                            , maxQuestions = Nothing
                            , shuffleQuestions = False
                            }
                    , flags = flags
                    }
                        ! []

        ( SelectDifficulty difficulty, PrepareState prepareModel ) ->
            let
                newPrepareModel =
                    { prepareModel | difficulty = difficulty }
            in
                { model | state = PrepareState newPrepareModel } ! []

        ( SelectShuffleQuestions shuffleQuestions, PrepareState prepareModel ) ->
            let
                newPrepareModel =
                    { prepareModel | shuffleQuestions = shuffleQuestions }
            in
                { model | state = PrepareState newPrepareModel } ! []

        ( StartQuiz, PrepareState prepareModel ) ->
            let
                ( quiz, quizCmd ) =
                    Quiz.configBuilder flags
                        |> Quiz.setDifficulty prepareModel.difficulty
                        |> Quiz.setShuffleQuestions prepareModel.shuffleQuestions
                        |> Quiz.initFromConfigBuilder
            in
                { model | state = QuizState quiz } ! [ Cmd.map ToQuiz quizCmd ]

        ( _, _ ) ->
            model ! []


subscriptions : Model -> Sub Msg
subscriptions ({ state } as model) =
    case state of
        QuizState quiz ->
            Sub.map ToQuiz <| Quiz.subscriptions quiz

        _ ->
            Sub.none


view : Model -> Html Msg
view ({ state } as model) =
    case state of
        PrepareState prepareModel ->
            viewPrepareState prepareModel

        QuizState quiz ->
            Quiz.view quiz
                |> Html.map ToQuiz


viewPrepareState : PrepareModel -> Html Msg
viewPrepareState model =
    node "main"
        [ Attributes.class "prepare-container" ]
        [ node "paper-card"
            [ attribute "heading" "Configure the quiz!" ]
            [ div
                [ Attributes.class "card-content" ]
                [ div [ Attributes.class "difficulty" ] [ viewDifficulty model ]
                , div [ Attributes.class "shuffle-questions" ] [ viewShuffleQuestions model ]
                ]
            , div
                [ Attributes.class "card-actions" ]
                [ viewSubmitButton ]
            ]
        ]


viewDifficulty : PrepareModel -> Html Msg
viewDifficulty model =
    node "paper-dropdown-menu"
        [ attribute "label" "Difficulty"
        , Events.on "value-changed"
            (Decode.map SelectDifficulty
                ((Decode.at [ "detail", "value" ] Decode.string)
                    |> Decode.andThen
                        (\difficulty ->
                            case difficulty of
                                "Easy" ->
                                    Decode.succeed Quiz.Easy

                                "Normal" ->
                                    Decode.succeed Quiz.Normal

                                "Hard" ->
                                    Decode.succeed Quiz.Hard

                                "Speedy" ->
                                    Decode.succeed Quiz.Speedy

                                "Impossible" ->
                                    Decode.succeed Quiz.Impossible

                                _ ->
                                    Decode.fail "Invalid value"
                        )
                )
            )
        , attribute "noAnimations" "noAnimations"
        ]
        [ node "paper-listbox"
            [ Attributes.class "dropdown-content"
            , attribute "slot" "dropdown-content"
            , attribute "selected" <| getSelectedIndex model.difficulty
            ]
            [ node "paper-item" [] [ text <| describeDifficulty Quiz.Easy ]
            , node "paper-item" [] [ text <| describeDifficulty Quiz.Normal ]
            , node "paper-item" [] [ text <| describeDifficulty Quiz.Hard ]
            , node "paper-item" [] [ text <| describeDifficulty Quiz.Speedy ]
            , node "paper-item" [] [ text <| describeDifficulty Quiz.Impossible ]
            ]
        ]


viewShuffleQuestions : PrepareModel -> Html Msg
viewShuffleQuestions model =
    node "paper-checkbox"
        [ Attributes.checked model.shuffleQuestions
        , Events.on "checked-changed" <|
            Decode.map SelectShuffleQuestions <|
                Decode.at [ "detail", "value" ] Decode.bool
        ]
        [ text "Shuffle questions" ]


viewSubmitButton : Html Msg
viewSubmitButton =
    node "paper-button"
        [ Events.onClick StartQuiz
        , Attributes.class "default"
        ]
        [ text "Start the quiz!" ]


describeDifficulty : Quiz.Difficulty -> String
describeDifficulty difficulty =
    case difficulty of
        Quiz.Easy ->
            "Easy"

        Quiz.Normal ->
            "Normal"

        Quiz.Hard ->
            "Hard"

        Quiz.Speedy ->
            "Speedy"

        Quiz.Impossible ->
            "Impossible"


getSelectedIndex : Quiz.Difficulty -> String
getSelectedIndex difficulty =
    case difficulty of
        Quiz.Easy ->
            "0"

        Quiz.Normal ->
            "1"

        Quiz.Hard ->
            "2"

        Quiz.Speedy ->
            "3"

        Quiz.Impossible ->
            "4"


main : Program Decode.Value Model Msg
main =
    Html.programWithFlags
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
