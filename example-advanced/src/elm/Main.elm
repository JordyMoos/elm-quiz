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
    | GameState Quiz.Quiz


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


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ state, flags } as model) =
    case ( msg, state ) of
        ( ToQuiz quizMsg, GameState quiz ) ->
            let
                ( newQuizModel, newQuizCmd ) =
                    Quiz.update quizMsg quiz
            in
                { model | state = GameState newQuizModel }
                    ! [ Cmd.map ToQuiz newQuizCmd ]

        ( SelectDifficulty difficulty, PrepareState prepareModel ) ->
            let
                newPrepareModel =
                    { prepareModel | difficulty = difficulty }
            in
                { model | state = PrepareState newPrepareModel } ! []

        ( _, _ ) ->
            model ! []


subscriptions : Model -> Sub Msg
subscriptions ({ state } as model) =
    case state of
        GameState quiz ->
            Sub.map ToQuiz <| Quiz.subscriptions quiz

        _ ->
            Sub.none


view : Model -> Html Msg
view ({ state } as model) =
    case state of
        PrepareState prepareModel ->
            viewPrepareState prepareModel

        GameState quiz ->
            Quiz.view quiz
                |> Html.map ToQuiz


viewPrepareState : PrepareModel -> Html Msg
viewPrepareState model =
    div
        [ Attributes.class "prepare-container" ]
        [ node "paper-dropdown-menu"
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

            --                    , attribute "noAnimations" "noAnimations"
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
        ]


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
