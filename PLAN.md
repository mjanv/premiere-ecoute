# Eurovision on Twitch - Implementation Plan

> **Document Purpose**: This plan outlines the complete implementation strategy for adding Eurovision-style voting ceremonies to Premiere Ecoute. This is a research and planning document - no implementation has been done yet.

## Table of Contents

1. [Eurovision Voting System Overview](#1-eurovision-voting-system-overview)
2. [Feature Requirements](#2-feature-requirements)
3. [Architectural Design](#3-architectural-design)
4. [Data Model](#4-data-model)
5. [Implementation Phases](#5-implementation-phases)
6. [Technical Decisions Needed](#6-technical-decisions-needed)
7. [Open Questions](#7-open-questions)

---

## 1. Eurovision Voting System Overview

### How Real Eurovision Works

Based on research from [Eurovision official site](https://eurovision.tv/about/how-it-works) and [Wikipedia](https://en.wikipedia.org/wiki/Voting_at_the_Eurovision_Song_Contest):

#### Point Scale
Eurovision uses a specific point scale: **1, 2, 3, 4, 5, 6, 7, 8, 10, and 12 points** (note: 9 and 11 are skipped). Each voting entity (jury or televote) awards these 10 point values to their top 10 favorite songs.

#### Voting Components (Real Eurovision)

| Component | Weight | Description |
|-----------|--------|-------------|
| **National Jury** | 50% | 5-7 music professionals per country vote based on dress rehearsal |
| **Televote** | 50% | Public votes via SMS, phone, or app during the live show |
| **Rest of World** | Bonus | Online votes from non-participating countries, weighted as one country |

#### Key Rules
- **Cannot vote for own country** - fairness requirement
- **Jury votes first, televote second** - dramatic reveal structure
- **Jury criteria**: composition/originality, stage performance, vocal capacity, overall impression
- **Jury composition**: Singers, DJs, composers, lyricists, producers, music critics (must have professional music background)

#### The Dramatic Reveal Sequence
1. **Jury points 1-10**: Each country's spokesperson announces their 12 points live ("And the 12 points from France goes to..."); points 1-8 and 10 are displayed automatically
2. **Televote reveal**: Announced by host in ascending order (lowest-ranked jury country gets their televote first), building to climax
3. **Final tally**: Combined jury + televote determines winner

---

## 2. Feature Requirements

### 2.1 Ceremony Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                     EUROVISION CEREMONY                         │
├─────────────────────────────────────────────────────────────────┤
│  Phase 1: Setup                                                 │
│  ├── Define participating countries (contestants)              │
│  ├── Define voter types (individuals, hosts, delegations)       │
│  ├── Configure point scale (1-12 Eurovision or custom)         │
│  └── Set up media sources (YouTube videos, standalone files)    │
│                                                                 │
│  Phase 2: Performances                                          │
│  ├── Each country performs (video playback)                    │
│  ├── Optional: Vote windows open/close per performance          │
│  └── Real-time viewer count tracking                           │
│                                                                 │
│  Phase 3: Voting                                                │
│  ├── Delegation voting (sortable list - full ranking)          │
│  ├── Host voting (sortable list - full ranking)                │
│  ├── Individual/public voting (single choice or full ranking)   │
│  └── Vote windows can be programmed                            │
│                                                                 │
│  Phase 4: Results Ceremony                                      │
│  ├── Delegation points announced (dramatic reveal)              │
│  ├── Public points announced (ascending order reveal)           │
│  └── Winner announcement                                        │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Voter Types

| Voter Type | Voting Method | Weight | Notes |
|------------|---------------|--------|-------|
| **Individual** | Web: single choice OR sortable list | TBD | Twitch account required |
| **Host** | Web: sortable list (full ranking) | TBD | Special streamer role |
| **Delegation** | Web: sortable list (full ranking) | TBD | Group of jury members representing a "country" |

### 2.3 Vote Input Methods

| Method | Vote Type | UI |
|--------|-----------|-----|
| **Web - One Shot** | Single country selection | Click/tap to select |
| **Web - Full Ranking** | Sortable list ranking all countries | Drag-and-drop interface |
| **SMS** | Single country selection | Text message with country code |

### 2.4 Scoring System

The Eurovision point distribution for a voter's ranked list:

| Rank | Points |
|------|--------|
| 1st  | 12     |
| 2nd  | 10     |
| 3rd  | 8      |
| 4th  | 7      |
| 5th  | 6      |
| 6th  | 5      |
| 7th  | 4      |
| 8th  | 3      |
| 9th  | 2      |
| 10th | 1      |
| 11th+ | 0     |

---

## 3. Architectural Design

### 3.1 Context Structure

Following the existing Premiere Ecoute architecture, create a new `Eurovision` context:

```
lib/premiere_ecoute/
├── eurovision/                          # New context
│   ├── ceremony/                        # Ceremony aggregate
│   │   ├── ceremony.ex                  # Main schema
│   │   ├── commands.ex                  # Command structs
│   │   ├── command_handler.ex           # Command processing
│   │   ├── events.ex                    # Event structs
│   │   └── event_handler.ex             # Event handling
│   │
│   ├── contestants/                     # Countries/contestants
│   │   ├── contestant.ex                # Contestant schema
│   │   └── performance.ex               # Performance/video info
│   │
│   ├── voters/                          # Voter management
│   │   ├── voter.ex                     # Voter schema
│   │   ├── delegation.ex                # Delegation (jury group)
│   │   └── delegation_member.ex         # Jury member schema
│   │
│   ├── voting/                          # Vote collection
│   │   ├── vote.ex                      # Individual vote schema
│   │   ├── delegation_vote.ex           # Delegation vote schema
│   │   ├── vote_window.ex               # Voting time windows
│   │   └── vote_pipeline.ex             # Broadway pipeline
│   │
│   └── results/                         # Results calculation
│       ├── scoreboard.ex                # Live scoreboard state
│       ├── point_calculator.ex          # Point conversion logic
│       └── reveal_sequence.ex           # Dramatic reveal ordering
```

### 3.2 Command/Event Flow

```
                    ┌──────────────────┐
                    │   Streamer UI    │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
    ┌─────────────────┐ ┌──────────┐ ┌───────────────┐
    │ CreateCeremony  │ │ AddVoter │ │ OpenVoteWindow│
    └────────┬────────┘ └────┬─────┘ └───────┬───────┘
             │               │               │
             ▼               ▼               ▼
    ┌─────────────────────────────────────────────────┐
    │              Command Handler                     │
    └─────────────────────┬───────────────────────────┘
                          │
              ┌───────────┼───────────┐
              ▼           ▼           ▼
    ┌────────────┐ ┌────────────┐ ┌─────────────────┐
    │ Ceremony   │ │ Voter      │ │ VoteWindow      │
    │ Created    │ │ Registered │ │ Opened          │
    └─────┬──────┘ └─────┬──────┘ └────────┬────────┘
          │              │                  │
          ▼              ▼                  ▼
    ┌─────────────────────────────────────────────────┐
    │              Event Handlers                      │
    │  - Update database                              │
    │  - Broadcast via PubSub                         │
    │  - Trigger side effects                         │
    └─────────────────────────────────────────────────┘
```

### 3.3 Real-Time Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         PubSub Topics                           │
├─────────────────────────────────────────────────────────────────┤
│  "eurovision:ceremony:{ceremony_id}"                            │
│  ├── :ceremony_started                                          │
│  ├── :performance_started                                       │
│  ├── :vote_window_opened                                        │
│  ├── :vote_window_closed                                        │
│  ├── :scoreboard_updated                                        │
│  └── :ceremony_ended                                            │
│                                                                 │
│  "eurovision:votes:{ceremony_id}"                               │
│  ├── :vote_cast                                                 │
│  ├── :delegation_vote_cast                                      │
│  └── :vote_totals_updated                                       │
│                                                                 │
│  "eurovision:reveal:{ceremony_id}"                              │
│  ├── :delegation_points_announced                               │
│  ├── :public_points_announced                                   │
│  └── :final_results                                             │
└─────────────────────────────────────────────────────────────────┘
```

### 3.4 Integration with Existing Systems

| Existing Feature | Integration Point |
|-----------------|-------------------|
| **Twitch OAuth** | Voter authentication (individuals, hosts, delegation members) |
| **PubSub** | Real-time scoreboard updates, vote notifications |
| **Presence** | Track active voters, show who's voted |
| **Overlay System** | OBS overlay for live scoreboard display |
| **Broadway Pipelines** | Process incoming votes in batches |
| **Command Bus** | Ceremony lifecycle management |
| **Report Generation** | Final ceremony results report |

---

## 4. Data Model

### 4.1 Core Schemas

#### Ceremony (Main aggregate)

```elixir
schema "eurovision_ceremonies" do
  field :name, :string
  field :status, Ecto.Enum, values: [:draft, :setup, :performing, :voting, :revealing, :completed]
  field :point_scale, {:array, :integer}, default: [1, 2, 3, 4, 5, 6, 7, 8, 10, 12]
  field :voting_config, :map  # Configuration for voting rules

  belongs_to :user, User  # Host/organizer
  has_many :contestants, Contestant
  has_many :delegations, Delegation
  has_many :votes, Vote
  has_many :vote_windows, VoteWindow

  timestamps()
end
```

#### Contestant

```elixir
schema "eurovision_contestants" do
  field :name, :string          # Country/contestant name
  field :code, :string          # Short code (e.g., "FR" for France)
  field :flag_emoji, :string    # Visual identifier
  field :song_title, :string
  field :artist_name, :string
  field :performance_order, :integer
  field :video_url, :string     # YouTube URL or direct video
  field :video_type, Ecto.Enum, values: [:youtube, :direct]

  belongs_to :ceremony, Ceremony

  timestamps()
end
```

#### Delegation (Jury Group)

```elixir
schema "eurovision_delegations" do
  field :name, :string              # e.g., "French Delegation"
  field :representing_code, :string  # Which country they represent
  field :can_vote_for_self, :boolean, default: false

  belongs_to :ceremony, Ceremony
  has_many :members, DelegationMember
  has_one :delegation_vote, DelegationVote

  timestamps()
end
```

#### DelegationMember

```elixir
schema "eurovision_delegation_members" do
  field :role, Ecto.Enum, values: [:spokesperson, :juror]
  field :twitch_user_id, :string
  field :display_name, :string

  belongs_to :delegation, Delegation

  timestamps()
end
```

#### Voter

```elixir
schema "eurovision_voters" do
  field :twitch_user_id, :string
  field :voter_type, Ecto.Enum, values: [:individual, :host, :delegation_member]
  field :has_voted, :boolean, default: false

  belongs_to :ceremony, Ceremony
  belongs_to :delegation_member, DelegationMember  # nil for individuals

  timestamps()
end
```

#### Vote (Individual/Host)

```elixir
schema "eurovision_votes" do
  field :twitch_user_id, :string
  field :voter_type, Ecto.Enum, values: [:individual, :host]
  field :vote_method, Ecto.Enum, values: [:web_single, :web_ranked, :sms]
  field :ranking, {:array, :integer}  # Ordered contestant IDs

  belongs_to :ceremony, Ceremony
  belongs_to :contestant, Contestant  # For single-choice votes

  timestamps()
end
```

#### DelegationVote

```elixir
schema "eurovision_delegation_votes" do
  field :ranking, {:array, :integer}  # Ordered contestant IDs (full ranking)
  field :submitted_by_twitch_id, :string
  field :announced, :boolean, default: false

  belongs_to :ceremony, Ceremony
  belongs_to :delegation, Delegation

  timestamps()
end
```

#### VoteWindow

```elixir
schema "eurovision_vote_windows" do
  field :window_type, Ecto.Enum, values: [:performance, :global, :delegation_only]
  field :opens_at, :utc_datetime
  field :closes_at, :utc_datetime
  field :status, Ecto.Enum, values: [:scheduled, :open, :closed]

  belongs_to :ceremony, Ceremony
  belongs_to :contestant, Contestant  # nil for global windows

  timestamps()
end
```

### 4.2 Database Migrations Required

```
priv/repo/migrations/
├── YYYYMMDDHHMMSS_create_eurovision_ceremonies.exs
├── YYYYMMDDHHMMSS_create_eurovision_contestants.exs
├── YYYYMMDDHHMMSS_create_eurovision_delegations.exs
├── YYYYMMDDHHMMSS_create_eurovision_delegation_members.exs
├── YYYYMMDDHHMMSS_create_eurovision_voters.exs
├── YYYYMMDDHHMMSS_create_eurovision_votes.exs
├── YYYYMMDDHHMMSS_create_eurovision_delegation_votes.exs
├── YYYYMMDDHHMMSS_create_eurovision_vote_windows.exs
└── YYYYMMDDHHMMSS_create_eurovision_scoreboards.exs
```

### 4.3 Indexes and Constraints

```elixir
# Key indexes for performance
create index(:eurovision_votes, [:ceremony_id, :twitch_user_id])
create index(:eurovision_votes, [:ceremony_id, :contestant_id])
create unique_index(:eurovision_votes, [:ceremony_id, :twitch_user_id], name: :eurovision_vote_unique)
create unique_index(:eurovision_delegation_votes, [:ceremony_id, :delegation_id])
```

---

## 5. Implementation Phases

### Phase 1: Foundation (Core Data Model)

**Goal**: Establish the database schema and basic context structure.

**Tasks**:
- [ ] Create `Eurovision` context module
- [ ] Create migrations for all schemas
- [ ] Implement `Ceremony` aggregate with CRUD operations
- [ ] Implement `Contestant` schema with video URL support
- [ ] Add basic validation and constraints
- [ ] Write unit tests for schemas

**Deliverables**:
- Working database schema
- Context module with basic operations
- Test coverage for data layer

---

### Phase 2: Ceremony Management

**Goal**: Allow streamers to create and configure ceremonies.

**Tasks**:
- [ ] Implement ceremony commands: `CreateCeremony`, `UpdateCeremony`, `StartCeremony`
- [ ] Create ceremony command handler
- [ ] Implement ceremony state machine (draft → setup → performing → voting → revealing → completed)
- [ ] Add contestant management (add, remove, reorder)
- [ ] Create delegation management
- [ ] Build LiveView for ceremony setup

**Deliverables**:
- Streamer can create ceremony with contestants
- Streamer can configure delegations
- Ceremony state transitions work correctly

---

### Phase 3: Voter Registration & Authentication

**Goal**: Allow viewers to register as voters and authenticate.

**Tasks**:
- [ ] Implement voter registration (link Twitch accounts)
- [ ] Create delegation member invitation system
- [ ] Implement voter type assignment (individual, host, delegation member)
- [ ] Add "cannot vote for own delegation's country" rule
- [ ] Create voter management UI for streamers

**Deliverables**:
- Viewers can register as voters
- Delegation members can be invited and accept
- Voting eligibility rules enforced

---

### Phase 4: Voting System (Web)

**Goal**: Implement web-based voting interface.

**Tasks**:
- [ ] Create single-choice voting component
- [ ] Create sortable list voting component (drag-and-drop)
- [ ] Implement vote submission and validation
- [ ] Add vote window management (open/close)
- [ ] Create Broadway pipeline for vote processing
- [ ] Implement real-time vote count updates

**Deliverables**:
- Individuals can vote via web (single or ranked)
- Delegations can submit ranked votes
- Vote windows can be programmed and enforced

---

### Phase 5: SMS Voting (Optional)

**Goal**: Allow single-choice voting via SMS.

**Tasks**:
- [ ] Integrate SMS gateway (Twilio or similar)
- [ ] Parse incoming SMS messages for country codes
- [ ] Link SMS numbers to Twitch accounts (or allow anonymous)
- [ ] Implement rate limiting and fraud prevention
- [ ] Add SMS vote to Broadway pipeline

**Deliverables**:
- Viewers can vote via SMS
- SMS votes count toward individual totals

---

### Phase 6: Performance Playback

**Goal**: Enable video playback during ceremonies.

**Tasks**:
- [ ] Create YouTube video player component
- [ ] Support direct video file playback
- [ ] Implement performance sequencing
- [ ] Add performance start/end triggers
- [ ] Sync vote windows with performances (optional)

**Deliverables**:
- Streamer can play contestant videos in sequence
- Video playback integrated with ceremony flow

---

### Phase 7: Scoreboard & Point Calculation

**Goal**: Calculate and display live scores.

**Tasks**:
- [ ] Implement point calculator module
- [ ] Convert ranked votes to Eurovision points
- [ ] Aggregate delegation + individual + host votes
- [ ] Create real-time scoreboard GenServer
- [ ] Implement scoreboard LiveView component
- [ ] Add vote breakdown visualization

**Deliverables**:
- Live scoreboard showing current standings
- Points calculated correctly from all vote sources
- Real-time updates as votes come in

---

### Phase 8: Results Reveal Ceremony

**Goal**: Implement the dramatic Eurovision-style reveal sequence.

**Tasks**:
- [ ] Calculate reveal order (delegation points → televote by jury rank)
- [ ] Create reveal sequence generator
- [ ] Build reveal UI with animations
- [ ] Implement spokesperson "12 points goes to..." moment
- [ ] Add suspense timing controls
- [ ] Create final winner announcement

**Deliverables**:
- Delegation points announced one-by-one with spokesperson
- Televote revealed in ascending order
- Dramatic winner reveal with running totals

---

### Phase 9: OBS Overlay

**Goal**: Provide streaming-ready visual overlays.

**Tasks**:
- [ ] Create scoreboard overlay component
- [ ] Add current performance overlay
- [ ] Implement results reveal overlay
- [ ] Support customizable themes/colors
- [ ] Add transparent background mode

**Deliverables**:
- OBS-compatible overlay URLs
- Multiple overlay styles available
- Real-time updates visible in stream

---

### Phase 10: Polish & Integration

**Goal**: Final integration, testing, and polish.

**Tasks**:
- [ ] End-to-end testing of full ceremony flow
- [ ] Performance optimization for high vote volume
- [ ] Add ceremony templates/presets
- [ ] Create user documentation
- [ ] Add analytics and reporting
- [ ] Mobile-responsive voting interface

**Deliverables**:
- Production-ready feature
- Documentation for streamers
- Performance validated at scale

---

## 6. Technical Decisions Needed

### 6.1 Vote Weight Distribution

**Question**: How should votes be weighted between voter types?

| Option | Delegation | Host | Individual |
|--------|------------|------|------------|
| A (Eurovision-like) | 50% | 0% (part of public) | 50% |
| B (Host emphasis) | 40% | 20% | 40% |
| C (Equal split) | 33% | 33% | 33% |
| D (Configurable) | Custom | Custom | Custom |

**Recommendation**: Option D - make it configurable per ceremony, with presets.

---

### 6.2 Individual Vote Method

**Question**: Should individuals vote for one country or rank all countries?

| Option | Pros | Cons |
|--------|------|------|
| Single choice only | Simple, fast, accessible | Less data, potential vote splitting |
| Full ranking only | Rich data, fair | Complex, time-consuming |
| User choice | Flexibility | May skew toward easier option |

**Recommendation**: Allow configurable per ceremony. Default to single choice for larger audiences, full ranking for smaller/dedicated groups.

---

### 6.3 Vote Window Strategy

**Question**: When should voting be allowed?

| Option | Description |
|--------|-------------|
| A: Per-performance | Window opens after each performance, closes before next |
| B: Global after all | One window after all performances complete |
| C: Hybrid | Per-performance + global catch-up window |
| D: Always open | Voting open throughout entire ceremony |

**Recommendation**: Option C (Hybrid) - matches real Eurovision where you can vote during performances but there's a final window.

---

### 6.4 Delegation Formation

**Question**: How are delegations formed?

| Option | Description |
|--------|-------------|
| A: Pre-defined | Streamer creates delegations and assigns members |
| B: Self-select | Viewers join delegations they want |
| C: Random | System assigns viewers to delegations randomly |
| D: Invitation | Delegation leads invite specific viewers |

**Recommendation**: Option A or D - delegations should be curated for the "jury" feel.

---

### 6.5 Anonymous vs Authenticated Voting

**Question**: Must all voters be authenticated?

| Voter Type | Recommendation |
|------------|----------------|
| Delegation | Must be authenticated (Twitch) |
| Host | Must be authenticated (Twitch) |
| Individual (Web) | Must be authenticated (Twitch) |
| Individual (SMS) | Can be anonymous OR linked to Twitch |

---

## 7. Open Questions

### 7.1 For Product Decision

1. **What's the expected ceremony size?**
   - Number of contestants (countries): typically 10-26 in real Eurovision
   - Number of delegations: 1 per contestant? Fewer?
   - Expected individual voter count: hundreds? thousands?

2. **How does SMS voting work financially?**
   - Who pays for SMS gateway?
   - Is there a charge per vote (like real Eurovision)?

3. **Should there be multiple rounds?**
   - Semi-finals to qualify contestants?
   - Or single-round only (as specified)?

4. **What happens with ties?**
   - Eurovision has complex tie-breaker rules
   - Define our tie-breaker: highest delegation votes? Most 12-pointers?

### 7.2 For Technical Decision

1. **Video hosting**
   - YouTube only, or support for direct uploads?
   - Copyright considerations for YouTube embeds?

2. **Scale requirements**
   - Max concurrent voters?
   - Vote throughput requirements?

3. **Internationalization**
   - UI in multiple languages?
   - RTL support?

4. **Accessibility**
   - Screen reader support for voting?
   - Keyboard navigation for drag-drop ranking?

### 7.3 For UX Decision

1. **Mobile experience**
   - Native app or responsive web?
   - SMS as primary mobile voting method?

2. **Reveal ceremony control**
   - Fully automatic timing?
   - Manual "next" button for streamer?
   - Hybrid with pause points?

3. **Spoiler prevention**
   - Hide vote counts until reveal?
   - Show running totals during voting?

---

## Sources

- [Eurovision - How It Works](https://eurovision.tv/about/how-it-works)
- [Wikipedia - Voting at Eurovision](https://en.wikipedia.org/wiki/Voting_at_the_Eurovision_Song_Contest)
- [Eurovision World - Voting Systems History](https://eurovisionworld.com/esc/voting-systems-in-eurovision-history)
- [EBU Voting Rules Changes 2025](https://www.ebu.ch/news/2025/11/ebu-announces-changes-to-eurovision-song-contest-voting-rules-to-strengthen-trust-and-transparency)
- [ESC Insight - Voting Sequence](https://escinsight.com/2019/03/31/eurovision-song-contest-new-voting-rules-presentation-televote-sequence/)

---

## Appendix A: Eurovision Point Scale Reference

The classic Eurovision point scale, unchanged since 1975:

```
Rank → Points
1    → 12  (douze points)
2    → 10  (dix points)
3    →  8
4    →  7
5    →  6
6    →  5
7    →  4
8    →  3
9    →  2
10   →  1
11+  →  0
```

**Note**: Points 9 and 11 are intentionally skipped to create distinction at the top of rankings.

---

## Appendix B: Example Ceremony Flow

```
Timeline for a 10-contestant ceremony:

00:00 - Ceremony opens, welcome message
00:05 - Performance 1 begins
00:08 - Performance 1 ends, vote window opens
00:10 - Performance 2 begins, P1 vote window closes
...
01:30 - Performance 10 ends
01:35 - Global voting window opens
01:50 - Global voting window closes
01:55 - Results ceremony begins

Results reveal sequence:
- Host introduces results
- Delegation 1 spokesperson: "Our 12 points go to..."
- Delegation 2 spokesperson: "Our 12 points go to..."
...
- "Now for the public vote..."
- Country ranked 10th by delegations gets their public points
- Country ranked 9th by delegations gets their public points
...
- Country ranked 1st by delegations gets their public points
- Winner announced!

02:30 - Ceremony complete
```

---

<!-- AIDEV-NOTE: This plan covers Eurovision voting feature for Premiere Ecoute. Key architectural patterns to follow: Command/Event flow (see sessions/listening_session/), Broadway for vote processing (see sessions/scores/), PubSub for real-time (see existing patterns). Major unknowns: vote weight distribution, SMS integration scope, expected scale. -->
