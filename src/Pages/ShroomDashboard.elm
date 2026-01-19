module Pages.ShroomDashboard exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Types exposing (..)
import Theme
import Supplemental exposing (..)
import Chart as C
import Chart.Attributes as CA


view : ShroomDashboardModel -> Html ShroomDashboardMsg
view model =
    div [ class "min-h-screen bg-gray-900 text-white p-8" ]
        [ div [ class "max-w-6xl mx-auto" ]
            [ headerSection model
            , statisticsSection model
            , holderChart model
            ]
        ]


headerSection : ShroomDashboardModel -> Html ShroomDashboardMsg
headerSection model =
    div [ class "text-center mb-12" ]
        [ h1 [ class "text-6xl font-bold mb-4 bg-gradient-to-r from-green-400 to-blue-500 bg-clip-text text-transparent" ]
            [ Html.text "Shroom Nation" ]
        , div [ class "text-2xl text-gray-300 mb-2" ]
            [ Html.text "$SHRMN Token Holders" ]
        , div [ class "text-5xl font-bold text-green-400" ]
            [ Html.text (String.fromInt model.totalHolders) ]
        , div [ class "mt-4 space-x-4" ]
            [ button 
                [ class "px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg transition-colors"
                , onClick FetchViaMoralis
                , disabled model.loading
                ]
                [ Html.text "Fetch via Moralis" ]
            , button 
                [ class "px-6 py-3 bg-green-600 hover:bg-green-700 text-white font-semibold rounded-lg transition-colors"
                , onClick FetchViaGoldRush
                , disabled model.loading
                ]
                [ Html.text "Fetch via GoldRush" ]
            , button 
                [ class "px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white font-semibold rounded-lg transition-colors"
                , onClick FetchTokenPrice
                , disabled model.loading
                ]
                [ Html.text "Get Price" ]
            ]
        , if model.loading then
            div [ class "mt-4 text-blue-400" ]
                [ Html.text "Loading holder data..." ]
          else
            case model.error of
                Just error ->
                    div [ class "mt-4 text-red-400" ]
                        [ Html.text ("Error: " ++ error) ]
                Nothing ->
                    if model.totalHolders == 0 then
                        div [ class "mt-4 text-gray-400" ]
                            [ Html.text "Click 'Fetch All Holders' to load data" ]
                    else
                        div [ class "mt-4 text-gray-400" ]
                            [ Html.text "Data updated every minute" ]
        ]


statisticsSection : ShroomDashboardModel -> Html ShroomDashboardMsg
statisticsSection model =
    div [ class "grid grid-cols-1 md:grid-cols-5 gap-4 mb-8" ]
        [ statCard "Total Holders" (addCommas (String.fromInt model.totalHolders)) "bg-blue-600"
        , statCard "Total SHRMN" (formatBalance model.totalTokens ++ " SHRMN") "bg-yellow-600"
        , statCard "Average Holding" (formatBalance model.averageHolding ++ " SHRMN") "bg-purple-600"
        , statCard "Median Holding" (formatBalance model.medianHolding ++ " SHRMN") "bg-green-600"
        , statCard "Max Holding" (formatBalance model.maxHolding ++ " SHRMN") "bg-red-600"
        ]


statCard : String -> String -> String -> Html ShroomDashboardMsg
statCard title value bgColor =
    div [ class ("p-6 rounded-lg " ++ bgColor) ]
        [ div [ class "text-white text-sm font-medium opacity-75" ]
            [ Html.text title ]
        , div [ class "text-white text-2xl font-bold mt-2" ]
            [ Html.text value ]
        ]


holderChart : ShroomDashboardModel -> Html ShroomDashboardMsg
holderChart model =
    div [ class "bg-gray-800 rounded-lg p-6" ]
        [ h2 [ class "text-2xl font-bold mb-6 text-center" ]
            [ Html.text "Token Distribution" ]
        , case model.hoveredHolder of
            Just holder ->
                div [ class "mb-4 p-3 bg-gray-700 rounded text-center" ]
                    [ div [ class "text-sm text-gray-300" ]
                        [ Html.text ("Address: " ++ shortenAddress holder.address) ]
                    , div [ class "text-lg font-bold text-green-400" ]
                        [ Html.text (formatBalance holder.balance ++ " SHRMN") ]
                    ]
            Nothing ->
                div [ class "mb-4 p-3 bg-gray-700 rounded text-center text-gray-400" ]
                    [ Html.text "Hover over bars to see holder details" ]
        , renderChart model
        , loadMoreButton model
        , terezkaChart model
        ]


loadMoreButton : ShroomDashboardModel -> Html ShroomDashboardMsg
loadMoreButton model =
    if model.hasMore && not model.loading then
        div [ class "mt-6 text-center" ]
            [ button 
                [ class "px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg transition-colors"
                , onClick LoadMoreHolders
                , disabled model.loadingMore
                ]
                [ Html.text 
                    (if model.loadingMore then 
                        "Loading..." 
                     else 
                        "Load More Holders")
                ]
            ]
    else
        div [] []


renderChart : ShroomDashboardModel -> Html ShroomDashboardMsg
renderChart model =
    if List.isEmpty model.holders then
        div [ class "text-center text-gray-400 py-8" ]
            [ Html.text "No holder data available" ]
    else
        let
            top100Holders = model.holders 
                |> List.sortBy .balance 
                |> List.reverse 
                |> List.take 100
                |> List.sortBy .balance
            
            holdersCount = List.length top100Holders
            maxBalance = top100Holders 
                |> List.map .balance 
                |> List.maximum 
                |> Maybe.withDefault 1
            
            chartWidth = 1000
            chartHeight = 400
            barWidth = chartWidth // Basics.max 1 holdersCount
            
            bars = top100Holders
                |> List.indexedMap (createBar maxBalance chartHeight barWidth)
        in
        div []
            [ div [ class "text-white text-center mb-4 p-2 bg-gray-700 rounded" ]
                [ Html.text ("Top " ++ String.fromInt holdersCount ++ " holders - Low to High (max: " ++ formatBalance maxBalance ++ " SHRMN)") ]
            , Html.node "svg" 
                [ attribute "width" "100%"
                , attribute "height" "400"
                , attribute "viewBox" "0 0 1000 400"
                , class "w-full bg-gray-900 border-2 border-green-500"
                ]
                ([ Html.node "rect" 
                    [ attribute "x" "0"
                    , attribute "y" "0"
                    , attribute "width" "1000"
                    , attribute "height" "400"
                    , attribute "fill" "#111827"
                    , attribute "opacity" "1"
                    ] []
                 ] ++ bars)
            ]


createBar : Float -> Int -> Int -> Int -> TokenHolder -> Html ShroomDashboardMsg
createBar maxBalance chartHeight barWidth index holder =
    let
        minBarHeight = 20
        logBalance = logBase 10 (Basics.max 1 holder.balance)
        logMax = logBase 10 (Basics.max 1 maxBalance)
        barHeight = 
            if logMax > 0 then
                Basics.max minBarHeight ((logBalance / logMax) * toFloat chartHeight * 0.9)
            else
                minBarHeight
        
        x = toFloat (index * barWidth)
        y = toFloat chartHeight - barHeight
        
        color = 
            if holder.balance > maxBalance * 0.7 then
                "#ef4444"
            else if holder.balance > maxBalance * 0.3 then
                "#f59e0b"
            else if holder.balance > maxBalance * 0.1 then
                "#10b981"
            else
                "#3b82f6"
    in
    Html.node "rect"
        [ attribute "x" (String.fromFloat x)
        , attribute "y" (String.fromFloat y)
        , attribute "width" (String.fromInt (Basics.max 6 (barWidth - 2)))
        , attribute "height" (String.fromFloat barHeight)
        , attribute "fill" color
        , attribute "opacity" "0.9"
        , attribute "stroke" "#1f2937"
        , attribute "stroke-width" "1"
        , onMouseEnter (HoverHolder (Just holder))
        , onMouseLeave (HoverHolder Nothing)
        , class "cursor-pointer transition-all duration-200 hover:opacity-100"
        ]
        []


prepareChartData : List TokenHolder -> List { x : Float, y : Float }
prepareChartData holders =
    holders
        |> List.indexedMap (\index holder -> 
            { x = toFloat index
            , y = holder.balance / 1000000
            })
        |> List.take 50


shortenAddress : String -> String
shortenAddress address =
    if String.length address > 10 then
        String.left 6 address ++ "..." ++ String.right 4 address
    else
        address


formatBalance : Float -> String
formatBalance balance =
    if balance >= 1000000 then
        let
            millions = balance / 1000000
            rounded = toFloat (round millions)
            millionsStr = addCommas (String.fromInt (round millions))
        in
        millionsStr ++ "M"
    else
        let
            rounded = toFloat (round balance)
            balanceStr = addCommas (String.fromInt (round balance))
        in
        balanceStr


calculateStatistics : List TokenHolder -> { median : Float, average : Float, max : Float, total : Float }
calculateStatistics holders =
    if List.isEmpty holders then
        { median = 0, average = 0, max = 0, total = 0 }
    else
        let
            balances = holders |> List.map .balance |> List.sort
            total = List.sum balances
            count = List.length balances
            average = total / toFloat count
            max = List.maximum balances |> Maybe.withDefault 0
            median = 
                let
                    midIndex = count // 2
                in
                if modBy 2 count == 0 then
                    (List.drop (midIndex - 1) balances |> List.head |> Maybe.withDefault 0) +
                    (List.drop midIndex balances |> List.head |> Maybe.withDefault 0) / 2
                else
                    List.drop midIndex balances |> List.head |> Maybe.withDefault 0
        in
        { median = median, average = average, max = max, total = total }


init : ShroomDashboardModel
init =
    { holders = []
    , totalHolders = 0
    , loading = False
    , loadingMore = False
    , error = Nothing
    , hoveredHolder = Nothing
    , cursor = Nothing
    , hasMore = True
    , medianHolding = 0
    , averageHolding = 0
    , maxHolding = 0
    , totalTokens = 0
    , tokenPrice = Nothing
    } 

terezkaChart : ShroomDashboardModel -> Html ShroomDashboardMsg
terezkaChart model =
    div [ class "bg-gray-800 rounded-lg p-6 mt-8" ]
        [ h2 [ class "text-2xl font-bold mb-6 text-center text-green-400" ]
            [ Html.text "Token Holdings (Terezka Chart)" ]
        , if List.isEmpty model.holders then
            div [ class "text-center text-gray-400 py-8" ]
                [ Html.text "No data available" ]
          else
            let
                top100Holders = model.holders
                    |> List.sortBy .balance
                    |> List.reverse
                    |> List.take 100

                chartData = top100Holders
                    |> List.indexedMap (\i holder -> 
                        { x = toFloat i + 1
                        , y = holder.balance / 1000000
                        , holder = holder
                        })
            in
            div []
                [ case model.hoveredHolder of
                    Just holder ->
                        div [ class "mb-4 p-3 bg-gray-700 rounded text-center" ]
                            [ div [ class "text-sm text-gray-300" ]
                                [ Html.text ("Address: " ++ holder.address) ]
                            , div [ class "text-lg font-bold text-green-400" ]
                                [ Html.text (formatBalance holder.balance ++ " SHRMN") ]
                            , case model.tokenPrice of
                                Just price ->
                                    div [ class "text-sm text-blue-400" ]
                                        [ Html.text ("Value: $" ++ String.fromFloat (holder.balance * price / 1000000)) ]
                                Nothing ->
                                    div [] []
                            ]
                    Nothing ->
                        div [ class "mb-4 p-3 bg-gray-700 rounded text-center text-gray-400" ]
                            [ Html.text "Hover over bars to see holder details" ]
                , case model.tokenPrice of
                    Just price ->
                        div [ class "text-center mb-4 p-3 bg-blue-900 rounded" ]
                            [ div [ class "text-lg text-blue-400" ]
                                [ Html.text ("Token Price: $" ++ String.fromFloat price) ]
                            ]
                    Nothing ->
                        div [] []
                , C.chart
                    [ CA.height 300
                    , CA.width 800
                    , CA.margin { top = 30, right = 30, bottom = 60, left = 80 }
                    ]
                    [ C.xTicks []
                    , C.yTicks []
                    , C.xLabels [ CA.fontSize 12 ]
                    , C.yLabels [ CA.format (\n -> formatBalance (n * 1000000) |> String.replace " SHRMN" "M"), CA.fontSize 12 ]
                    , C.xAxis []
                    , C.yAxis []
                    , C.bars [ CA.spacing 0.1 ] 
                        [ C.bar .y [ CA.color "#10b981" ] ] 
                        chartData
                    ]
                ]
        ] 