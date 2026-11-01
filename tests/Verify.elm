port module Verify exposing (main)

import Game
import Platform
import Array

port result : List Bool -> Cmd msg

main : Program () () Never
main =
    Platform.worker
        { init = \_ ->
            let
                tiny = Game.fromCats 3 3 [ 0 ]
                opened = Game.reveal 8 tiny
                marked = Game.toggleFlag 0 tiny
                wrongMark = Game.toggleFlag 1 marked
                solved = Game.fromCats 1 5 [ 2 ]
                ambiguous = Game.fromCats 1 5 [ 2, 4 ]
                first = Game.generate 9 9 10 40 12345
                medium = Game.generate 16 16 40 120 12345
                expert = Game.generate 16 30 99 240 12345
            in
            ( (), result
                [ Game.neighbors 5 5 12 == [ 11, 13, 6, 7, 16, 17 ]
                , Game.neighbors 5 5 7 == [ 6, 8, 2, 3, 12, 13 ]
                , Maybe.map Game.catCount first == Just 10
                , Maybe.map (\board -> List.all (\k -> not (Game.isCat k board)) (40 :: Game.neighbors 9 9 40)) first == Just True
                , Game.solvable 0 solved
                , not (Game.solvable 0 ambiguous)
                , Game.isWon opened
                , Game.isFlagged 0 marked && not (Game.isOpened 0 (Game.reveal 0 marked))
                , Maybe.map (Game.solvable 120) medium == Just True
                , Maybe.map (Game.solvable 240) expert == Just True
                , Game.generate 1 5 5 0 12345 == Nothing
                , Game.caughtBreeds False wrongMark == [ 0 ]
                , Game.caughtBreeds True wrongMark == [ 0 ]
                , Game.addToDex (Array.fromList [ 2, 0 ]) [ 0, 1, 1 ] == ( Array.fromList [ 3, 2 ], [ 1 ] )
                ]
              )
        , update = \msg _ -> Basics.never msg
        , subscriptions = \_ -> Sub.none
        }
