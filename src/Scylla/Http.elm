module Scylla.Http exposing (..)
import Scylla.Model exposing (..)
import Scylla.Api exposing (..)
import Scylla.Sync exposing (syncResponseDecoder)
import Scylla.Login exposing (loginResponseDecoder, Username, Password)
import Json.Encode exposing (object, string, int)
import Http exposing (request, emptyBody, jsonBody, expectJson)

fullUrl : ApiUrl -> ApiUrl
fullUrl s = s ++ "/_matrix/client/r0"

-- Http Requests
firstSync : ApiUrl -> ApiToken -> Cmd Msg
firstSync apiUrl token = request
    { method = "GET"
    , headers = authenticatedHeaders token
    , url = (fullUrl apiUrl) ++ "/sync"
    , body = emptyBody
    , expect = expectJson ReceiveSyncResponse syncResponseDecoder
    , timeout = Nothing
    , tracker = Nothing
    }

sync : String -> ApiUrl -> ApiToken -> Cmd Msg
sync nextBatch apiUrl token = request
    { method = "GET"
    , headers = authenticatedHeaders token
    , url = (fullUrl apiUrl) ++ "/sync" ++ "?since=" ++ (nextBatch) ++ "&timeout=10000"
    , body = emptyBody
    , expect = expectJson ReceiveSyncResponse syncResponseDecoder
    , timeout = Nothing
    , tracker = Nothing
    }

login : ApiUrl -> Username -> Password -> Cmd Msg
login apiUrl username password = request
    { method = "POST"
    , headers = basicHeaders
    , url = (fullUrl apiUrl) ++ "/login"
    , body = jsonBody <| object
        [ ("type", string "m.login.password")
        , ("identifier", object
            [ ("type", string "m.id.user")
            , ("user", string username)
            ] )
        , ("password", string password)
        ]
    , expect = expectJson ReceiveLoginResponse loginResponseDecoder
    , timeout = Nothing
    , tracker = Nothing
    }
