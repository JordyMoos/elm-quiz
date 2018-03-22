module Quiz exposing (..)

import Data.Question exposing (Question)
import Html exposing (..)


--type alias Model =
--    { questionQueue : List Question
--    }


type alias LoadingModel =
    {}


type alias PlayingModel =
    {}


type alias FinishedModel =
    {}


type QuizState
    = LoadingQuizState LoadingModel
    | PlayingQuizState PlayingModel
    | FinishedQuizState FinishedModel


type alias Model =
    { state : QuizState
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


init : ( Model, Cmd Msg )
init =
    { state = LoadingQuizState LoadingModel } ! []


subscriptions : Model -> Sub Msg
subscriptions =
    always Sub.none


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    model ! []


view : Model -> Html Msg
view model =
    text <| toString model
