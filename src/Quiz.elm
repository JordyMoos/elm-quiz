module Quiz
    exposing
        ( Msg
        , Quiz(..)
        , initFromJson
        , initFromConfigBuilder
        , update
        , view
        , subscriptions
        , Difficulty(..)
        , ConfigBuilder
        , configBuilder
        , setShuffleQuestions
        , setShuffleAnswers
        , setDifficulty
        , setMaxQuestions
        )

{-| A customizable quiz powered by Elm and Polymer

See the example on github.


# Quiz

@docs Msg, Quiz
@docs initFromJson, initFromConfigBuilder, update, view, subscriptions
@docs Difficulty
@docs ConfigBuilder, configBuilder, setShuffleQuestions, setShuffleAnswers, setDifficulty, setMaxQuestions

-}

import Html exposing (..)
import Html.Events as Events exposing (onClick)
import Html.Attributes as Attributes exposing (attribute)
import Random.List
import Random
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (decode, required, optional)
import Maybe.Extra
import Time


{-| The Quiz model.
-}
type Quiz
    = Active Model
    | Stopped


{-| ConfigBuilder type allows you to make changes to the config.

@see configBuilder
@see setShuffleQuestions, setShuffleAnswers, setDifficulty, setMaxQuestions

-}
type ConfigBuilder
    = ConfigBuilder Config


type alias Model =
    { config : Config
    , game : Game
    }


type Answer
    = CorrectAnswer String
    | InvalidAnswer String


type AdditionalContent
    = Image String


type alias Question =
    { question : String
    , additionalContent : List AdditionalContent
    , answers : List Answer
    }


type alias Config =
    { providedQuestions : List Question
    , shuffleQuestions : Bool
    , shuffleAnswers : Bool
    , difficulty : Difficulty
    , maxQuestions : Int
    }


{-| Difficulty settings

The difficulties are:
`Easy`
`Normal`
`Hard`
`Speedy`
`Impossible`

Difficulties can be set in the json config.
The values are then the lower cased representation.

        Easy -- "easy"
        Normal -- "normal"
        -- etc

With setDifficulty you can set those difficulties:

        Quiz.setDifficulty Quiz.Easy configBuilder

-}
type Difficulty
    = Easy
    | Normal
    | Hard
    | Speedy
    | Impossible


type alias Game =
    { questionQueue : List Question
    , answerHistory : List AnsweredQuestion
    , state : GameState
    }


type alias AnsweredQuestion =
    { question : Question
    , chosenAnswer : ChosenAnswer
    }


type alias CountDown =
    Int


type GameState
    = ShufflingQuestionsState
    | ShufflingAnswersState Question
    | AskingQuestionState Question (Maybe CountDown)
    | ReviewAnswerState Question ChosenAnswer
    | ConclusionState


type ChosenAnswer
    = Answered Answer
    | Skipped
    | TimedOut


{-| An opaque type representing messages that are passed inside the Quiz.
-}
type Msg
    = ProvidingQuestions (List Question)
    | ProvidingAnswers (List Answer)
    | ChooseAnswer ChosenAnswer
    | NextQuestion
    | Restart
    | Stop
    | Tick Time.Time


{-| Initialize a Quiz given a config as Json.Decode.Value record.
You must always execute the returned commands.


# Example of the config

Only the "providedQuestions" is required.

    {
      "providedQuestions": [
        {
          "question": "Which nephew has a red hat?",
          "additional_content": [
            { "type": "image", "data": "https://s3.amazonaws.com/gs-geo-images/29d80404-5063-4ddd-9887-bb6f6a565588_l.jpg"}
          ],
          "answers": [
            { "type": "correct", "value": "Huey"},
            { "type": "invalid", "value": "Dewey"},
            { "type": "invalid", "value": "Louie"},
            { "type": "invalid", "value": "Donald"}
          ]
        },
        {
          "question": "Who is the richest of them all?",
          "answers": [
            { "type": "correct", "value": "Scrooge McDuck"},
            { "type": "invalid", "value": "Jeff Bezos"},
            { "type": "invalid", "value": "Bill Gates"},
            { "type": "invalid", "value": "Warren Buffett"}
          ]
        }
      ],
      "shuffleQuestions": false,
      "shuffleAnswers": false,
      "difficulty": "normal",
      "maxQuestions: 10
    }


# Example init call

    init
        let
            (quizModel, quizCmd) = Quiz.init config
        in
            { quiz = quizModel } ! [ Cmd.map ToQuiz quizCmd ]

For a detailed example see
@see example/src/elm/Main.elm

-}
initFromJson : Decode.Value -> ( Quiz, Cmd Msg )
initFromJson configJson =
    let
        config =
            Decode.decodeValue configDecoder configJson
                |> Result.withDefault defaultConfig
    in
        createGame config
            |> wrapModel


{-| Same as the initFromJson but now via a ConfigBuilder

You must always execute the returned commands.

@see ConfigBuilder

-}
initFromConfigBuilder : ConfigBuilder -> ( Quiz, Cmd Msg )
initFromConfigBuilder (ConfigBuilder config) =
    createGame config
        |> wrapModel


{-| Converts a valid quiz config from Json.Decode.Value to a ConfigBuilder.
Which allows you to make changed to the config.

@see initFromJson for an example Json.Decode.Value

-}
configBuilder : Decode.Value -> ConfigBuilder
configBuilder configJson =
    Decode.decodeValue configDecoder configJson
        |> Result.withDefault defaultConfig
        |> ConfigBuilder


{-| Overwrite the shuffle questions configuration
-}
setShuffleQuestions : Bool -> ConfigBuilder -> ConfigBuilder
setShuffleQuestions shuffleQuestions (ConfigBuilder config) =
    ConfigBuilder { config | shuffleQuestions = shuffleQuestions }


{-| Overwrite the shuffle answers configuration
-}
setShuffleAnswers : Bool -> ConfigBuilder -> ConfigBuilder
setShuffleAnswers shuffleAnswers (ConfigBuilder config) =
    ConfigBuilder { config | shuffleAnswers = shuffleAnswers }


{-| Overwrite the difficulty configuration
-}
setDifficulty : Difficulty -> ConfigBuilder -> ConfigBuilder
setDifficulty difficulty (ConfigBuilder config) =
    ConfigBuilder { config | difficulty = difficulty }


{-| Overwrite the max questions configuration
-}
setMaxQuestions : Int -> ConfigBuilder -> ConfigBuilder
setMaxQuestions maxQuestions (ConfigBuilder config) =
    ConfigBuilder { config | maxQuestions = maxQuestions }


{-| The quiz update function

Do not forget to execute the returned command (same as for init)

-}
update : Msg -> Quiz -> ( Quiz, Cmd Msg )
update msg appState =
    case appState of
        Active model ->
            innerUpdate msg model

        Stopped ->
            appState ! []


innerUpdate : Msg -> Model -> ( Quiz, Cmd Msg )
innerUpdate msg ({ config, game } as model) =
    case ( msg, model.game.state ) of
        ( ProvidingQuestions (question :: otherQuestions), ShufflingQuestionsState ) ->
            let
                ( newGameState, cmd ) =
                    determineNewQuestionState config question

                newGame =
                    { game
                        | state = newGameState
                        , questionQueue = List.take (config.maxQuestions - 1) otherQuestions
                    }
            in
                ( { model | game = newGame }, cmd ) |> wrapModel

        ( ProvidingAnswers answers, ShufflingAnswersState question ) ->
            let
                newGame =
                    { game
                        | state =
                            AskingQuestionState
                                { question | answers = answers }
                                (getCountDown model.config.difficulty)
                    }
            in
                { model | game = newGame } ! [] |> wrapModel

        ( Tick time, AskingQuestionState question (Just countDown) ) ->
            let
                newGame =
                    case countDown of
                        1 ->
                            let
                                answeredQuestion =
                                    { question = question
                                    , chosenAnswer = TimedOut
                                    }
                            in
                                { game
                                    | answerHistory = answeredQuestion :: model.game.answerHistory
                                    , state = ReviewAnswerState question TimedOut
                                }

                        _ ->
                            { game | state = AskingQuestionState question (Just (countDown - 1)) }
            in
                { model | game = newGame } ! [] |> wrapModel

        ( ChooseAnswer chosenAnswer, AskingQuestionState question _ ) ->
            let
                answeredQuestion =
                    { question = question
                    , chosenAnswer = chosenAnswer
                    }

                newGame =
                    { game
                        | answerHistory = answeredQuestion :: model.game.answerHistory
                        , state = ReviewAnswerState question chosenAnswer
                    }
            in
                { model | game = newGame } ! [] |> wrapModel

        ( NextQuestion, ReviewAnswerState _ _ ) ->
            let
                newQuestionQueue =
                    List.tail game.questionQueue |> Maybe.withDefault []

                ( newGameState, cmd ) =
                    case List.head game.questionQueue of
                        Just question ->
                            determineNewQuestionState config question

                        Nothing ->
                            ( ConclusionState, Cmd.none )

                newGame =
                    { game
                        | questionQueue = newQuestionQueue
                        , state = newGameState
                    }
            in
                ( { model | game = newGame }, cmd ) |> wrapModel

        ( Restart, _ ) ->
            createGame model.config |> wrapModel

        ( Stop, _ ) ->
            Stopped ! []

        ( _, _ ) ->
            -- Void on bibs
            model ! [] |> wrapModel


{-| subscriptions

Must always be connected else the countdown will not work.

-}
subscriptions : Quiz -> Sub Msg
subscriptions appState =
    case appState of
        Active model ->
            case model.game.state of
                AskingQuestionState _ (Just _) ->
                    Time.every Time.second Tick

                _ ->
                    Sub.none

        Stopped ->
            Sub.none


{-| view
-}
view : Quiz -> Html Msg
view appState =
    case appState of
        Active model ->
            case model.game.state of
                ShufflingQuestionsState ->
                    viewShufflingQuestions model

                ShufflingAnswersState question ->
                    viewShufflingAnswers model question

                AskingQuestionState question maybeCountDown ->
                    viewAskingQuestionState model question maybeCountDown

                ReviewAnswerState question chosenAnswer ->
                    viewReviewAnswerState model question chosenAnswer

                ConclusionState ->
                    viewConclusionState model

        Stopped ->
            text ""


viewShufflingQuestions : Model -> Html Msg
viewShufflingQuestions model =
    card
        [ attribute "heading" "Preparing questions... please wait!" ]
        []


viewShufflingAnswers : Model -> Question -> Html Msg
viewShufflingAnswers model question =
    card
        [ attribute "heading" "Preparing question... please wait!" ]
        []


viewAskingQuestionState : Model -> Question -> Maybe CountDown -> Html Msg
viewAskingQuestionState model question maybeCountDown =
    let
        buttonList =
            case List.isEmpty question.answers of
                True ->
                    [ viewSkipButton ]

                False ->
                    List.map (viewAnswerButton model.config.difficulty) question.answers

        countDownElement =
            case maybeCountDown of
                Just seconds ->
                    div
                        [ Attributes.class "countdown-container" ]
                        [ node "paper-fab"
                            [ attribute "noink" "noink"
                            , Attributes.class "countdown"
                            , attribute "label" <| toString seconds
                            ]
                            []
                        ]

                Nothing ->
                    text ""

        additionalContents =
            List.map viewAdditionalContent question.additionalContent
    in
        card
            [ attribute "heading" question.question ]
            [ countDownElement
            , div [] additionalContents
            , ul [] buttonList
            ]


viewAdditionalContent : AdditionalContent -> Html Msg
viewAdditionalContent additionalContent =
    case additionalContent of
        Image src ->
            div
                [ Attributes.align "center" ]
                [ img [ Attributes.src src ] [] ]


viewCardActions : Html Msg
viewCardActions =
    div
        [ Attributes.class "card-actions" ]
        [ cardAction Restart "Restart"
        , cardAction Stop "Stop"
        ]


viewSkipButton : Html Msg
viewSkipButton =
    li [] [ paperButton (ChooseAnswer Skipped) "Skip" ]


viewAnswerButton : Difficulty -> Answer -> Html Msg
viewAnswerButton difficulty answer =
    let
        isDisabled =
            case ( difficulty, answer ) of
                ( Impossible, CorrectAnswer _ ) ->
                    True

                _ ->
                    False

        class =
            case ( difficulty, answer ) of
                ( Easy, CorrectAnswer _ ) ->
                    "correct"

                ( Easy, InvalidAnswer _ ) ->
                    "invalid"

                _ ->
                    "default"
    in
        li
            []
            [ node "paper-button"
                [ onClick <| ChooseAnswer (Answered answer)
                , Attributes.class class
                , Attributes.disabled isDisabled
                , Attributes.attribute "raised" "raised"
                ]
                [ text <| getAnswerText answer ]
            ]


viewReviewAnswerState : Model -> Question -> ChosenAnswer -> Html Msg
viewReviewAnswerState model question chosenAnswer =
    let
        resultHtml =
            case chosenAnswer of
                Answered (CorrectAnswer answer) ->
                    String.concat
                        [ "Your answer "
                        , "\""
                        , answer
                        , "\""
                        , " is correct!"
                        ]
                        |> text

                Answered (InvalidAnswer answer) ->
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

                Skipped ->
                    "You will not get points for skipping a question!" |> text

                TimedOut ->
                    "We are so sorry but you are out of time!" |> text

        nextButtonText =
            case List.head model.game.questionQueue of
                Just _ ->
                    "Next question"

                Nothing ->
                    "Finish"
    in
        card
            [ attribute "heading" ("Review: " ++ question.question) ]
            [ p [] [ resultHtml ]
            , div
                [ Attributes.class "continue-button-container" ]
                [ paperButton NextQuestion nextButtonText ]
            ]


viewConclusionState : Model -> Html Msg
viewConclusionState model =
    let
        correct =
            List.filter
                (\answeredQuestion ->
                    case answeredQuestion.chosenAnswer of
                        Answered (CorrectAnswer _) ->
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
                        Answered (InvalidAnswer _) ->
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
                        Skipped ->
                            True

                        _ ->
                            False
                )
                model.game.answerHistory
                |> List.length

        timedOut =
            List.filter
                (\answeredQuestion ->
                    case answeredQuestion.chosenAnswer of
                        TimedOut ->
                            True

                        _ ->
                            False
                )
                model.game.answerHistory
                |> List.length
    in
        card
            [ attribute "heading" "Report" ]
            [ ul
                []
                [ li [] [ text <| "Correct: " ++ (toString correct) ]
                , li [] [ text <| "Invalid: " ++ (toString invalid) ]
                , li [] [ text <| "Skipped: " ++ (toString skipped) ]
                , li [] [ text <| "Timed out: " ++ (toString timedOut) ]
                ]
            , div
                [ Attributes.class "continue-button-container" ]
                [ paperButton Restart "Try again!" ]
            ]



--- Default stuff


defaultConfig : Config
defaultConfig =
    { providedQuestions =
        [ { question = "You configured the config wrong did not you?"
          , additionalContent = []
          , answers =
                [ CorrectAnswer "Yes I did" ]
          }
        ]
    , shuffleQuestions = False
    , shuffleAnswers = False
    , difficulty = Easy
    , maxQuestions = 10
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


getCountDown : Difficulty -> Maybe CountDown
getCountDown difficulty =
    case difficulty of
        Hard ->
            Just 10

        Speedy ->
            Just 2

        Impossible ->
            Just 5

        _ ->
            Nothing


wrapModel : ( Model, Cmd Msg ) -> ( Quiz, Cmd Msg )
wrapModel ( model, cmd ) =
    ( Active model, cmd )


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

                ( False, question :: otherQuestions ) ->
                    let
                        ( gameState, cmd ) =
                            determineNewQuestionState config question
                    in
                        ( { questionQueue = List.take (config.maxQuestions - 1) otherQuestions
                          , answerHistory = []
                          , state = gameState
                          }
                        , cmd
                        )
    in
        ( { config = config
          , game = game
          }
        , cmd
        )


determineNewQuestionState : Config -> Question -> ( GameState, Cmd Msg )
determineNewQuestionState { shuffleAnswers, difficulty } question =
    case shuffleAnswers of
        True ->
            ( ShufflingAnswersState question
            , Random.List.shuffle question.answers
                |> Random.generate ProvidingAnswers
            )

        False ->
            ( AskingQuestionState question (getCountDown difficulty)
            , Cmd.none
            )



--- WebComponent helpers


paperButton : Msg -> String -> Html Msg
paperButton msg content =
    node "paper-button"
        [ onClick msg
        , Attributes.class "default"
        , Attributes.attribute "raised" "raised"
        ]
        [ text content ]


card : List (Attribute Msg) -> List (Html Msg) -> Html Msg
card attributes contents =
    node "paper-card"
        attributes
        [ div
            [ Attributes.class "card-content" ]
            contents
        , viewCardActions
        ]


cardAction : Msg -> String -> Html Msg
cardAction msg content =
    node "paper-button"
        [ onClick msg
        , Attributes.class "card-action"
        ]
        [ text content ]



--- Decoders


configDecoder : Decoder Config
configDecoder =
    decode Config
        |> required "providedQuestions" questionsDecoder
        |> optional "shuffleQuestions" Decode.bool False
        |> optional "shuffleAnswers" Decode.bool False
        |> optional "difficulty" difficultyDecoder Normal
        |> optional "maxQuestions" Decode.int 10


questionsDecoder : Decoder (List Question)
questionsDecoder =
    Decode.list questionDecoder


questionDecoder : Decoder Question
questionDecoder =
    decode Question
        |> required "question" Decode.string
        |> optional "additional_content" additionalContentsDecoder []
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


additionalContentsDecoder : Decoder (List AdditionalContent)
additionalContentsDecoder =
    Decode.list additionalContentDecoder


additionalContentDecoder : Decoder AdditionalContent
additionalContentDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\theType ->
                case theType of
                    "image" ->
                        Decode.map Image (Decode.field "data" Decode.string)

                    _ ->
                        Decode.fail <|
                            "Trying to decode additional_content, but type "
                                ++ theType
                                ++ " is not supported."
            )


difficultyDecoder : Decoder Difficulty
difficultyDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case str of
                    "easy" ->
                        Decode.succeed Easy

                    _ ->
                        Decode.succeed Normal
            )
