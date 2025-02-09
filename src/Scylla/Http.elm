module Scylla.Http exposing (..)

import File exposing (File, mime, name)
import Http exposing (emptyBody, expectJson, expectWhatever, fileBody, jsonBody, request)
import Json.Decode exposing (field)
import Json.Encode exposing (bool, int, list, object, string)
import Scylla.Api exposing (..)
import Scylla.Login exposing (Password, Username, loginResponseDecoder)
import Scylla.Model exposing (..)
import Scylla.Route exposing (RoomId)
import Scylla.Sync exposing (historyResponseDecoder, syncResponseDecoder)
import Scylla.UserData exposing (UserData, userDataDecoder)
import Url.Builder


firstSyncFilter : Json.Decode.Value
firstSyncFilter =
    object
        [ ( "room"
          , object
                [ ( "state"
                  , object
                        [ ( "types", list string [ "m.room.name", "m.room.member" ] )
                        ]
                  )
                ]
          )
        ]


firstSyncFilterString : String
firstSyncFilterString =
    Json.Encode.encode 0 firstSyncFilter


fullClientUrl : ApiUrl -> ApiUrl
fullClientUrl s =
    s ++ "/_matrix/client/r0"


fullMediaUrl : ApiUrl -> ApiUrl
fullMediaUrl s =
    s ++ "/_matrix/media/r0"



-- Http Requests


firstSync : ApiUrl -> ApiToken -> Cmd Msg
firstSync apiUrl token =
    request
        { method = "GET"
        , headers = authenticatedHeaders token
        , url = Url.Builder.crossOrigin (fullClientUrl apiUrl) [ "sync" ] [ Url.Builder.string "filter" firstSyncFilterString ]
        , body = emptyBody
        , expect = expectJson ReceiveFirstSyncResponse syncResponseDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


sync : ApiUrl -> ApiToken -> String -> Cmd Msg
sync apiUrl token nextBatch =
    request
        { method = "GET"
        , headers = authenticatedHeaders token
        , url = fullClientUrl apiUrl ++ "/sync" ++ "?since=" ++ nextBatch ++ "&timeout=10000"
        , body = emptyBody
        , expect = expectJson ReceiveSyncResponse syncResponseDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


uploadMediaFile : ApiUrl -> ApiToken -> (File -> Result Http.Error String -> Msg) -> File -> Cmd Msg
uploadMediaFile apiUrl token msg file =
    request
        { method = "POST"
        , headers = authenticatedHeaders token
        , url = Url.Builder.crossOrigin (fullMediaUrl apiUrl) [ "upload" ] [ Url.Builder.string "filename" (name file) ]
        , body = fileBody file
        , expect = expectJson (msg file) <| Json.Decode.field "content_uri" Json.Decode.string
        , timeout = Nothing
        , tracker = Nothing
        }


getHistory : ApiUrl -> ApiToken -> RoomId -> String -> Cmd Msg
getHistory apiUrl token room prevBatch =
    request
        { method = "GET"
        , headers = authenticatedHeaders token
        , url = fullClientUrl apiUrl ++ "/rooms/" ++ room ++ "/messages" ++ "?from=" ++ prevBatch ++ "&dir=" ++ "b"
        , body = emptyBody
        , expect = expectJson (ReceiveHistoryResponse room) historyResponseDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


sendMessage : ApiUrl -> ApiToken -> Int -> RoomId -> (Result Http.Error String -> Msg) -> List ( String, Json.Encode.Value ) -> Cmd Msg
sendMessage apiUrl token transactionId room msg contents =
    request
        { method = "PUT"
        , headers = authenticatedHeaders token
        , url =
            fullClientUrl apiUrl
                ++ "/rooms/"
                ++ room
                ++ "/send/"
                ++ "m.room.message"
                ++ "/"
                ++ String.fromInt transactionId
        , body = jsonBody <| object contents
        , expect = expectJson msg (field "event_id" Json.Decode.string)
        , timeout = Nothing
        , tracker = Nothing
        }


sendMarkdownMessage : ApiUrl -> ApiToken -> Int -> RoomId -> String -> String -> Cmd Msg
sendMarkdownMessage apiUrl token transactionId room message md =
    sendMessage apiUrl
        token
        transactionId
        room
        (SendRoomTextResponse transactionId)
        [ ( "msgtype", string "m.text" )
        , ( "body", string message )
        , ( "formatted_body", string md )
        , ( "format", string "org.matrix.custom.html" )
        ]


sendTextMessage : ApiUrl -> ApiToken -> Int -> RoomId -> String -> Cmd Msg
sendTextMessage apiUrl token transactionId room message =
    sendMessage apiUrl
        token
        transactionId
        room
        (SendRoomTextResponse transactionId)
        [ ( "msgtype", string "m.text" )
        , ( "body", string message )
        ]


sendImageMessage : ApiUrl -> ApiToken -> Int -> RoomId -> File -> String -> Cmd Msg
sendImageMessage apiUrl token transactionId room file message =
    sendMessage apiUrl
        token
        transactionId
        room
        SendImageResponse
        [ ( "msgtype", string "m.image" )
        , ( "body", string <| name file )
        , ( "url", string message )
        , ( "info", object [ ( "mimetype", string <| mime file ) ] )
        ]


sendFileMessage : ApiUrl -> ApiToken -> Int -> RoomId -> File -> String -> Cmd Msg
sendFileMessage apiUrl token transactionId room file message =
    sendMessage apiUrl
        token
        transactionId
        room
        SendFileResponse
        [ ( "msgtype", string "m.file" )
        , ( "body", string <| name file )
        , ( "url", string message )
        , ( "info", object [ ( "mimetype", string <| mime file ) ] )
        ]


login : ApiUrl -> Username -> Password -> Cmd Msg
login apiUrl username password =
    request
        { method = "POST"
        , headers = basicHeaders
        , url = fullClientUrl apiUrl ++ "/login"
        , body =
            jsonBody <|
                object
                    [ ( "type", string "m.login.password" )
                    , ( "identifier"
                      , object
                            [ ( "type", string "m.id.user" )
                            , ( "user", string username )
                            ]
                      )
                    , ( "password", string password )
                    ]
        , expect = expectJson (ReceiveLoginResponse apiUrl) loginResponseDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


getUserData : ApiUrl -> ApiToken -> Username -> Cmd Msg
getUserData apiUrl token username =
    request
        { method = "GET"
        , headers = authenticatedHeaders token
        , url = fullClientUrl apiUrl ++ "/profile/" ++ username
        , body = emptyBody
        , expect = expectJson (ReceiveUserData username) userDataDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


setReadMarkers : ApiUrl -> ApiToken -> RoomId -> String -> Maybe String -> Cmd Msg
setReadMarkers apiUrl token roomId fullyRead readReceipt =
    let
        readReciptFields =
            case readReceipt of
                Just s ->
                    [ ( "m.read", string s ) ]

                _ ->
                    []
    in
    request
        { method = "POST"
        , headers = authenticatedHeaders token
        , url = fullClientUrl apiUrl ++ "/rooms/" ++ roomId ++ "/read_markers"
        , body = jsonBody <| object <| [ ( "m.fully_read", string fullyRead ) ] ++ readReciptFields
        , expect = expectWhatever ReceiveCompletedReadMarker
        , timeout = Nothing
        , tracker = Nothing
        }


sendTypingIndicator : ApiUrl -> ApiToken -> RoomId -> Username -> Bool -> Int -> Cmd Msg
sendTypingIndicator apiUrl token room user isTyping timeout =
    request
        { method = "PUT"
        , headers = authenticatedHeaders token
        , url = fullClientUrl apiUrl ++ "/rooms/" ++ room ++ "/typing/" ++ user
        , body = jsonBody <| object [ ( "timeout", int timeout ), ( "typing", bool isTyping ) ]
        , expect = expectWhatever ReceiveCompletedTypingIndicator
        , timeout = Nothing
        , tracker = Nothing
        }


setRoomAccountData : ApiUrl -> ApiToken -> Username -> RoomId -> String -> Json.Decode.Value -> Msg -> Cmd Msg
setRoomAccountData apiUrl token user roomId key value msg =
    request
        { method = "PUT"
        , headers = authenticatedHeaders token
        , url = fullClientUrl apiUrl ++ "/user/" ++ user ++ "/rooms/" ++ roomId ++ "/account_data/" ++ key
        , body = jsonBody value
        , expect = expectWhatever (\_ -> msg)
        , timeout = Nothing
        , tracker = Nothing
        }
