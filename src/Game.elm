module Game exposing (Board, Cell, addToDex, catCount, caughtBreeds, fromCats, generate, isCat, isFlagged, isOpened, isWon, neighbors, reveal, solvable, toggleFlag)

import Array exposing (Array)
import Set exposing (Set)


type alias Cell =
    { cat : Bool, breed : Int, number : Int, opened : Bool, flagged : Bool }


type alias Board =
    { rows : Int, cols : Int, cells : Array Cell }


cell : Int -> Board -> Cell
cell k board =
    Array.get k board.cells
        |> Maybe.withDefault { cat = False, breed = 0, number = 0, opened = False, flagged = False }


indices : Board -> List Int
indices board =
    List.range 0 (board.rows * board.cols - 1)


neighbors : Int -> Int -> Int -> List Int
neighbors rows cols k =
    let
        row = k // cols
        col = modBy cols k
        diagonals =
            if modBy 2 row == 1 then
                [ ( -1, 0 ), ( -1, 1 ), ( 1, 0 ), ( 1, 1 ) ]
            else
                [ ( -1, -1 ), ( -1, 0 ), ( 1, -1 ), ( 1, 0 ) ]
    in
    List.filterMap
        (\( dr, dc ) ->
            let
                r = row + dr
                c = col + dc
            in
            if r >= 0 && r < rows && c >= 0 && c < cols then
                Just (r * cols + c)
            else
                Nothing
        )
        (( 0, -1 ) :: ( 0, 1 ) :: diagonals)


fromBreeds : Int -> Int -> List ( Int, Int ) -> Board
fromBreeds rows cols cats =
    let
        catSet = Set.fromList (List.map Tuple.first cats)
        breedAt k =
            cats |> List.filter (\( position, _ ) -> position == k) |> List.head |> Maybe.map Tuple.second |> Maybe.withDefault 0
        cells =
            List.range 0 (rows * cols - 1)
                |> List.map
                    (\k ->
                        { cat = Set.member k catSet
                        , breed = breedAt k
                        , number = List.length (List.filter (\n -> Set.member n catSet) (neighbors rows cols k))
                        , opened = False
                        , flagged = False
                        }
                    )
    in
    { rows = rows, cols = cols, cells = Array.fromList cells }


fromCats : Int -> Int -> List Int -> Board
fromCats rows cols cats =
    fromBreeds rows cols (List.map (\k -> ( k, 0 )) cats)


nextSeed : Int -> Int
nextSeed seed =
    modBy 2147483647 (seed * 48271)


breedFor : Int -> Int
breedFor n =
    let
        x = modBy 100 n
    in
    if x < 30 then 0
    else if x < 50 then 1
    else if x < 65 then 2
    else if x < 80 then 3
    else if x < 90 then 4
    else if x < 96 then 5
    else if x < 99 then 6
    else 7


candidate : Int -> Int -> Int -> Int -> Int -> ( Board, Int )
candidate rows cols cats start seed =
    let
        safe = Set.fromList (start :: neighbors rows cols start)
        spots = List.range 0 (rows * cols - 1) |> List.filter (\k -> not (Set.member k safe))
        step k ( s, pairs ) =
            let
                a = nextSeed s
                b = nextSeed a
            in
            ( b, ( a, k, breedFor b ) :: pairs )
        ( last, shuffled ) = List.foldl step ( seed, [] ) spots
        selected =
            shuffled
                |> List.sortBy (\( key, _, _ ) -> key)
                |> List.take cats
                |> List.map (\( _, k, breed ) -> ( k, breed ))
    in
    ( fromBreeds rows cols selected, last )


generate : Int -> Int -> Int -> Int -> Int -> Maybe Board
generate rows cols cats start seed =
    let
        attempt remaining current =
            let
                ( board, next ) = candidate rows cols cats start current
            in
            if solvable start board then
                Just board
            else if remaining <= 1 then
                Nothing
            else
                attempt (remaining - 1) (nextSeed next)
    in
    if rows <= 0 || cols <= 0 || start < 0 || start >= rows * cols || cats < 0 || cats > rows * cols - 1 - List.length (neighbors rows cols start) then
        Nothing
    else
        attempt 5000 (max 1 (modBy 2147483647 seed))


catCount : Board -> Int
catCount board =
    List.length (List.filter (\k -> isCat k board) (indices board))


isCat : Int -> Board -> Bool
isCat k board =
    (cell k board).cat


isOpened : Int -> Board -> Bool
isOpened k board =
    (cell k board).opened


isFlagged : Int -> Board -> Bool
isFlagged k board =
    (cell k board).flagged


toggleFlag : Int -> Board -> Board
toggleFlag k board =
    let
        old = cell k board
    in
    if old.opened then board
    else { board | cells = Array.set k { old | flagged = not old.flagged } board.cells }


reveal : Int -> Board -> Board
reveal k board =
    let
        open pending cells =
            case pending of
                [] -> cells
                x :: rest ->
                    case Array.get x cells of
                        Nothing -> open rest cells
                        Just current ->
                            if current.opened || current.flagged then open rest cells
                            else if current.cat then open rest (Array.set x { current | opened = True } cells)
                            else
                                let
                                    more = if current.number == 0 then neighbors board.rows board.cols x else []
                                in
                                open (more ++ rest) (Array.set x { current | opened = True } cells)
        first = cell k board
    in
    if first.opened || first.flagged then board
    else if first.cat then { board | cells = Array.set k { first | opened = True } board.cells }
    else { board | cells = open [ k ] board.cells }


isWon : Board -> Bool
isWon board =
    Array.toList board.cells |> List.all (\c -> c.cat || c.opened)


caughtBreeds : Bool -> Board -> List Int
caughtBreeds won board =
    Array.toList board.cells
        |> List.filter (\c -> c.cat && (won || c.flagged))
        |> List.map .breed


addToDex : Array Int -> List Int -> ( Array Int, List Int )
addToDex dex breeds =
    let
        step breed ( counts, firsts ) =
            let
                old = Array.get breed counts |> Maybe.withDefault 0
            in
            ( Array.set breed (old + 1) counts
            , if old == 0 && not (List.member breed firsts) then firsts ++ [ breed ] else firsts
            )
    in
    List.foldl step ( dex, [] ) breeds


type alias Constraint =
    { cells : List Int, mines : Int }


simOpen : Board -> List Int -> Array Int -> Array Int
simOpen board pending state =
    case pending of
        [] -> state
        k :: rest ->
            if Array.get k state /= Just 0 then simOpen board rest state
            else
                let
                    more = if (cell k board).number == 0 then neighbors board.rows board.cols k else []
                in
                simOpen board (more ++ rest) (Array.set k 1 state)


constraints : Board -> Array Int -> List Constraint
constraints board state =
    let
        unknown = indices board |> List.filter (\k -> Array.get k state == Just 0)
        found = indices board |> List.filter (\k -> Array.get k state == Just 2) |> List.length
        local k =
            if Array.get k state /= Just 1 || (cell k board).number == 0 then Nothing
            else
                let
                    around = neighbors board.rows board.cols k
                    pending = List.filter (\n -> Array.get n state == Just 0) around
                    known = List.filter (\n -> Array.get n state == Just 2) around |> List.length
                in
                if List.isEmpty pending then Nothing
                else Just { cells = pending, mines = (cell k board).number - known }
    in
    { cells = unknown, mines = catCount board - found } :: List.filterMap local (indices board)


settle : Board -> Array Int -> Constraint -> Maybe (Array Int)
settle board state constraint =
    if List.isEmpty constraint.cells || not (constraint.mines == 0 || constraint.mines == List.length constraint.cells) then Nothing
    else if constraint.mines == 0 then Just (simOpen board constraint.cells state)
    else Just (List.foldl (\k acc -> Array.set k 2 acc) state constraint.cells)


firstSettle : Board -> Array Int -> List Constraint -> Maybe (Array Int)
firstSettle board state all =
    case all of
        [] -> Nothing
        current :: rest ->
            case settle board state current of
                Just changed -> Just changed
                Nothing -> firstSettle board state rest


subsetDiffs : List Constraint -> List Constraint
subsetDiffs all =
    List.concatMap
        (\a ->
            List.filterMap
                (\b ->
                    if List.length a.cells < List.length b.cells && List.all (\k -> List.member k b.cells) a.cells then
                        Just { cells = List.filter (\k -> not (List.member k a.cells)) b.cells, mines = b.mines - a.mines }
                    else Nothing
                )
                all
        )
        all


solvable : Int -> Board -> Bool
solvable start board =
    let
        loop state =
            if not (Array.toList state |> List.member 0) then True
            else
                let
                    cons = constraints board state
                    next =
                        case firstSettle board state cons of
                            Just changed -> Just changed
                            Nothing -> firstSettle board state (subsetDiffs cons)
                in
                case next of
                    Just changed -> if changed == state then False else loop changed
                    Nothing -> False
    in
    if isCat start board then False
    else loop (simOpen board [ start ] (Array.repeat (board.rows * board.cols) 0))
