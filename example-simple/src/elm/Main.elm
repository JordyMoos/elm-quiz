module Main exposing (main)

import Quiz
import Html exposing (..)
import Json.Decode as Decode exposing (Decoder)


type Msg
    = ToQuiz Quiz.Msg


type alias Model =
    { quiz : Quiz.Quiz
    }


init : Decode.Value -> ( Model, Cmd Msg )
init flags =
    let
        ( quiz, quizCmd ) =
            Quiz.initFromJson flags
    in
        { quiz = quiz } ! [ Cmd.map ToQuiz quizCmd ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ quiz } as model) =
    case msg of
        ToQuiz quizMsg ->
            let
                ( newQuizModel, newQuizCmd ) =
                    Quiz.update quizMsg quiz
            in
                { model | quiz = newQuizModel }
                    ! [ Cmd.map ToQuiz newQuizCmd ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map ToQuiz <| Quiz.subscriptions model.quiz


view : Model -> Html Msg
view ({ quiz } as model) =
    Quiz.view quiz
        |> Html.map ToQuiz


main : Program Decode.Value Model Msg
main =
    Html.programWithFlags
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
