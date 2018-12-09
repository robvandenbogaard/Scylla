import Browser exposing (application, UrlRequest(..))
import Browser.Navigation as Nav
import Scylla.Sync exposing (..)
import Scylla.Login exposing (..)
import Scylla.Model exposing (..)
import Scylla.Http exposing (..)
import Scylla.Views exposing (viewFull)
import Scylla.Route exposing (Route(..))
import Url exposing (Url)
import Url.Parser exposing (parse)
import Url.Builder
import Html exposing (div, text)
import Http

type alias Flags =
    { token : Maybe String
    }

init : Flags -> Url -> Nav.Key -> (Model, Cmd Msg)
init flags url key =
    let
        model =
            { key = key
            , route = Maybe.withDefault Unknown <| parse Scylla.Route.route url
            , token = flags.token
            , loginUsername = ""
            , loginPassword = ""
            , apiUrl = "https://matrix.org"
            , sync =
                { nextBatch = ""
                , rooms = Nothing
                , presence = Nothing
                , accountData = Nothing
                }
            , errors = []
            }
        cmd = case flags.token of
            Just _ -> Cmd.none
            Nothing -> Nav.pushUrl key <| Url.Builder.absolute [ "login" ] []
    in
        (model, cmd)

view : Model -> Browser.Document Msg
view m =
    { title = "Scylla"
    , body = viewFull m
    }

update : Msg -> Model -> (Model, Cmd Msg)
update msg model = case msg of
    ChangeApiUrl u -> ({ model | apiUrl = u }, Cmd.none)
    ChangeLoginUsername u -> ({ model | loginUsername = u }, Cmd.none)
    ChangeLoginPassword p -> ({ model | loginPassword = p }, Cmd.none)
    AttemptLogin -> (model, Scylla.Http.login model.apiUrl model.loginUsername model.loginPassword) -- TODO 
    TryUrl urlRequest -> updateTryUrl model urlRequest
    ChangeRoute r -> ({ model | route = r }, Cmd.none)
    ReceiveLoginResponse r -> updateLoginResponse model r
    ReceiveSyncResponse r -> updateSyncResponse model r

updateTryUrl : Model -> Browser.UrlRequest -> (Model, Cmd Msg)
updateTryUrl m ur = case ur of
    Internal u -> (m, Nav.pushUrl m.key (Url.toString u))
    _ -> (m, Cmd.none)

updateLoginResponse : Model -> Result Http.Error LoginResponse -> (Model, Cmd Msg)
updateLoginResponse model r = case r of
    Ok lr -> ( { model | token = Just lr.accessToken } , Cmd.batch
        [ firstSync model.apiUrl lr.accessToken
        , Nav.pushUrl model.key <| Url.Builder.absolute [] []
        ] )
    Err e  -> (model, Cmd.none)

updateSyncResponse : Model -> Result Http.Error SyncResponse -> (Model, Cmd Msg)
updateSyncResponse model r = let sync = model.sync in case r of
    Ok sr -> ({ model | sync = mergeSyncResponse model.sync sr }, Cmd.none)
    _ -> (model, Cmd.none)

subscriptions : Model -> Sub Msg
subscriptions m = Sub.none

onUrlRequest : Browser.UrlRequest -> Msg
onUrlRequest = TryUrl

onUrlChange : Url -> Msg
onUrlChange = ChangeRoute << Maybe.withDefault Unknown << parse Scylla.Route.route

main = application
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    , onUrlRequest = onUrlRequest
    , onUrlChange = onUrlChange
    }
