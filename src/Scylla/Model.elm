module Scylla.Model exposing (..)

import Browser
import Browser.Dom exposing (Viewport)
import Browser.Navigation as Nav
import Dict exposing (Dict)
import File exposing (File)
import Http
import Json.Decode as Decode
import Scylla.Api exposing (..)
import Scylla.ListUtils exposing (findFirst)
import Scylla.Login exposing (LoginResponse, Password, Username)
import Scylla.Markdown exposing (..)
import Scylla.Messages exposing (..)
import Scylla.Room exposing (OpenRooms, getLocalDisplayName)
import Scylla.Route exposing (RoomId, Route(..))
import Scylla.Storage exposing (..)
import Scylla.Sync exposing (HistoryResponse, SyncResponse)
import Scylla.Sync.AccountData exposing (AccountData, directMessagesDecoder)
import Scylla.Sync.Push exposing (Ruleset)
import Scylla.Sync.Rooms exposing (JoinedRoom)
import Scylla.UserData exposing (UserData, getSenderName)
import Time exposing (Posix)
import Url exposing (Url)
import Url.Builder


type alias Model =
    { key : Nav.Key
    , route : Route
    , token : Maybe ApiToken
    , loginUsername : Username
    , loginPassword : Password
    , apiUrl : ApiUrl
    , accountData : AccountData
    , nextBatch : String
    , errors : List String
    , roomText : Dict RoomId String
    , sending : Dict Int ( RoomId, SendingMessage )
    , transactionId : Int
    , connected : Bool
    , searchText : String
    , rooms : OpenRooms
    , roomsVisible : Bool
    }


type Msg
    = ChangeApiUrl ApiUrl -- During login screen: the API URL (homeserver)
    | ChangeLoginUsername Username -- During login screen: the username
    | ChangeLoginPassword Password -- During login screen: the password
    | AttemptLogin -- During login screen, login button presed
    | TryUrl Browser.UrlRequest -- User attempts to change URL
    | OpenRoom String -- We try open a room
    | ChangeRoute Route -- URL changes
    | ChangeRoomText String String -- Change to a room's input text
    | SendRoomText String -- Sends a message typed into a given room's input
    | SendRoomTextResponse Int (Result Http.Error String) -- A send message response finished
    | ViewportAfterMessage (Result Browser.Dom.Error Viewport) -- A message has been received, try scroll (maybe)
    | ViewportChangeComplete (Result Browser.Dom.Error ()) -- We're done changing the viewport.
    | ReceiveFirstSyncResponse (Result Http.Error SyncResponse) -- HTTP, Sync has finished
    | ReceiveSyncResponse (Result Http.Error SyncResponse) -- HTTP, Sync has finished
    | ReceiveLoginResponse ApiUrl (Result Http.Error LoginResponse) -- HTTP, Login has finished
    | ReceiveUserData Username (Result Http.Error UserData) -- HTTP, receive user data
    | ReceiveCompletedReadMarker (Result Http.Error ()) -- HTTP, read marker request completed
    | ReceiveCompletedTypingIndicator (Result Http.Error ()) -- HTTP, typing indicator request completed
    | ReceiveStoreData Decode.Value -- We are send back a value on request from localStorage.
    | TypingTick Posix -- Tick for updating the typing status
    | History RoomId -- Load history for a room
    | ReceiveHistoryResponse RoomId (Result Http.Error HistoryResponse) -- HTTP, receive history
    | SendImages RoomId -- Image selection triggered
    | SendFiles RoomId -- File selection triggered
    | ImagesSelected RoomId File (List File) -- Images to send selected
    | FilesSelected RoomId File (List File) -- Files to send selected
    | ImageUploadComplete RoomId File (Result Http.Error String) -- Image has been uploaded
    | FileUploadComplete RoomId File (Result Http.Error String) -- File has been uploaded
    | SendImageResponse (Result Http.Error String) -- Server responded to image
    | SendFileResponse (Result Http.Error String) -- Server responded to file
    | ReceiveMarkdown MarkdownResponse -- Markdown was rendered
    | DismissError Int -- User dismisses error
    | AttemptReconnect -- User wants to reconnect to server
    | UpdateSearchText String -- Change search text in room list
    | RoomsToggle


rootUrl : String
rootUrl =
    "#"


roomUrl : String -> String
roomUrl s =
    "#room/" ++ s


loginUrl : String
loginUrl =
    "#login"


currentRoomId : Model -> Maybe RoomId
currentRoomId m =
    case m.route of
        Room r ->
            Just r

        _ ->
            Nothing


roomLocalDisplayName : Model -> RoomId -> Username -> String
roomLocalDisplayName m rid u =
    case Dict.get rid m.rooms of
        Just rd ->
            getLocalDisplayName rd u

        _ ->
            getSenderName u
