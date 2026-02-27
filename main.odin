package main

import "core:fmt"
import "core:log"
import SDL "vendor:sdl3"

Vec2 :: [2]f32

PIECE_O :: [4][4]int {
    {0, 0, 0, 0},
    {0, 1, 1, 0},
    {0, 1, 1, 0},
    {0, 0, 0, 0},
}

PIECE_I :: [4][4]int {
    {0, 0, 0, 0},
    {0, 0, 0, 0},
    {1, 1, 1, 1},
    {0, 0, 0, 0},
}

PIECE_J :: [4][4]int {
    {0, 0, 1, 0},
    {0, 0, 1, 0},
    {0, 1, 1, 0},
    {0, 0, 0, 0},
}

PIECE_L :: [4][4]int {
    {0, 1, 0, 0},
    {0, 1, 0, 0},
    {0, 1, 1, 0},
    {0, 0, 0, 0},
}

PIECE_Z :: [4][4]int {
    {0, 0, 0, 0},
    {1, 1, 0, 0},
    {0, 1, 1, 0},
    {0, 0, 0, 0},
}

PIECE_T :: [4][4]int {
    {0, 0, 0, 0},
    {0, 1, 0, 0},
    {1, 1, 1, 0},
    {0, 0, 0, 0},
}

PIECE_S :: [4][4]int {
    {0, 0, 0, 0},
    {0, 1, 1, 0},
    {1, 1, 0, 0},
    {0, 0, 0, 0},
}

Game :: struct {
    window: ^SDL.Window,
    renderer: ^SDL.Renderer,
    event: SDL.Event,

    play_area: SDL.FRect,
    next_piece_box: SDL.FRect,

    board: [20][10]int,
    next_piece: [4][4]int,
}

// Game_Area :: struct {
//     cell: bool
// }

SCREEN_WIDTH :: 720
SCREEN_HEIGHT :: 560

initialize :: proc(game: ^Game) -> bool {
    game.window = SDL.CreateWindow("Tetris", SCREEN_WIDTH, SCREEN_HEIGHT, {})
    if game.window == nil {
        log.error("Failed to create window:", SDL.GetError())
        return false
    }

    game.renderer = SDL.CreateRenderer(game.window, nil)
    if game.renderer == nil {
        log.error("Failed to create renderer:", SDL.GetError())
        return false
    }

    SDL.SetRenderVSync(game.renderer, 1)

    game.play_area.w = 300
    game.play_area.h = SCREEN_HEIGHT
    game.play_area.x = SCREEN_WIDTH / 2 - game.play_area.w / 2
    game.play_area.y = 0

    game.next_piece = PIECE_S

    game.next_piece_box.w = 100
    game.next_piece_box.h = 100
    game.next_piece_box.x = game.play_area.x + 325
    game.next_piece_box.y = 0

    return true
}

update :: proc() {

}

// render_game_area :: proc(game: ^Game) {
//     SDL.SetRenderDrawColor(game.renderer, 30, 30, 30, 255)
//     SDL.RenderFillRect(game.renderer, &game.play_area)
// }

render_board :: proc(game: ^Game) {
    cell_w := game.play_area.w / 10
    cell_h := game.play_area.h / 20

    for row in 0..<20 {
        for col in 0..<10 {
            rect := SDL.FRect{
                x = game.play_area.x + f32(col) * cell_w,
                y = game.play_area.y + f32(row) * cell_h,
                w = cell_w,
                h = cell_h,
            }
            SDL.SetRenderDrawColor(game.renderer, 50, 100, 50, 255)
            SDL.RenderFillRect(game.renderer, &rect)
        }
    }
}

render_next_piece :: proc(game: ^Game) {
    cell_w := game.next_piece_box.w / 4
    cell_h := game.next_piece_box.h / 4

    for row in 0..<4 {
        for col in 0..<4 {
            if game.next_piece[row][col] == 1 {
                rect := SDL.FRect{
                    x = game.next_piece_box.x + f32(col) * cell_w,
                    y = game.next_piece_box.y + f32(row) * cell_h,
                    w = cell_w,
                    h = cell_h,
                }
                SDL.SetRenderDrawColor(game.renderer, 255, 255, 255, 255)
                SDL.RenderRect(game.renderer, &game.next_piece_box) // outline box instead of filled
                SDL.RenderFillRect(game.renderer, &rect)
            }
        }
    }
}

main_loop :: proc(game: ^Game) {
    for {
        for SDL.PollEvent(&game.event) {
            #partial switch game.event.type {
                case .QUIT:
                    return
            }
        }

        // update()

        SDL.SetRenderDrawColor(game.renderer, 0, 0, 0, 255)
        SDL.RenderClear(game.renderer)

        //render_game_area(game)
        render_board(game)
        render_next_piece(game)

        SDL.RenderPresent(game.renderer)
    }
}

main :: proc() {
    fmt.printf("hello world")

    game: Game

    if !initialize(&game) do return
    main_loop(&game)

    SDL.DestroyWindow(game.window)
    SDL.DestroyRenderer(game.renderer)
    SDL.Quit()
}