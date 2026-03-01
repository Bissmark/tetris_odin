package main

import "core:fmt"
import "core:log"
import SDL "vendor:sdl3"
import "core:math/rand"

Vec2 :: [2]f32

PIECE_O :: [4][4]int {
    {0, 1, 1, 0},
    {0, 1, 1, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0},
}

PIECE_I :: [4][4]int {
    {1, 1, 1, 1},
    {0, 0, 0, 0},
    {0, 0, 0, 0},
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
    {0, 1, 1, 0},
    {0, 0, 1, 1},
    {0, 0, 0, 0},
    {0, 0, 0, 0},
}

PIECE_T :: [4][4]int {
    {0, 0, 1, 0},
    {0, 1, 1, 1},
    {0, 0, 0, 0},
    {0, 0, 0, 0},
}

PIECE_S :: [4][4]int {
    {0, 0, 1, 1},
    {0, 1, 1, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0},
}

Game :: struct {
    window: ^SDL.Window,
    renderer: ^SDL.Renderer,
    event: SDL.Event,

    play_area: SDL.FRect,
    next_piece_box: SDL.FRect,

    board: [20][10]int,
    next_piece: Piece,
    active_piece: Piece,

    last_tick: u64,
}

Piece :: struct {
    shape: [4][4]int,
    row: int,
    col: int,
    speed: int,
    locked: bool
}

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

    spawn_next_block(game)
    spawn_next_block(game)

    game.next_piece_box.w = 100
    game.next_piece_box.h = 100
    game.next_piece_box.x = game.play_area.x + 325
    game.next_piece_box.y = 0

    return true
}

update :: proc(game: ^Game) {
    now := SDL.GetTicks()
    if now - game.last_tick >= 1000 {
        game.last_tick = now
        if is_valid_position(game, game.active_piece.shape, game.active_piece.row + 1, game.active_piece.col) {
            game.active_piece.row += 1
        } else {
            game.active_piece.locked = true
        }

        if game.active_piece.locked == true {
            lock_piece(game)
            spawn_next_block(game)
        } 
    }
}

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
            if game.board[row][col] == 1 {
                SDL.SetRenderDrawColor(game.renderer, 255, 255, 255, 255)
            } else {
                SDL.SetRenderDrawColor(game.renderer, 50, 100, 50, 255)
            }
            SDL.RenderFillRect(game.renderer, &rect)
        }
    }
}

render_next_block :: proc(game: ^Game) {
    cell_w := game.next_piece_box.w / 4
    cell_h := game.next_piece_box.h / 4

    for row in 0..<4 {
        for col in 0..<4 {
            if game.next_piece.shape[row][col] == 1 {
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

render_block_in_play_area :: proc(game: ^Game) {
    cell_w := game.play_area.w / 10
    cell_h := game.play_area.h / 20

    for row in 0..<4 {
        for col in 0..<4 {
            if game.active_piece.shape[row][col] == 1 {
                rect := SDL.FRect {
                    x = game.play_area.x + f32(game.active_piece.col + col) * cell_w,
                    y = game.play_area.y + f32(game.active_piece.row + row) * cell_h,
                    w = cell_w,
                    h = cell_h,
                }
                SDL.SetRenderDrawColor(game.renderer, 255, 255, 255, 255)
                SDL.RenderFillRect(game.renderer, &rect)
            }
        }
    }
}

lock_piece :: proc(game: ^Game) {
    for row in 0..<4 {
        for col in 0..<4 {
            if game.active_piece.shape[row][col] == 1 {
                board_row := game.active_piece.row + row
                board_col := game.active_piece.col + col
                if board_row >= 0 && board_row < 20 && board_col >= 0 && board_col < 10 {
                    game.board[board_row][board_col] = 1
                }
            }
        }
    }
}

spawn_next_block :: proc(game: ^Game){
    game.active_piece = game.next_piece
    game.active_piece.col = 3
    game.active_piece.row = 0

    switch rand.int_max(7) {
        case 0:
            game.next_piece.shape = PIECE_O
        case 1:
            game.next_piece.shape = PIECE_I
        case 2:
            game.next_piece.shape = PIECE_J
        case 3:
            game.next_piece.shape = PIECE_L
        case 4:
            game.next_piece.shape = PIECE_S
        case 5:
            game.next_piece.shape = PIECE_T
        case 6:
            game.next_piece.shape = PIECE_Z
    }
}

is_valid_position :: proc(game: ^Game, shape: [4][4]int, row: int, col: int) -> bool {
    for r in 0..<4 {
        for c in 0..<4 {
            if shape[r][c] == 1 {
                new_row := row + r
                new_col := col + c
                if new_row < 0 || new_row >= 20 || new_col < 0 || new_col >= 10 {
                    return false
                }
                if game.board[new_row][new_col] == 1 {
                    return false
                }
            }
        }
    }
    return true
}

rotate_piece :: proc(game: ^Game) {
    new_shape: [4][4]int
    for col in 0..<4 {
        for row in 0..<4 {
            new_shape[col][3 - row] = game.active_piece.shape[row][col]
        }
    }
    
    kicks := []int{0, 1, -1, 2, -2}
    for kick in kicks {
        if is_valid_position(game, new_shape, game.active_piece.row, game.active_piece.col + kick) {
            game.active_piece.shape = new_shape
            game.active_piece.col += kick
            break
        }
    }
}

main_loop :: proc(game: ^Game) {
    for {
        for SDL.PollEvent(&game.event) {
            #partial switch game.event.type {
                case .QUIT:
                    return
                case .KEY_DOWN:
                    if game.event.key.scancode == .LEFT {
                        if is_valid_position(game, game.active_piece.shape, game.active_piece.row, game.active_piece.col - 1) {
                            game.active_piece.col -= 1
                        }
                    }
                    if game.event.key.scancode == .RIGHT {
                        if is_valid_position(game, game.active_piece.shape, game.active_piece.row, game.active_piece.col + 1) {
                            game.active_piece.col += 1
                        }
                    }
                    if game.event.key.scancode == .DOWN {
                        if is_valid_position(game, game.active_piece.shape, game.active_piece.row + 1, game.active_piece.col) {
                            game.active_piece.row += 1
                        }
                    }
                    if game.event.key.scancode == .UP {
                        rotate_piece(game)
                    }
            }
        }

        SDL.SetRenderDrawColor(game.renderer, 0, 0, 0, 255)
        SDL.RenderClear(game.renderer)

        render_board(game)
        render_next_block(game)
        render_block_in_play_area(game)
        update(game)

        SDL.RenderPresent(game.renderer)
        SDL.Delay(16) // 60 fps cap
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