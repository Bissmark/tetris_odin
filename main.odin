package main

import "core:fmt"
import "core:log"
import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"
import "core:math/rand"

Vec2 :: [2]f32
FONT_SIZE :: 40
FONT_COLOR :: SDL.Color{255, 255, 255, 225}

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
    timer_rect: SDL.Rect,
    timer_image: ^SDL.Texture,
    score_rect: SDL.Rect,
    score_image: ^SDL.Texture,
    difficulty_rect: SDL.Rect,
    difficulty_image: ^SDL.Texture,

    board: [20][10]int,
    next_piece: Piece,
    active_piece: Piece,

    last_tick: u64,
    seconds: int,
    minutes: int,

    font: ^TTF.Font,
    score: int,
    difficulty: int,
    lines_cleared: int,
    drop_interval: u64,
    last_timer_tick: u64,
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
    TTF.Init()

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

    game.font = TTF.OpenFont("fonts/ShareTechMono-Regular.ttf", FONT_SIZE)
    if game.font == nil {
        log.error("Failed to load font:", SDL.GetError())
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

    game.difficulty = 10
    game.drop_interval = u64(max(100, 1000 - (game.difficulty - 1) * 100))

    return true
}

update :: proc(game: ^Game) {
    now := SDL.GetTicks()
    if now - game.last_tick >= game.drop_interval {
        game.last_tick = now
        score(game)
        difficulty(game)
        if is_valid_position(game, game.active_piece.shape, game.active_piece.row + 1, game.active_piece.col) {
            game.active_piece.row += 1
        } else {
            game.active_piece.locked = true
        }

        if game.active_piece.locked == true {
            lock_piece(game)
            clear_lines(game)
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

timer :: proc(game: ^Game) -> bool {
    timer_text := fmt.ctprintf("%02d:%02d", game.minutes, game.seconds)

    font_surf := TTF.RenderText_Blended(game.font, timer_text, 0, FONT_COLOR)
    if font_surf == nil {
        log.error("Failed to render text:", SDL.GetError())
        return false
    }

    game.timer_rect.w = font_surf.w
    game.timer_rect.h = font_surf.h
    game.timer_rect.x = i32(game.play_area.x) - font_surf.w - 10
    game.timer_rect.y = 10

    game.timer_image = SDL.CreateTextureFromSurface(game.renderer, font_surf)
    SDL.DestroySurface(font_surf)

    return true
}

score :: proc(game: ^Game) -> bool {
    score_text := fmt.ctprint("Score: ", game.score)

    font_surf := TTF.RenderText_Blended(game.font, score_text, 0, FONT_COLOR)
    if font_surf == nil {
        log.error("Failed to render text:", SDL.GetError())
        return false
    }

    game.score_rect.w = font_surf.w
    game.score_rect.h = font_surf.h
    game.score_rect.x = i32(game.play_area.x) - font_surf.w - 10
    game.score_rect.y = 60

    game.score_image = SDL.CreateTextureFromSurface(game.renderer, font_surf)
    SDL.DestroySurface(font_surf)

    return true
}

difficulty :: proc(game: ^Game) -> bool {
    difficulty_text := fmt.ctprint("Level: ", game.difficulty)

    font_surf := TTF.RenderText_Blended(game.font, difficulty_text, 0, FONT_COLOR)
    if font_surf == nil {
        log.error("Failed to render text:", SDL.GetError())
        return false
    }

    game.difficulty_rect.w = font_surf.w
    game.difficulty_rect.h = font_surf.h
    game.difficulty_rect.x = i32(game.play_area.x) - font_surf.w - 10
    game.difficulty_rect.y = 110

    game.difficulty_image = SDL.CreateTextureFromSurface(game.renderer, font_surf)
    SDL.DestroySurface(font_surf)

    return true
}

clear_lines :: proc(game: ^Game) {
    for row in 0..<20 {
        full := true
        for col in 0..<10 {
            if game.board[row][col] == 0 {
                full = false
                break
            }
        }
        if full {
            // shift everything above this row down by one
            for r := row; r > 0; r -= 1 {
                game.board[r] = game.board[r - 1]
            }
            // clear the row
            game.board[0] = {}
            game.score += 100
            game.lines_cleared += 1

            if game.lines_cleared % 10 == 0 && game.lines_cleared > 0 {
                game.difficulty += 1
                game.drop_interval -= 100
                if game.drop_interval < 100 {
                    game.drop_interval = 100
                }
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
        now := SDL.GetTicks()
        if now - game.last_timer_tick >= 1000 {
            game.last_timer_tick = now
            game.seconds += 1
            if game.seconds >= 60 {
                game.seconds = 0
                game.minutes += 1
            }
            timer(game)
        }
        update(game)

        dst_timer := SDL.FRect{
            x = f32(game.timer_rect.x),
            y = f32(game.timer_rect.y),
            w = f32(game.timer_rect.w),
            h = f32(game.timer_rect.h),
        }

        SDL.RenderTexture(game.renderer, game.timer_image, nil, &dst_timer)

        dst_score := SDL.FRect{
            x = f32(game.score_rect.x),
            y = f32(game.score_rect.y),
            w = f32(game.score_rect.w),
            h = f32(game.score_rect.h),
        }

        SDL.RenderTexture(game.renderer, game.score_image, nil, &dst_score)

        dst_difficulty := SDL.FRect{
            x = f32(game.difficulty_rect.x),
            y = f32(game.difficulty_rect.y),
            w = f32(game.difficulty_rect.w),
            h = f32(game.difficulty_rect.h),
        }

        SDL.RenderTexture(game.renderer, game.difficulty_image, nil, &dst_difficulty)

        SDL.RenderPresent(game.renderer)
        SDL.Delay(16) // 60 fps cap
    }
}

main :: proc() {
    fmt.printf("hello world")

    game: Game

    if !initialize(&game) do return
    if !timer(&game) do return
    if !score(&game) do return
    if !difficulty(&game) do return
    main_loop(&game)

    TTF.CloseFont(game.font)
    SDL.DestroyWindow(game.window)
    SDL.DestroyRenderer(game.renderer)
    SDL.Quit()
}