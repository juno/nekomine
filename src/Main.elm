port module Main exposing (main)

import Array exposing (Array)
import Browser
import Game exposing (Board, Cell)
import Html exposing (Html, button, details, div, h1, img, li, option, p, select, small, span, summary, text, ul)
import Html.Attributes exposing (attribute, class, classList, id, src, value)
import Html.Events exposing (on, onClick, onInput, preventDefaultOn)
import Json.Decode as Decode
import Json.Encode as Encode
import List
import String
import Time
import Url


port save : Encode.Value -> Cmd msg
port sound : String -> Cmd msg
port flagCell : (Int -> msg) -> Sub msg


type alias Flags =
    { seed : Int, best : List Float, dex : List Int, muted : Bool }


type alias Model =
    { level : Int
    , board : Maybe Board
    , over : Bool
    , won : Bool
    , seconds : Float
    , best : Array Float
    , dex : Array Int
    , muted : Bool
    , seed : Int
    , message : String
    , caught : Int
    , fresh : List Int
    }


type Msg
    = Restart
    | Choose String
    | Open Int
    | Flag Int
    | Tick
    | ToggleSound


main : Program Flags Model Msg
main =
    Browser.element { init = init, view = view, update = update, subscriptions = subscriptions }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { level = 0, board = Nothing, over = False, won = False, seconds = 0
      , best = Array.fromList (List.take 3 (flags.best ++ List.repeat 3 0))
      , dex = Array.fromList (List.take 8 (flags.dex ++ List.repeat 8 0))
      , muted = flags.muted, seed = flags.seed, message = "", caught = 0, fresh = []
      }
    , Cmd.none
    )


type alias Level = { name : String, rows : Int, cols : Int, cats : Int }

levels : List Level
levels =
    [ { name = "こねこ", rows = 9, cols = 9, cats = 10 }
    , { name = "おとな猫", rows = 16, cols = 16, cats = 40 }
    , { name = "ボス猫", rows = 16, cols = 30, cats = 99 }
    ]


levelSpec : Int -> Level
levelSpec n =
    levels |> List.drop n |> List.head |> Maybe.withDefault { name = "こねこ", rows = 9, cols = 9, cats = 10 }


persist : Model -> Cmd Msg
persist model =
    save <| Encode.object
        [ ( "best", Encode.list Encode.float (Array.toList model.best) )
        , ( "dex", Encode.list Encode.int (Array.toList model.dex) )
        , ( "muted", Encode.bool model.muted )
        ]


restart : Model -> Model
restart model =
    { model | board = Nothing, over = False, won = False, seconds = 0, message = "", caught = 0, fresh = [] }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Restart ->
            ( restart model, Cmd.none )

        Choose raw ->
            ( restart { model | level = String.toInt raw |> Maybe.withDefault 0 }, Cmd.none )

        Tick ->
            if model.board /= Nothing && not model.over then
                ( { model | seconds = model.seconds + 0.1 }, Cmd.none )
            else
                ( model, Cmd.none )

        ToggleSound ->
            let
                next = { model | muted = not model.muted }
            in
            ( next, persist next )

        Flag k ->
            case model.board of
                Nothing ->
                    ( model, Cmd.none )

                Just board ->
                    if model.over || Game.isOpened k board then
                        ( model, Cmd.none )
                    else
                        let
                            next = { model | board = Just (Game.toggleFlag k board) }
                        in
                        ( next, if model.muted then Cmd.none else sound (if Game.isFlagged k board then "unflag" else "flag") )

        Open k ->
            if model.over then
                ( model, Cmd.none )
            else
                let
                    level = levelSpec model.level
                    board =
                        case model.board of
                            Just existing -> Just existing
                            Nothing -> Game.generate level.rows level.cols level.cats k model.seed
                in
                case board of
                    Nothing ->
                        ( { model | message = "盤面を生成できません。もう一度お試しください" }, Cmd.none )

                    Just existing ->
                        openWithBoard k existing model


openWithBoard : Int -> Board -> Model -> ( Model, Cmd Msg )
openWithBoard k board model =
    let
        wasOpened = Game.isOpened k board
        nextBoard = Game.reveal k board
        base = { model | board = Just nextBoard, seed = model.seed + 1 }
    in
    if Game.isCat k board && Game.isOpened k nextBoard then
        finish False { base | message = "猫が起きちゃった…！もう一回？" }
    else if Game.isWon nextBoard then
        let
            elapsed = max 0.1 model.seconds
            previous = Array.get model.level model.best |> Maybe.withDefault 0
            record = previous == 0 || elapsed < previous
            updated = if record then Array.set model.level elapsed model.best else model.best
        in
        finish True
            { base | best = updated
            , seconds = elapsed
            , message = "みんなぐっすり！ " ++ formatTime elapsed ++ "秒でクリア" ++ (if record then " 新記録！" else "")
            }
    else
        ( base, if model.muted || wasOpened then Cmd.none else sound "open" )


finish : Bool -> Model -> ( Model, Cmd Msg )
finish won model =
    case model.board of
        Nothing ->
            ( model, Cmd.none )

        Just board ->
            let
                found = Game.caughtBreeds won board
                ( dex, fresh ) = Game.addToDex model.dex found
                next = { model | over = True, won = won, dex = dex, caught = List.length found, fresh = fresh }
            in
            ( next, Cmd.batch [ persist next, if model.muted then Cmd.none else sound (if won then "win" else "meow") ] )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ flagCell Flag
        , if model.board /= Nothing && not model.over then Time.every 100 (\_ -> Tick) else Sub.none
        ]


type alias Breed = { name : String, fur : String, mark : String, rarity : Int }

breeds : List Breed
breeds =
    [ { name = "茶トラ", fur = "#f7c27a", mark = "#e0964a", rarity = 1 }
    , { name = "サバトラ", fur = "#d4d4da", mark = "#8e8e9a", rarity = 1 }
    , { name = "黒猫", fur = "#4d434a", mark = "#4d434a", rarity = 1 }
    , { name = "白猫", fur = "#fffaf3", mark = "#fffaf3", rarity = 1 }
    , { name = "ハチワレ", fur = "#fffaf3", mark = "#4d434a", rarity = 2 }
    , { name = "三毛", fur = "#fffaf3", mark = "#f5a35c", rarity = 2 }
    , { name = "シャム", fur = "#f6e8d2", mark = "#7a5c4c", rarity = 3 }
    , { name = "招き猫", fur = "#ffd36e", mark = "#e8364f", rarity = 4 }
    ]


breedInfo : Int -> Breed
breedInfo n =
    breeds |> List.drop n |> List.head |> Maybe.withDefault { name = "猫", fur = "#f7c27a", mark = "#e0964a", rarity = 1 }


catImage : Int -> String -> Html msg
catImage breed mood =
    let
        info = breedInfo breed
        fur = info.fur
        mark = info.mark
        eyes =
            case mood of
                "sleep" -> "<path d='M27 56q7 7 14 0M59 56q7 7 14 0' fill='none' stroke='#6b4a57' stroke-width='4' stroke-linecap='round'/>"
                "happy" -> "<path d='M27 58q7-8 14 0M59 58q7-8 14 0' fill='none' stroke='#6b4a57' stroke-width='4' stroke-linecap='round'/>"
                "sad" -> "<circle cx='34' cy='55' r='3' fill='#6b4a57'/><circle cx='66' cy='55' r='3' fill='#6b4a57'/><path d='M42 74q8-7 16 0' fill='none' stroke='#6b4a57' stroke-width='4'/>"
                _ -> "<circle cx='34' cy='55' r='3' fill='#6b4a57'/><circle cx='66' cy='55' r='3' fill='#6b4a57'/>"
        pattern =
            if breed == 0 || breed == 1 then
                "<path d='M41 30v10M50 29v11M59 30v10' stroke='" ++ mark ++ "' stroke-width='5'/>"
            else if breed == 4 then
                "<path d='M12 37Q50 5 88 37L72 46 50 37 28 46Z' fill='" ++ mark ++ "'/>"
            else if breed == 5 then
                "<ellipse cx='28' cy='39' rx='18' ry='12' fill='" ++ mark ++ "'/><ellipse cx='72' cy='39' rx='18' ry='12' fill='#4d434a'/>"
            else if breed == 6 then
                "<ellipse cx='50' cy='68' rx='18' ry='11' fill='" ++ mark ++ "'/>"
            else ""
        svg =
            "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'>"
                ++ "<path d='M14 46 20 8 46 28ZM86 46 80 8 54 28Z' fill='" ++ fur ++ "' stroke='#6b4a57' stroke-width='4'/>"
                ++ "<ellipse cx='50' cy='60' rx='41' ry='34' fill='" ++ fur ++ "' stroke='#6b4a57' stroke-width='4'/>"
                ++ pattern ++ eyes
                ++ "<path d='M46 63h8l-4 5z' fill='#ff6f91'/><path d='M40 72q5 5 10 0q5 5 10 0' fill='none' stroke='#6b4a57' stroke-width='3'/></svg>"
    in
    img [ class "cat-image", src ("data:image/svg+xml," ++ Url.percentEncode svg), attribute "alt" "" ] []


formatTime : Float -> String
formatTime n =
    let
        tenths = round (n * 10)
    in
    String.fromInt (tenths // 10) ++ "." ++ String.fromInt (modBy 10 tenths)


cellAt : Int -> Board -> Maybe Cell
cellAt k board = Array.get k board.cells


viewCell : Model -> Int -> Html Msg
viewCell model k =
    let
        current = model.board |> Maybe.andThen (cellAt k)
        opened = current |> Maybe.map .opened |> Maybe.withDefault False
        flagged = current |> Maybe.map .flagged |> Maybe.withDefault False
        isCat = current |> Maybe.map .cat |> Maybe.withDefault False
        number = current |> Maybe.map .number |> Maybe.withDefault 0
        breed = current |> Maybe.map .breed |> Maybe.withDefault 0
        cols = (levelSpec model.level).cols
        row = k // cols + 1
        col = modBy cols k + 1
        content =
            if opened && isCat then [ catImage breed "sad" ]
            else if opened && number > 0 then [ text (String.fromInt number) ]
            else if model.over && isCat then [ catImage breed (if flagged then "happy" else "sleep") ]
            else if flagged then [ span [ class "blanket" ] [ text "🐱" ], span [ class "quilt" ] [ text "" ] ]
            else []
    in
    button
        [ classList [ ( "cell", True ), ( "open", opened ), ( "flagged", flagged && not opened ), ( "boom", opened && isCat ), ( "n" ++ String.fromInt number, opened ) ]
        , attribute "data-cell" (String.fromInt k)
        , attribute "aria-label" (String.fromInt row ++ "行" ++ String.fromInt col ++ "列" ++ (if flagged then "、毛布の目印" else if opened then "、開いたマス" else "、未開封"))
        , onClick (Open k)
        , preventDefaultOn "contextmenu" (Decode.succeed ( Flag k, True ))
        ]
        content


viewDex : Model -> Html Msg
viewDex model =
    let
        discovered = Array.toList model.dex |> List.filter ((<) 0) |> List.length
        card k =
            let
                count = Array.get k model.dex |> Maybe.withDefault 0
                info = breedInfo k
            in
            div [ classList [ ( "dex-card", True ), ( "unknown", count == 0 ) ] ]
                [ catImage k (if count == 0 then "sleep" else "happy")
                , span [] [ text (if count == 0 then "？？？" else info.name) ]
                , small [] [ text (String.repeat info.rarity "★" ++ String.repeat (4 - info.rarity) "☆") ]
                , small [] [ text (if count == 0 then "" else "発見 " ++ String.fromInt count ++ "匹") ]
                ]
    in
    details [ id "dex" ]
        [ summary [] [ text ("ねこ図鑑 " ++ String.fromInt discovered ++ "/8") ]
        , div [ class "dex-grid" ] (List.map card (List.range 0 7))
        ]


view : Model -> Html Msg
view model =
    let
        level = levelSpec model.level
        rows = level.rows
        cols = level.cols
        cats = level.cats
        board = model.board
        flags = board |> Maybe.map (\b -> Array.toList b.cells |> List.filter .flagged |> List.length) |> Maybe.withDefault 0
        best = Array.get model.level model.best |> Maybe.withDefault 0
        cells = List.range 0 (rows - 1) |> List.map (\r -> div [ class "row" ] (List.map (viewCell model) (List.range (r * cols) (r * cols + cols - 1))))
        freshNames = model.fresh |> List.map (\n -> (breedInfo n).name) |> String.join "、"
    in
    div [ class "app" ]
        [ h1 [] [ text "🐾 ねこマインスイーパー 🐾" ]
        , p [] [ text "寝ている猫を起こさないように、猫のいないクッションを全部めくってね" ]
        , div [ class "bar" ]
            [ select [ id "level", value (String.fromInt model.level), onInput Choose ]
                (List.indexedMap (\i item -> option [ value (String.fromInt i) ] [ text item.name ]) levels)
            , span [] [ text ("💤 × " ++ String.fromInt (cats - flags)) ]
            , span [] [ text ("🕒 " ++ formatTime model.seconds) ]
            , span [] [ text ("👑 " ++ (if best == 0 then "--" else formatTime best)) ]
            , button [ id "face", onClick Restart, attribute "aria-label" "リスタート" ] [ catImage 0 (if model.over then (if model.won then "happy" else "sad") else "normal") ]
            , button [ onClick ToggleSound, attribute "aria-pressed" (if model.muted then "false" else "true") ] [ text (if model.muted then "おと OFF" else "おと ON") ]
            ]
        , details [ id "help" ]
            [ summary [] [ text "遊び方" ]
            , ul []
                [ li [] [ text "クリック（タップ）でクッションをめくる" ]
                , li [] [ text "数字は、まわり6マスで寝ている猫の数" ]
                , li [] [ text "右クリック（スマホは長押し）で、猫がいそうなマスに毛布をかける" ]
                , li [] [ text "猫のいないマスを全部めくったらクリア" ]
                , li [] [ text "どの盤面も運に頼らず推理だけで解けるよ" ]
                , li [] [ text "クリアで全猫、負けても正しく目印した猫を図鑑に記録" ]
                ]
            ]
        , viewDex model
        , div [ id "board-scroll" ] [ div [ id "board" ] cells ]
        , div [ id "msg" ]
            [ text model.message
            , if model.caught > 0 then p [] [ text ("猫を" ++ String.fromInt model.caught ++ "匹発見" ++ (if List.isEmpty model.fresh then "" else "！ はじめて会った猫：" ++ freshNames)) ] else text ""
            ]
        ]
