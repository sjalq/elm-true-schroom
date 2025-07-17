module Route exposing (..)

import Types exposing (AdminRoute(..), Route(..))
import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), Parser, oneOf, s)


parser : Parser (Route -> a) a
parser =
    oneOf
        [ Parser.map ShroomDashboard Parser.top
        , Parser.map (Admin AdminDefault) (s "admin")
        , Parser.map (Admin AdminLogs) (s "admin" </> s "logs")
        , Parser.map (Admin AdminFetchModel) (s "admin" </> s "fetch-model")
        --, Parser.map (Admin AdminFusion) (s "admin" </> s "fusion")
        , Parser.map Examples (s "examples")
        , Parser.map Default (s "default")
        ]


fromUrl : Url -> Route
fromUrl url =
    Parser.parse parser url
        |> Maybe.withDefault NotFound


toString : Route -> String
toString route =
    case route of
        ShroomDashboard ->
            "/"

        Default ->
            "/default"

        Admin AdminDefault ->
            "/admin"

        Admin AdminLogs ->
            "/admin/logs"

        Admin AdminFetchModel ->
            "/admin/fetch-model"

        -- Admin AdminFusion ->
        --     "/admin/fusion"

        Examples ->
            "/examples"

        NotFound ->
            "/not-found"
