module Quiz exposing (main)

import Html exposing (..)
import Html.Events as Events exposing (onClick)
import Html.Attributes as Attributes exposing (attribute)
import Random.List
import Random
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (decode, required, optional)
import Maybe.Extra


type alias Model =
    { config : Config
    , game : Game
    , guiState : GuiState
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
    , shuffleQuestions : Bool
    , title : String
    }


type alias GuiState =
    { drawerOpened : Bool
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
    = ShufflingQuestionsState
    | AskingQuestionState Question
    | ReviewAnswerState Question (Maybe Answer)
    | ConclusionState


type Msg
    = NoOp
    | DrawerStatus Bool
    | ProvidingQuestions (List Question)
    | ChosenAnswer (Maybe Answer)
    | NextQuestion
    | Restart


main : Program Decode.Value Model Msg
main =
    Html.programWithFlags
        { init = init
        , update = update
        , view = view
        , subscriptions = always Sub.none
        }


init : Decode.Value -> ( Model, Cmd Msg )
init configJson =
    let
        config =
            Decode.decodeValue configDecoder configJson
                |> Result.withDefault defaultConfig
    in
        createGame config


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.game.state ) of
        ( DrawerStatus status, _ ) ->
            let
                guiState =
                    model.guiState

                newGuiState =
                    { guiState | drawerOpened = status }
            in
                { model | guiState = newGuiState } ! []

        ( ProvidingQuestions (firstQuestion :: otherQuestions), ShufflingQuestionsState ) ->
            let
                game =
                    model.game

                newGame =
                    { game
                        | state = AskingQuestionState firstQuestion
                        , questionQueue = otherQuestions
                    }
            in
                { model | game = newGame } ! []

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
            createGame model.config

        ( _, _ ) ->
            -- Void on bibs
            model ! []


view : Model -> Html Msg
view model =
    (case model.game.state of
        ShufflingQuestionsState ->
            viewShufflingQuestions model

        AskingQuestionState question ->
            viewAskingQuestionState model question

        ReviewAnswerState question maybeAnswer ->
            viewReviewAnswerState model question maybeAnswer

        ConclusionState ->
            viewConclusionState model
    )
        |> viewWrapInLayout model


viewWrapInLayout : Model -> Html Msg -> Html Msg
viewWrapInLayout { config, guiState } content =
    let
        drawerOpenStatus =
            case guiState.drawerOpened of
                True ->
                    [ attribute "opened" "opened" ]

                False ->
                    []

        drawerAttributes =
            List.append
                drawerOpenStatus
                [ Attributes.id "drawer"
                , attribute "swipe-open" "swipe-open"
                , onDrawerStatusChange
                ]
    in
        div
            []
            [ node "app-header"
                [ attribute "reveals" "reveals" ]
                [ node "app-toolbar"
                    []
                    [ node "paper-icon-button" [ attribute "icon" "menu", onClick (DrawerStatus True) ] []
                    , div [ attribute "main-title" "main-title" ] [ text config.title ]
                    ]
                ]
            , Html.main_ [] [ content ]
            , node "app-drawer"
                drawerAttributes
                [ node "app-header-layout"
                    []
                    [ node "app-header"
                        [ Attributes.class "blueHeader"
                        , attribute "waterfall" "waterfall"
                        , attribute "fixed" "fixed"
                        , attribute "slot" "header"
                        ]
                        [ node "app-toolbar"
                            []
                            [ div [ attribute "main-title" "main-title" ] [ text "Menu" ] ]
                        ]
                    , node "paper-icon-item"
                        [ Attributes.class "iconItem", onClick (DrawerStatus False) ]
                        [ node "iron-icon" [ Attributes.class "grayIcon", attribute "icon" "done", attribute "slot" "item-icon" ] []
                        , span [] [ text "Questions" ]
                        ]
                    , node "paper-icon-item"
                        [ Attributes.class "iconItem", onClick Restart ]
                        [ node "iron-icon" [ Attributes.class "grayIcon", attribute "icon" "av:fast-rewind", attribute "slot" "item-icon" ] []
                        , span [] [ text "Restart" ]
                        ]
                    ]
                ]
            ]


onDrawerStatusChange : Attribute Msg
onDrawerStatusChange =
    Events.on "opened-changed" <|
        Decode.map DrawerStatus
            (Decode.at [ "detail", "value" ] Decode.bool)


viewShufflingQuestions : Model -> Html Msg
viewShufflingQuestions model =
    node "paper-card"
        [ attribute "heading" "Preparing questions... please wait!" ]
        []


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
        node "paper-card"
            [ attribute "heading" question.question ]
            [ div
                [ Attributes.class "card-content" ]
                [ ul [] buttonList ]
            ]


viewSkipButton : Html Msg
viewSkipButton =
    li [] [ paperButton (ChosenAnswer Nothing) "Skip" ]


viewAnswerButton : Answer -> Html Msg
viewAnswerButton answer =
    li [] [ paperButton (ChosenAnswer (Just answer)) (getAnswerText answer) ]


viewReviewAnswerState : Model -> Question -> Maybe Answer -> Html Msg
viewReviewAnswerState model question maybeAnswer =
    let
        resultHtml =
            case maybeAnswer of
                Just (CorrectAnswer answer) ->
                    String.concat
                        [ "Your answer "
                        , "\""
                        , answer
                        , "\""
                        , " is correct!"
                        ]
                        |> text

                Just (InvalidAnswer answer) ->
                    let
                        invalidAnswerMessage =
                            String.concat
                                [ "We are so sorry but your answer "
                                , "\""
                                , answer
                                , "\""
                                , " is incorrect!"
                                ]

                        correctAnswers =
                            List.map
                                (\answer ->
                                    case answer of
                                        CorrectAnswer value ->
                                            Just value

                                        _ ->
                                            Nothing
                                )
                                question.answers
                                |> Maybe.Extra.values

                        correctAnswersMessage =
                            case correctAnswers of
                                [] ->
                                    "There where no correct answers"

                                answer :: [] ->
                                    "The correct answer was: " ++ answer

                                answers ->
                                    "The correct answers where: " ++ (String.join ", " answers)
                    in
                        div
                            []
                            [ p [] [ text invalidAnswerMessage ]
                            , p [] [ text correctAnswersMessage ]
                            ]

                Nothing ->
                    "You will not get points for skipping a question!" |> text

        nextButtonText =
            case List.head model.game.questionQueue of
                Just _ ->
                    "Next question"

                Nothing ->
                    "Finish"
    in
        node "paper-card"
            [ attribute "heading" ("Review: " ++ question.question) ]
            [ div
                [ Attributes.class "card-content" ]
                [ p [] [ resultHtml ]
                , div
                    [ Attributes.class "continue-button-container" ]
                    [ paperButton NextQuestion nextButtonText ]
                ]
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
        node "paper-card"
            [ attribute "heading" "Report" ]
            [ div
                [ Attributes.class "card-content" ]
                [ ul
                    []
                    [ li [] [ text <| "Correct: " ++ (toString correct) ]
                    , li [] [ text <| "Invalid: " ++ (toString invalid) ]
                    , li [] [ text <| "Skipped: " ++ (toString skipped) ]
                    ]
                , div
                    [ Attributes.class "continue-button-container" ]
                    [ paperButton Restart "Try again!" ]
                ]
            ]



--- Default stuff


defaultGuiState : GuiState
defaultGuiState =
    { drawerOpened = False
    }


defaultConfig : Config
defaultConfig =
    { providedQuestions =
        [ { question = "You configured the config wrong did not you?"
          , answers =
                [ CorrectAnswer "Yes I did" ]
          }
        ]
    , shuffleQuestions = False
    , title = "Elm Quiz!"
    }



--- Answer helpers


getAnswerText : Answer -> String
getAnswerText answer =
    case answer of
        CorrectAnswer text ->
            text

        InvalidAnswer text ->
            text



--- Other helpers


createGame : Config -> ( Model, Cmd Msg )
createGame config =
    let
        ( game, cmd ) =
            case ( config.shuffleQuestions, config.providedQuestions ) of
                ( _, [] ) ->
                    -- No questions
                    ( { questionQueue = []
                      , answerHistory = []
                      , state = ConclusionState
                      }
                    , Cmd.none
                    )

                ( True, questions ) ->
                    -- Shuffle questions
                    ( { questionQueue = []
                      , answerHistory = []
                      , state = ShufflingQuestionsState
                      }
                    , Random.List.shuffle config.providedQuestions
                        |> Random.generate ProvidingQuestions
                    )

                ( False, firstQuestion :: otherQuestions ) ->
                    ( { questionQueue = otherQuestions
                      , answerHistory = []
                      , state = AskingQuestionState firstQuestion
                      }
                    , Cmd.none
                    )
    in
        ( { config = config
          , game = game
          , guiState = defaultGuiState
          }
        , cmd
        )



--- Webcomponent helpers


paperButton : Msg -> String -> Html Msg
paperButton msg content =
    node "paper-button"
        [ onClick msg, Attributes.class "indigo", Attributes.attribute "raised" "raised" ]
        [ text content ]



--- Decoders


configDecoder : Decoder Config
configDecoder =
    decode Config
        |> required "providedQuestions" questionsDecoder
        |> optional "shuffleQuestions" Decode.bool False
        |> optional "title" Decode.string "Elm Quiz!"


questionsDecoder : Decoder (List Question)
questionsDecoder =
    Decode.list questionDecoder


questionDecoder : Decoder Question
questionDecoder =
    decode Question
        |> required "question" Decode.string
        |> required "answers" answersDecoder


answersDecoder : Decoder (List Answer)
answersDecoder =
    Decode.list answerDecoder


answerDecoder : Decoder Answer
answerDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\theType ->
                case theType of
                    "correct" ->
                        Decode.map CorrectAnswer (Decode.field "value" Decode.string)

                    _ ->
                        Decode.map InvalidAnswer (Decode.field "value" Decode.string)
            )
