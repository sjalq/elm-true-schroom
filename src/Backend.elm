module Backend exposing (..)

import Auth.Flow
import Dict
import Env
-- import Fusion.Generated.Types
-- import Fusion.Patch
import Http
import Json.Decode as Decode
import Lamdera
import RPC
import Rights.Auth0 exposing (backendConfig)
import Rights.Permissions exposing (sessionCanPerformAction)
import Rights.Role exposing (roleToString)
import Rights.User exposing (createUser, getUserRole, insertUser, isSysAdmin)
import Supplemental exposing (..)
import Task
import Types exposing (..)


type alias Model =
    BackendModel


app =
    Lamdera.backend
        { init = init
        , update = update
        , updateFromFrontend = updateFromFrontendCheckingRights
        , subscriptions = subscriptions
        }


subscriptions : Model -> Sub msg
subscriptions _ =
    Sub.batch
        [-- things that run on timers and things that listen to the outside world
        ]


init : ( Model, Cmd BackendMsg )
init =
    ( { logs = []
      , pendingAuths = Dict.empty
      , sessions = Dict.empty
      , users = Dict.empty
      , pollingJobs = Dict.empty
      , shroomHoldersCache = Nothing
      }
    , Cmd.none
    )


update : BackendMsg -> Model -> ( Model, Cmd BackendMsg )
update msg model =
    case msg of
        NoOpBackendMsg ->
            ( model, Cmd.none )

        Log logMsg ->
            ( model, Cmd.none )
                |> log logMsg

        GotRemoteModel result ->
            case result of
                Ok model_ ->
                    ( model_, Cmd.none )
                        |> log "GotRemoteModel Ok"

                Err err ->
                    ( model, Cmd.none )
                        |> log ("GotRemoteModel Err: " ++ httpErrorToString err)

        AuthBackendMsg authMsg ->
            Auth.Flow.backendUpdate (backendConfig model) authMsg

        GotCryptoPriceResult token result ->
            case result of
                Ok priceStr ->
                    let
                        updatedPollingJobs =
                            Dict.insert token (Ready (Ok priceStr)) model.pollingJobs
                    in
                    ( { model | pollingJobs = updatedPollingJobs }, Cmd.none )
                        |> log ("Crypto price calculated: " ++ priceStr)

                Err err ->
                    let
                        updatedPollingJobs =
                            Dict.insert token (Ready (Err (httpErrorToString err))) model.pollingJobs
                    in
                    ( { model | pollingJobs = updatedPollingJobs }, Cmd.none )
                        |> log ("Failed to calculate crypto price: " ++ httpErrorToString err)

        StoreTaskResult token result ->
            let
                updatedPollingJobs =
                    Dict.insert token (Ready result) model.pollingJobs
                
                logMsg =
                    case result of
                        Ok data ->
                            "Task completed successfully: " ++ token
                        
                        Err err ->
                            "Task failed: " ++ token ++ " - " ++ err
            in
            ( { model | pollingJobs = updatedPollingJobs }, Cmd.none )
                |> log logMsg

        GotJobTime token timestamp ->
            let
                updatedPollingJobs =
                    Dict.insert token (BusyWithTime timestamp) model.pollingJobs
            in
            ( { model | pollingJobs = updatedPollingJobs }, Cmd.none )
                |> log ("Updated job " ++ token ++ " with timestamp: " ++ String.fromInt timestamp)

        GotMoralisHoldersResponse result ->
            case result of
                Ok holders ->
                    ( model, Lamdera.broadcast (ShroomHoldersData (Ok holders)) )
                        |> log ("Fetched " ++ String.fromInt (List.length holders) ++ " SHRMN holders via Moralis")

                Err httpError ->
                    ( model, Lamdera.broadcast (ShroomHoldersData (Err (httpErrorToString httpError))) )
                        |> log ("Moralis failed: " ++ httpErrorToString httpError)

        GotGoldRushHoldersResponse result ->
            case result of
                Ok holders ->
                    let
                        hasMore = List.length holders >= 100
                        cache = { holders = holders, lastUpdated = 0, cacheValidMinutes = 60 }
                        updatedModel = { model | shroomHoldersCache = Just cache }
                    in
                    ( updatedModel
                    , Cmd.batch
                        [ Lamdera.broadcast (ShroomHoldersData (Ok holders))
                        , if hasMore then 
                            fetchMoreHoldersFromGoldRush 1
                          else 
                            Cmd.none
                        ]
                    )
                        |> log ("Fetched " ++ String.fromInt (List.length holders) ++ " SHRMN holders via GoldRush - auto-fetching more")

                Err httpError ->
                    ( model, Lamdera.broadcast (ShroomHoldersData (Err (httpErrorToString httpError))) )
                        |> log ("GoldRush failed: " ++ httpErrorToString httpError)

        GotMoreGoldRushHoldersResponse pageNum result ->
            case result of
                Ok holders ->
                    let
                        hasMore = List.length holders >= 100
                        allHolders = case model.shroomHoldersCache of
                            Just existingCache -> existingCache.holders ++ holders
                            Nothing -> holders
                        cache = { holders = allHolders, lastUpdated = 0, cacheValidMinutes = 60 }
                        updatedModel = { model | shroomHoldersCache = Just cache }
                    in
                    ( updatedModel
                    , Cmd.batch
                        [ Lamdera.broadcast (MoreShroomHoldersData (Ok { holders = holders, cursor = Nothing }))
                        , Lamdera.broadcast (ShroomHoldersData (Ok allHolders))
                        , if hasMore then 
                            fetchMoreHoldersFromGoldRush (pageNum + 1)
                          else 
                            Cmd.none
                        ]
                    )
                        |> log ("Fetched page " ++ String.fromInt pageNum ++ " with " ++ String.fromInt (List.length holders) ++ " more SHRMN holders. Total: " ++ String.fromInt (List.length allHolders) ++ (if hasMore then " - fetching next" else " - done"))

                Err httpError ->
                    ( model, Lamdera.broadcast (MoreShroomHoldersData (Err (httpErrorToString httpError))) )
                        |> log ("Failed to fetch more holders: " ++ httpErrorToString httpError)


updateFromFrontend : BrowserCookie -> ConnectionId -> ToBackend -> Model -> ( Model, Cmd BackendMsg )
updateFromFrontend browserCookie connectionId msg model =
    case msg of
        NoOpToBackend ->
            ( model, Cmd.none )

        Admin_FetchLogs ->
            ( model, Lamdera.sendToFrontend connectionId (Admin_Logs_ToFrontend model.logs) )

        Admin_ClearLogs ->
            let
                newModel =
                    { model | logs = [] }
            in
            ( newModel, Lamdera.sendToFrontend connectionId (Admin_Logs_ToFrontend newModel.logs) )

        Admin_FetchRemoteModel remoteUrl ->
            ( model
              -- put your production model key in here to fetch from your prod env.
            , RPC.fetchImportedModel remoteUrl "1234567890"
                |> Task.attempt GotRemoteModel
            )

        AuthToBackend authToBackend ->
            Auth.Flow.updateFromFrontend (backendConfig model) connectionId browserCookie authToBackend model

        GetUserToBackend ->
            case Dict.get browserCookie model.sessions of
                Just userInfo ->
                    case getUserFromCookie browserCookie model of
                        Just user ->
                            ( model, Cmd.batch [ Lamdera.sendToFrontend connectionId <| UserInfoMsg <| Just userInfo, Lamdera.sendToFrontend connectionId <| UserDataToFrontend <| userToFrontend user ] )

                        Nothing ->
                            let
                                initialPreferences =
                                    { darkMode = True } -- Default new users to dark mode
                                
                                user =
                                    createUser userInfo initialPreferences

                                newModel =
                                    insertUser userInfo.email user model
                            in
                            ( newModel, Cmd.batch [ Lamdera.sendToFrontend connectionId <| UserInfoMsg <| Just userInfo, Lamdera.sendToFrontend connectionId <| UserDataToFrontend <| userToFrontend user ] )

                Nothing ->
                    ( model, Lamdera.sendToFrontend connectionId <| UserInfoMsg Nothing )

        LoggedOut ->
            ( { model | sessions = Dict.remove browserCookie model.sessions }, Cmd.none )

        FetchShroomHoldersViaMoralis ->
            ( model, fetchHoldersFromMoralis )

        FetchShroomHoldersViaGoldRush ->
            ( model, fetchHoldersFromGoldRush )

        LoadMoreShroomHolders cursor ->
            let
                pageNum = cursor 
                    |> Maybe.andThen String.toInt 
                    |> Maybe.withDefault 1
            in
            ( model, fetchMoreHoldersFromGoldRush pageNum )

        SetDarkModePreference preference ->
            case getUserFromCookie browserCookie model of
                Just user ->
                    let
                        -- Explicitly alias the nested record
                        currentPreferences = 
                            user.preferences
                        
                        updatedUserPreferences : Preferences
                        updatedUserPreferences =
                            { currentPreferences | darkMode = preference } -- Update the alias
                        
                        updatedUser : User
                        updatedUser =
                            { user | preferences = updatedUserPreferences }

                        updatedUsers =
                            Dict.insert user.email updatedUser model.users
                    in
                    ( { model | users = updatedUsers }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )
                        |> log "User or session not found for SetDarkModePreference"

        WS_Receive message ->
            -- Echo websocket message back to frontend
            ( model, Lamdera.sendToFrontend connectionId (WS_Send ("Echo: " ++ message)) )

        -- Fusion_PersistPatch patch ->
        --     let
        --         value =
        --             Fusion.Patch.patch { force = False } patch (Fusion.Generated.Types.toValue_BackendModel model)
        --                 |> Result.withDefault (Fusion.Generated.Types.toValue_BackendModel model)
        --     in
        --     case
        --         Fusion.Generated.Types.build_BackendModel value
        --     of
        --         Ok newModel ->
        --             ( newModel
        --               -- , Lamdera.sendToFrontend connectionId (Admin_FusionResponse value)
        --             , Cmd.none
        --             )

                -- Err err ->
                --     ( model
                --     , Cmd.none
                --     )
                --         |> log ("Failed to apply fusion patch: " ++ Debug.toString err)

        -- Fusion_Query query ->
        --     ( model
        --     , Lamdera.sendToFrontend connectionId (Admin_FusionResponse (Fusion.Generated.Types.toValue_BackendModel model))
        --     )


updateFromFrontendCheckingRights : BrowserCookie -> ConnectionId -> ToBackend -> Model -> ( Model, Cmd BackendMsg )
updateFromFrontendCheckingRights browserCookie connectionId msg model =
    if
        case msg of
            NoOpToBackend ->
                True

            LoggedOut ->
                True

            AuthToBackend _ ->
                True

            GetUserToBackend ->
                True
            
            SetDarkModePreference _ -> -- Allow everyone to set their own preference
                True

            _ ->
                sessionCanPerformAction model browserCookie msg
    then
        updateFromFrontend browserCookie connectionId msg model

    else
        ( model, Lamdera.sendToFrontend connectionId (PermissionDenied msg) )


getUserFromCookie : BrowserCookie -> Model -> Maybe User
getUserFromCookie browserCookie model =
    Dict.get browserCookie model.sessions
        |> Maybe.andThen (\userInfo -> Dict.get userInfo.email model.users)


log =
    Supplemental.log NoOpBackendMsg


userToFrontend : User -> UserFrontend
userToFrontend user =
    { email = user.email
    , isSysAdmin = isSysAdmin user
    , role = getUserRole user |> roleToString
    , preferences = user.preferences
    }


fetchHoldersFromMoralis : Cmd BackendMsg
fetchHoldersFromMoralis =
    let
        url = "https://deep-index.moralis.io/api/v2.2/erc20/" ++ Env.shroomTokenAddress ++ "/owners?chain=base&limit=100"
        headers = [ Http.header "X-API-Key" Env.moralisApiKey ]
    in
    Http.request
        { method = "GET"
        , headers = headers
        , url = url
        , body = Http.emptyBody
        , expect = Http.expectJson GotMoralisHoldersResponse moralisHolderResponseDecoder
        , timeout = Nothing
        , tracker = Nothing
        }

fetchHoldersFromGoldRush : Cmd BackendMsg
fetchHoldersFromGoldRush =
    let
        url = "https://api.covalenthq.com/v1/base-mainnet/tokens/" ++ Env.shroomTokenAddress ++ "/token_holders_v2/?key=" ++ Env.goldRushApiKey
    in
    Http.get
        { url = url
        , expect = Http.expectJson GotGoldRushHoldersResponse goldRushHolderResponseDecoder
        }

fetchMoreHoldersFromGoldRush : Int -> Cmd BackendMsg
fetchMoreHoldersFromGoldRush pageNum =
    let
        url = "https://api.covalenthq.com/v1/base-mainnet/tokens/" ++ Env.shroomTokenAddress ++ "/token_holders_v2/?key=" ++ Env.goldRushApiKey ++ "&page-number=" ++ String.fromInt pageNum
    in
    Http.get
        { url = url
        , expect = Http.expectJson (GotMoreGoldRushHoldersResponse pageNum) goldRushHolderResponseDecoder
        }

moralisHolderResponseDecoder : Decode.Decoder (List TokenHolder)
moralisHolderResponseDecoder =
    Decode.field "result" 
        (Decode.list 
            (Decode.map2 TokenHolder
                (Decode.field "owner_address" Decode.string)
                (Decode.field "balance_formatted" 
                    (Decode.string |> Decode.map parseFormattedBalance)
                )
            )
        )

parseFormattedBalance : String -> Float
parseFormattedBalance balanceStr =
    String.toFloat balanceStr |> Maybe.withDefault 0

goldRushHolderResponseDecoder : Decode.Decoder (List TokenHolder)
goldRushHolderResponseDecoder =
    Decode.field "data" 
        (Decode.field "items"
            (Decode.list 
                (Decode.map2 TokenHolder
                    (Decode.field "address" Decode.string)
                    (Decode.field "balance" 
                        (Decode.string |> Decode.map (\bal -> 
                            String.toFloat bal 
                                |> Maybe.withDefault 0 
                                |> (\balFloat -> balFloat / 10^18)
                        ))
                    )
                )
            )
        )
