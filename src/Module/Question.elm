module Module.Question exposing (..)

import Html exposing (..)
import Html.Events exposing (onClick)


type State
    = AskingQuestion AskingQuestionModel
    | ShowingResult ShowingResultModel


type alias AskingQuestionModel =
    { question : String
    , answers : List Answer
    }


type alias ShowingResultModel =
    { question : String
    , answered : Answer
    , wasCorrect : Bool
    }


type alias Model =
    { state : State
    }


type Answer
    = CorrectAnswer String
    | InvalidAnswer String


createCorrectAnswer : String -> CorrectAnswer
createCorrectAnswer =
    CorrectAnswer


createInvalidAnswer : String -> CorrectAnswer
createInvalidAnswer =
    InvalidAnswer


getText : Answer -> String
getText answer =
    case answer of
        CorrectAnswer text ->
            text

        InvalidAnswer text ->
            text


isCorrect : Answer -> Bool
isCorrect answer =
    case answer of
        CorrectAnswer _ ->
            True

        InvalidAnswer _ ->
            False


init : String -> List Answer -> Model
init question answers =
    let
        stateModel =
            { question = question
            , answers = answers
            }
    in
        { state = AskingQuestion stateModel
        }


type Msg
    = NoOp
    | Guessed Answer
    | Continue


type SupervisorCmd
    = None
    | Answered


update : Msg -> Model -> ( Model, Cmd Msg, SupervisorCmd )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none, None )

        Guessed answer ->
            let
                newStateModel =
                    { question = model.question
                    , answered = answer
                    , wasCorrect = isCorrect answer
                    }

                newModel =
                    { state = newStateModel
                    }
            in
                ( newModel, Cmd.none, None )

        Continue ->
            ( model, Cmd.none, Answered )


view : Model -> Html Msg
view model =
    case model.state of
        AskingQuestion stateModel ->
            viewAskingQuestion stateModel

        ShowingResult stateModel ->
            viewShowingResult stateModel


viewAskingQuestion : AskingQuestionModel -> Html Msg
viewAskingQuestion model =
    div
        []
        [ h1 [] [ text model.question ]
        , ul
            []
            (List.map viewAnswerButton model.answers)
        ]


viewAnswerButton : Answer -> Html Msg
viewAnswerButton answer =
    li
        []
        [ button [ onClick (Guessed answer) ] [ text <| getText answer ]
        ]


viewShowingResult : ShowingResultModel -> Html Msg
viewShowingResult model =
    div
        []
        [ viewResult model
        , viewContinueButton
        ]


viewResult : ShowingResultModel -> Html Msg
viewResult model =
    if model.wasCorrect then
        viewResultCorrect model
    else
        viewResultInvalid model


viewResultCorrect : ShowingResultModel -> Html Msg
viewResultCorrect model =
    div
        []
        [ h1 [] [ text "The answer is correct!" ] ]


viewResultInvalid : ShowingResultModel -> Html Msg
viewResultInvalid model =
    div
        []
        [ h1 [] [ text "Tooo bad" ] ]


viewContinueButton : Html Msg
viewContinueButton =
    div
        []
        [ button [ onClick Continue ] [ text "Continue" ] ]
