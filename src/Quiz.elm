module Quiz exposing (..)

import Html exposing (..)
import Html.Attributes as Attributes
import Data.Question as Question
import Data.Answer as Answer


type alias PresentingQuestionModel =
    { currentQuestion : Question.Question
    , questionQueue : List Question.Question
    }


type GameState
    = PresentingQuestion PresentingQuestionModel


type alias Model =
    { state : GameState
    }


type Msg
    = NoOp


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


sampleData : Question.Question
sampleData =
    { question = "Which nephew often wears a red hat?"
    , answers =
        [ Answer.Correct "Huey"
        , Answer.Invalid "Dewey"
        , Answer.Invalid "Louie"
        , Answer.Invalid "Donald"
        ]
    }


init : ( Model, Cmd Msg )
init =
    let
        stateModel =
            { currentQuestion = sampleData
            , questionQueue = []
            }
    in
        { state = PresentingQuestion stateModel } ! []


subscriptions : Model -> Sub Msg
subscriptions =
    always Sub.none


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    model ! []


view : Model -> Html Msg
view model =
    case model.state of
        PresentingQuestion gameModel ->
