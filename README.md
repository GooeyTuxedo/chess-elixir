# Elixir Chess Game

This Phoenix LiveView chess application provides a fully functional two-player chess game with real-time updates and all standard chess rules. Here's a summary of what I've built and the key decisions made:

## Core Components

1. **Board Representation** - A comprehensive model representing a chess board with piece positions, castling rights, en passant targets, and move counters.

2. **Move Validation** - A robust validator that enforces all chess rules including special moves like castling, en passant, and pawn promotion.

3. **Game Server** - A GenServer-based approach for managing game state, handling concurrent games, and broadcasting moves to players.

4. **Real-time UI** - LiveView implementation enabling real-time board updates, move highlighting, and player interactions.

## Key Design Decisions

### Deferring User Authentication

I decided to defer implementing user authentication in favor of session-based player identification because:

- It simplified the initial architecture, allowing us to focus on the core chess gameplay
- It reduced development time while still providing a fully functional experience
- Players can be uniquely identified within their browser session
- The system remains flexible enough to add authentication later when needed

### State Management

The project uses Elixir's actor model through GenServers:
- Each game is managed by a separate GameServer process
- A Registry tracks all active games
- A DynamicSupervisor ensures fault tolerance

### Real-time Updates

The real-time gameplay is implemented using:
- Phoenix PubSub for broadcasting moves and game events
- LiveView for seamless UI updates without page refreshes
- Pattern matching to handle various game events (moves, player joins, game endings)

### Session-Based Identity

Instead of user accounts, I implemented a session-based approach:
- Players receive a random session ID and nickname
- Games recognize returning players based on their session
- The approach is lightweight but sufficient for casual play

## Game Features

The implementation includes all standard chess rules:
- Basic movement for all piece types
- Castling (kingside and queenside)
- En passant captures
- Pawn promotion
- Check and checkmate detection
- Draw conditions (stalemate, insufficient material, fifty-move rule)

## Technical Highlights

- **Concurrency** - Multiple games can run simultaneously thanks to Elixir's lightweight processes
- **Fault Tolerance** - Supervision ensures that individual game failures don't affect the entire system
- **Pattern Matching** - Elixir's pattern matching creates clean, readable code for complex chess rules
- **Real-time UI** - LiveView provides a responsive experience without complex client-side JavaScript
- **Containerization** - Docker setup for consistent development environments

## Future Enhancements

Possible next steps include:
- Adding move history with standard chess notation
- Implementing a simple AI opponent
- Adding game persistence to the database
- Introducing player ratings and matchmaking
- Adding time controls (chess clock)
- Implementing user authentication when needed

This project demonstrates effective use of Elixir and Phoenix LiveView for building real-time, stateful applications with complex business logic and interactive UIs.